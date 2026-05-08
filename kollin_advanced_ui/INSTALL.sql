-- kollin_advanced_ui — Database schema
-- Run once before starting the resource. Safe to re-run (uses IF NOT EXISTS).

CREATE TABLE IF NOT EXISTS kollin_ui_settings (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    citizenid   VARCHAR(64) NOT NULL,
    settings    LONGTEXT    NOT NULL DEFAULT '{}',
    updated_at  DATETIME    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY ux_citizen (citizenid)
);
