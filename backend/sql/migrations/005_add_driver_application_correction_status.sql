-- Migration: allow admins to request a document correction/re-upload
-- from a driver applicant instead of only approve/reject.

SET @db_name = DATABASE();

ALTER TABLE driver_applications
  MODIFY status ENUM('pending', 'approved', 'rejected', 'needs_correction', 'archived') NOT NULL DEFAULT 'pending';

SET @exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'driver_applications'
    AND COLUMN_NAME = 'correction_note'
);
SET @sql = IF(@exists = 0, 'ALTER TABLE driver_applications ADD COLUMN correction_note VARCHAR(255) NULL AFTER rejection_reason', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
