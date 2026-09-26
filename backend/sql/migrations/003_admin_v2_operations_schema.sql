-- Migration: Admin Dashboard V2 operational schema.
-- Non-destructive: adds missing cash-only municipal operations tables, columns, and indexes.

SET @db_name = DATABASE();

-- Helper pattern: set @sql to ALTER/CREATE when missing, otherwise SELECT 1.

ALTER TABLE users
  MODIFY status ENUM('pending', 'active', 'suspended', 'rejected', 'archived') NOT NULL DEFAULT 'active';

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'users' AND COLUMN_NAME = 'deleted_at');
SET @sql = IF(@exists = 0, 'ALTER TABLE users ADD COLUMN deleted_at DATETIME NULL AFTER updated_at', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'users' AND INDEX_NAME = 'idx_users_role_status_deleted');
SET @sql = IF(@exists = 0, 'CREATE INDEX idx_users_role_status_deleted ON users (role, status, deleted_at)', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'admins' AND COLUMN_NAME = 'deleted_at');
SET @sql = IF(@exists = 0, 'ALTER TABLE admins ADD COLUMN deleted_at DATETIME NULL AFTER created_at', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

ALTER TABLE drivers
  MODIFY approval_status ENUM('pending', 'approved', 'rejected', 'suspended', 'archived', 'license_expired') NOT NULL DEFAULT 'pending';

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'drivers' AND COLUMN_NAME = 'license_status');
SET @sql = IF(@exists = 0, 'ALTER TABLE drivers ADD COLUMN license_status ENUM(''valid'', ''expiring_soon'', ''expired'') NOT NULL DEFAULT ''valid'' AFTER license_expires_at', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'drivers' AND COLUMN_NAME = 'license_number');
SET @sql = IF(@exists = 0, 'ALTER TABLE drivers ADD COLUMN license_number VARCHAR(80) NULL AFTER license_status', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'drivers' AND COLUMN_NAME = 'license_holder_name');
SET @sql = IF(@exists = 0, 'ALTER TABLE drivers ADD COLUMN license_holder_name VARCHAR(120) NULL AFTER license_number', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'drivers' AND COLUMN_NAME = 'license_ocr_text');
SET @sql = IF(@exists = 0, 'ALTER TABLE drivers ADD COLUMN license_ocr_text TEXT NULL AFTER license_holder_name', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'drivers' AND COLUMN_NAME = 'business_permit_expires_at');
SET @sql = IF(@exists = 0, 'ALTER TABLE drivers ADD COLUMN business_permit_expires_at DATETIME NULL AFTER business_permit_image_url', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'drivers' AND COLUMN_NAME = 'deleted_at');
SET @sql = IF(@exists = 0, 'ALTER TABLE drivers ADD COLUMN deleted_at DATETIME NULL AFTER updated_at', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'drivers' AND INDEX_NAME = 'idx_drivers_status_deleted');
SET @sql = IF(@exists = 0, 'CREATE INDEX idx_drivers_status_deleted ON drivers (approval_status, deleted_at)', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'drivers' AND INDEX_NAME = 'idx_drivers_license_monitor');
SET @sql = IF(@exists = 0, 'CREATE INDEX idx_drivers_license_monitor ON drivers (license_status, license_expires_at)', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'fare_settings' AND COLUMN_NAME = 'minimum_fare');
SET @sql = IF(@exists = 0, 'ALTER TABLE fare_settings ADD COLUMN minimum_fare DECIMAL(10, 2) NOT NULL DEFAULT 0.00 AFTER per_km_rate', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'fare_settings' AND COLUMN_NAME = 'night_fee');
SET @sql = IF(@exists = 0, 'ALTER TABLE fare_settings ADD COLUMN night_fee DECIMAL(10, 2) NOT NULL DEFAULT 0.00 AFTER minimum_fare', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'fare_settings' AND COLUMN_NAME = 'deleted_at');
SET @sql = IF(@exists = 0, 'ALTER TABLE fare_settings ADD COLUMN deleted_at DATETIME NULL AFTER updated_at', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

ALTER TABLE bookings
  MODIFY status ENUM('pending', 'searching', 'accepted', 'assigned', 'arriving', 'ongoing', 'on_ride', 'completed', 'cancelled', 'archived') NOT NULL DEFAULT 'pending';

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'payment_method');
SET @sql = IF(@exists = 0, 'ALTER TABLE bookings ADD COLUMN payment_method ENUM(''cash'') NOT NULL DEFAULT ''cash'' AFTER final_fare', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'archived_at');
SET @sql = IF(@exists = 0, 'ALTER TABLE bookings ADD COLUMN archived_at DATETIME NULL AFTER cancelled_at', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'deleted_at');
SET @sql = IF(@exists = 0, 'ALTER TABLE bookings ADD COLUMN deleted_at DATETIME NULL AFTER updated_at', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'bookings' AND INDEX_NAME = 'idx_bookings_status_requested');
SET @sql = IF(@exists = 0, 'CREATE INDEX idx_bookings_status_requested ON bookings (status, requested_at)', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'bookings' AND INDEX_NAME = 'idx_bookings_deleted_archived');
SET @sql = IF(@exists = 0, 'CREATE INDEX idx_bookings_deleted_archived ON bookings (deleted_at, archived_at)', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'ratings' AND COLUMN_NAME = 'deleted_at');
SET @sql = IF(@exists = 0, 'ALTER TABLE ratings ADD COLUMN deleted_at DATETIME NULL AFTER created_at', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'notifications' AND COLUMN_NAME = 'is_read');
SET @sql = IF(@exists = 0, 'ALTER TABLE notifications ADD COLUMN is_read TINYINT(1) NOT NULL DEFAULT 0 AFTER metadata_json', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'notifications' AND COLUMN_NAME = 'user_id');
SET @sql = IF(@exists = 0, 'ALTER TABLE notifications ADD COLUMN user_id BIGINT UNSIGNED NULL AFTER id', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'notifications' AND COLUMN_NAME = 'recipient_role');
SET @sql = IF(@exists = 0, 'ALTER TABLE notifications ADD COLUMN recipient_role ENUM(''everyone'', ''driver'', ''passenger'', ''admin'') NOT NULL DEFAULT ''everyone'' AFTER user_id', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'notifications' AND COLUMN_NAME = 'sent_by');
SET @sql = IF(@exists = 0, 'ALTER TABLE notifications ADD COLUMN sent_by BIGINT UNSIGNED NULL AFTER recipient_role', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'notifications' AND COLUMN_NAME = 'read_at');
SET @sql = IF(@exists = 0, 'ALTER TABLE notifications ADD COLUMN read_at DATETIME NULL AFTER is_read', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'notifications' AND COLUMN_NAME = 'updated_at');
SET @sql = IF(@exists = 0, 'ALTER TABLE notifications ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'notifications' AND COLUMN_NAME = 'deleted_at');
SET @sql = IF(@exists = 0, 'ALTER TABLE notifications ADD COLUMN deleted_at DATETIME NULL AFTER updated_at', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'notifications' AND INDEX_NAME = 'idx_notifications_recipient_read');
SET @sql = IF(@exists = 0, 'CREATE INDEX idx_notifications_recipient_read ON notifications (recipient_role, is_read, created_at)', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS driver_applications (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  driver_id BIGINT UNSIGNED NULL,
  full_name VARCHAR(120) NOT NULL,
  email VARCHAR(120) NULL,
  phone VARCHAR(20) NOT NULL,
  plate_number VARCHAR(60) NOT NULL,
  license_image_url VARCHAR(255) NOT NULL,
  business_permit_image_url VARCHAR(255) NOT NULL,
  license_number VARCHAR(80) NULL,
  license_holder_name VARCHAR(120) NULL,
  license_expires_at DATETIME NULL,
  ocr_status ENUM('pending', 'passed', 'failed') NOT NULL DEFAULT 'pending',
  ocr_failure_reason VARCHAR(255) NULL,
  status ENUM('pending', 'approved', 'rejected', 'archived') NOT NULL DEFAULT 'pending',
  rejection_reason VARCHAR(255) NULL,
  reviewed_by BIGINT UNSIGNED NULL,
  reviewed_at DATETIME NULL,
  submitted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT fk_driver_applications_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_driver_applications_driver FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_driver_applications_reviewed_by FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX idx_driver_applications_status_submitted (status, submitted_at),
  INDEX idx_driver_applications_user (user_id),
  INDEX idx_driver_applications_deleted (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS booking_timeline_events (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id BIGINT UNSIGNED NOT NULL,
  status VARCHAR(40) NOT NULL,
  title VARCHAR(120) NOT NULL,
  body VARCHAR(255) NULL,
  lat DECIMAL(10, 7) NULL,
  lng DECIMAL(10, 7) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT fk_booking_timeline_booking FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_booking_timeline_booking_created (booking_id, created_at),
  INDEX idx_booking_timeline_deleted (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sos_alerts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id BIGINT UNSIGNED NULL,
  passenger_id BIGINT UNSIGNED NOT NULL,
  driver_id BIGINT UNSIGNED NULL,
  lat DECIMAL(10, 7) NULL,
  lng DECIMAL(10, 7) NULL,
  message TEXT NULL,
  status ENUM('active', 'resolved', 'dismissed', 'archived') NOT NULL DEFAULT 'active',
  resolved_by BIGINT UNSIGNED NULL,
  resolved_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT fk_sos_booking FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_sos_passenger FOREIGN KEY (passenger_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_sos_driver FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_sos_resolved_by FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX idx_sos_status_created (status, created_at),
  INDEX idx_sos_deleted (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS complaints (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reporter_id BIGINT UNSIGNED NOT NULL,
  reported_user_id BIGINT UNSIGNED NULL,
  booking_id BIGINT UNSIGNED NULL,
  category VARCHAR(80) NOT NULL,
  description TEXT NOT NULL,
  evidence_json JSON NULL,
  status ENUM('open', 'resolved', 'dismissed', 'archived') NOT NULL DEFAULT 'open',
  resolution_note TEXT NULL,
  resolved_by BIGINT UNSIGNED NULL,
  resolved_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT fk_complaints_reporter FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_complaints_reported_user FOREIGN KEY (reported_user_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_complaints_booking FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_complaints_resolved_by FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX idx_complaints_status_created (status, created_at),
  INDEX idx_complaints_reporter (reporter_id),
  INDEX idx_complaints_deleted (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS favorite_destinations (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  label VARCHAR(120) NOT NULL,
  address VARCHAR(255) NOT NULL,
  lat DECIMAL(10, 7) NULL,
  lng DECIMAL(10, 7) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT fk_favorite_destinations_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_favorites_user_deleted (user_id, deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS barangays (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL UNIQUE,
  is_enabled TINYINT(1) NOT NULL DEFAULT 1,
  service_notes VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  INDEX idx_barangays_enabled_deleted (is_enabled, deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS system_settings (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  setting_key VARCHAR(120) NOT NULL UNIQUE,
  setting_value TEXT NULL,
  value_type ENUM('string', 'number', 'boolean', 'json') NOT NULL DEFAULT 'string',
  updated_by BIGINT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT fk_system_settings_updated_by FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX idx_system_settings_deleted (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS activity_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id BIGINT UNSIGNED NULL,
  action VARCHAR(120) NOT NULL,
  target_type VARCHAR(80) NULL,
  target_id BIGINT UNSIGNED NULL,
  metadata_json JSON NULL,
  ip_address VARCHAR(45) NULL,
  user_agent VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_activity_logs_admin FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX idx_activity_logs_created (created_at),
  INDEX idx_activity_logs_admin_created (admin_id, created_at),
  INDEX idx_activity_logs_target (target_type, target_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO system_settings (setting_key, setting_value, value_type)
VALUES
  ('app_name', 'FindMeTricycle', 'string'),
  ('support_email', 'support@findmetricycle.local', 'string'),
  ('contact_number', '09990000000', 'string'),
  ('operating_hours', '{"start":"05:00","end":"22:00"}', 'json')
ON DUPLICATE KEY UPDATE setting_key = VALUES(setting_key);
