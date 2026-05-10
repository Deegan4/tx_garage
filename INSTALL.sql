-- tx_garage v2.0 — Database schema
-- Idempotent: re-runnable. Adds columns and tables without destroying existing data.
-- Compatible with qbx_core's player_vehicles schema.

-- ─────────────────────────────────────────────────────────────────────
-- player_vehicles column additions
-- ─────────────────────────────────────────────────────────────────────
SET @dbname = DATABASE();
SET @tablename = 'player_vehicles';

-- tx_garage_state: 'out' | 'stored' | 'impound' | 'auction'
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = 'tx_garage_state') = 0,
    'ALTER TABLE player_vehicles ADD COLUMN tx_garage_state VARCHAR(16) DEFAULT ''stored'', ADD INDEX ix_txg_state (tx_garage_state)',
    'SELECT 0'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = 'tx_garage_name') = 0,
    'ALTER TABLE player_vehicles ADD COLUMN tx_garage_name VARCHAR(64) DEFAULT NULL',
    'SELECT 0'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = 'tx_garage_impounded_at') = 0,
    'ALTER TABLE player_vehicles ADD COLUMN tx_garage_impounded_at DATETIME DEFAULT NULL',
    'SELECT 0'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Pinned/favorite flag
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = 'tx_garage_fav') = 0,
    'ALTER TABLE player_vehicles ADD COLUMN tx_garage_fav TINYINT(1) NOT NULL DEFAULT 0',
    'SELECT 0'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Mileage (meters travelled). Saved on store; visible in NUI.
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = 'tx_garage_mileage') = 0,
    'ALTER TABLE player_vehicles ADD COLUMN tx_garage_mileage BIGINT UNSIGNED NOT NULL DEFAULT 0',
    'SELECT 0'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Last private-rent payment (so we charge weekly, not every retrieve)
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = 'tx_garage_rent_paid_at') = 0,
    'ALTER TABLE player_vehicles ADD COLUMN tx_garage_rent_paid_at DATETIME DEFAULT NULL',
    'SELECT 0'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Sub-owners (key sharing). JSON array of citizenids.
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = 'tx_garage_sub_owners') = 0,
    'ALTER TABLE player_vehicles ADD COLUMN tx_garage_sub_owners JSON DEFAULT NULL',
    'SELECT 0'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Last plate-change timestamp (per-vehicle cooldown enforcement)
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = 'tx_garage_plate_changed_at') = 0,
    'ALTER TABLE player_vehicles ADD COLUMN tx_garage_plate_changed_at DATETIME DEFAULT NULL',
    'SELECT 0'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ─────────────────────────────────────────────────────────────────────
-- Auctions
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tx_garage_auctions (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    plate           VARCHAR(16) NOT NULL,
    vehicle_model   VARCHAR(64) NOT NULL,
    starting_bid    INT NOT NULL,
    current_bid     INT NOT NULL,
    leading_bidder  VARCHAR(64) DEFAULT NULL,
    original_owner  VARCHAR(64) DEFAULT NULL,
    started_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    ends_at         DATETIME NOT NULL,
    status          VARCHAR(16) DEFAULT 'open', -- 'open' | 'closed' | 'forfeited'
    INDEX ix_status_ends (status, ends_at),
    INDEX ix_plate (plate)
);
-- Drop the legacy unique-plate constraint (a plate can be re-auctioned over time).
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = 'tx_garage_auctions' AND INDEX_NAME = 'ux_plate') > 0,
    'ALTER TABLE tx_garage_auctions DROP INDEX ux_plate',
    'SELECT 0'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add original_owner column if upgrading from v1
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = 'tx_garage_auctions' AND COLUMN_NAME = 'original_owner') = 0,
    'ALTER TABLE tx_garage_auctions ADD COLUMN original_owner VARCHAR(64) DEFAULT NULL',
    'SELECT 0'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS tx_garage_auction_bids (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    auction_id      INT NOT NULL,
    bidder          VARCHAR(64) NOT NULL,
    bid_amount      INT NOT NULL,
    placed_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX ix_auction (auction_id),
    INDEX ix_bidder (bidder),
    FOREIGN KEY (auction_id) REFERENCES tx_garage_auctions(id) ON DELETE CASCADE
);

-- ─────────────────────────────────────────────────────────────────────
-- Valet log (analytics + anti-abuse)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tx_garage_valet_log (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    citizenid       VARCHAR(64) NOT NULL,
    plate           VARCHAR(16) NOT NULL,
    requested_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
    delivered_at    DATETIME DEFAULT NULL,
    cancelled_at    DATETIME DEFAULT NULL,
    cost            INT NOT NULL DEFAULT 0,
    INDEX ix_citizen (citizenid),
    INDEX ix_requested (requested_at)
);

-- ─────────────────────────────────────────────────────────────────────
-- Pending vehicle transfers (consent flow — fixes C2)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tx_garage_transfer_requests (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    plate           VARCHAR(16) NOT NULL,
    from_citizenid  VARCHAR(64) NOT NULL,
    to_citizenid    VARCHAR(64) NOT NULL,
    price           INT NOT NULL DEFAULT 0,
    expires_at      DATETIME NOT NULL,
    status          VARCHAR(16) NOT NULL DEFAULT 'pending', -- pending|accepted|rejected|expired
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX ix_to (to_citizenid, status),
    INDEX ix_plate (plate)
);

-- ─────────────────────────────────────────────────────────────────────
-- Society balance ledger (boss menu deposits/withdrawals)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tx_garage_society_log (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    society         VARCHAR(64) NOT NULL,
    citizenid       VARCHAR(64) NOT NULL,
    action          VARCHAR(32) NOT NULL,   -- 'deposit'|'withdraw'|'auction_cut'
    amount          INT NOT NULL,
    note            VARCHAR(255) DEFAULT NULL,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX ix_society (society, created_at)
);
