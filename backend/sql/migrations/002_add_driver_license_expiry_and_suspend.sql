-- Migration: add driver license expiry and suspended status safely.
-- This file is idempotent and can be rerun by the Node migration runner.

SET @db_name = DATABASE();

SET @license_column_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'drivers'
    AND COLUMN_NAME = 'license_expires_at'
);

SET @sql = IF(
  @license_column_exists = 0,
  'ALTER TABLE drivers ADD COLUMN license_expires_at DATETIME NULL AFTER business_permit_image_url',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Uses the full current value list (incl. 'archived' / 'license_expired'
-- from 003) so re-running this file can never shrink the enum and wipe
-- those statuses from existing rows.
ALTER TABLE drivers
  MODIFY approval_status ENUM('pending', 'approved', 'rejected', 'suspended', 'archived', 'license_expired') NOT NULL DEFAULT 'pending';

SET @driver_license_index_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'drivers'
    AND INDEX_NAME = 'idx_driver_license_expires_at'
);

SET @sql = IF(
  @driver_license_index_exists = 0,
  'CREATE INDEX idx_driver_license_expires_at ON drivers (license_expires_at)',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
