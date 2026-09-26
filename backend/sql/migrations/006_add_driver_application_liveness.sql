-- Migration: add selfie/liveness columns for the driver-verification flow.
-- Liveness is a screening signal only — never auto-approves/rejects an
-- application (admin has final authority), mirroring the existing
-- ocr_status column added in 003_admin_v2_operations_schema.sql.

SET @db_name = DATABASE();

SET @exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'driver_applications'
    AND COLUMN_NAME = 'selfie_image_url'
);
SET @sql = IF(@exists = 0, 'ALTER TABLE driver_applications ADD COLUMN selfie_image_url VARCHAR(255) NULL AFTER business_permit_image_url', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'driver_applications'
    AND COLUMN_NAME = 'liveness_status'
);
SET @sql = IF(@exists = 0, 'ALTER TABLE driver_applications ADD COLUMN liveness_status ENUM(''pending'', ''passed'', ''needs_review'', ''failed'') NOT NULL DEFAULT ''pending'' AFTER ocr_failure_reason', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
