-- tx_garage — Database schema
-- Run this once on your server's MySQL database before starting the resource.
-- Compatible with QBCore's existing player_vehicles table; only ADDS columns and tables.

-- Add tracking columns to player_vehicles if missing (safe — uses IF NOT EXISTS pattern via stored proc workaround)
SET @dbname = DATABASE();
SET @tablename = 'player_vehicles';

-- garage_state: 'out' | 'stored' | 'impound' | 'auction'
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = 'tx_garage_state') = 0,
    'ALTER TABLE player_vehicles ADD COLUMN tx_garage_state VARCHAR(16) DEFAULT ''stored''',
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

-- Auction table
CREATE TABLE IF NOT EXISTS tx_garage_auctions (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    plate           VARCHAR(16) NOT NULL,
    vehicle_model   VARCHAR(64) NOT NULL,
    starting_bid    INT NOT NULL,
    current_bid     INT NOT NULL,
    leading_bidder  VARCHAR(64) DEFAULT NULL,  -- citizenid / identifier
    started_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    ends_at         DATETIME NOT NULL,
    status          VARCHAR(16) DEFAULT 'open', -- 'open' | 'closed' | 'forfeited'
    UNIQUE KEY ux_plate (plate)
);

CREATE TABLE IF NOT EXISTS tx_garage_auction_bids (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    auction_id      INT NOT NULL,
    bidder          VARCHAR(64) NOT NULL,
    bid_amount      INT NOT NULL,
    placed_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX ix_auction (auction_id),
    FOREIGN KEY (auction_id) REFERENCES tx_garage_auctions(id) ON DELETE CASCADE
);

-- Valet log (analytics + anti-abuse)
CREATE TABLE IF NOT EXISTS tx_garage_valet_log (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    citizenid       VARCHAR(64) NOT NULL,
    plate           VARCHAR(16) NOT NULL,
    requested_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
    delivered_at    DATETIME DEFAULT NULL,
    cancelled_at    DATETIME DEFAULT NULL,
    cost            INT NOT NULL DEFAULT 0,
    INDEX ix_citizen (citizenid)
);
