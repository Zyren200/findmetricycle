CREATE DATABASE IF NOT EXISTS findme_tricycle
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE findme_tricycle;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  phone VARCHAR(20) NOT NULL UNIQUE,
  email VARCHAR(120) NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('passenger', 'driver', 'admin') NOT NULL,
  status ENUM('pending', 'active', 'suspended', 'rejected', 'archived') NOT NULL DEFAULT 'active',
  profile_image_url VARCHAR(255) NULL,
  driver_approval_status ENUM('none', 'pending', 'approved', 'rejected') NOT NULL DEFAULT 'none',
  is_driver_account TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  INDEX idx_users_role_status_deleted (role, status, deleted_at),
  INDEX idx_users_driver_approval (driver_approval_status)
);

CREATE TABLE IF NOT EXISTS admins (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL UNIQUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT fk_admin_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS drivers (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL UNIQUE,
  tricycle_number VARCHAR(60) NOT NULL UNIQUE,
  license_image_url VARCHAR(255) NOT NULL,
  business_permit_image_url VARCHAR(255) NOT NULL,
  business_permit_expires_at DATETIME NULL,
  license_expires_at DATETIME NULL,
  license_status ENUM('valid', 'expiring_soon', 'expired') NOT NULL DEFAULT 'valid',
  license_number VARCHAR(80) NULL,
  license_holder_name VARCHAR(120) NULL,
  license_ocr_text TEXT NULL,
  approval_status ENUM('pending', 'approved', 'rejected', 'suspended', 'archived', 'license_expired') NOT NULL DEFAULT 'pending',
  is_online TINYINT(1) NOT NULL DEFAULT 0,
  current_lat DECIMAL(10, 7) NULL,
  current_lng DECIMAL(10, 7) NULL,
  last_location_update DATETIME NULL,
  rating_avg DECIMAL(3, 2) NOT NULL DEFAULT 5.00,
  total_rides INT UNSIGNED NOT NULL DEFAULT 0,
  total_earnings DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  approved_by BIGINT UNSIGNED NULL,
  approved_at DATETIME NULL,
  rejection_reason VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT fk_driver_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_driver_approved_by
    FOREIGN KEY (approved_by) REFERENCES users(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  INDEX idx_driver_approval_online (approval_status, is_online),
  INDEX idx_driver_license_expires_at (license_expires_at),
  INDEX idx_drivers_status_deleted (approval_status, deleted_at),
  INDEX idx_drivers_license_monitor (license_status, license_expires_at),
  INDEX idx_driver_location (current_lat, current_lng)
);

CREATE TABLE IF NOT EXISTS fare_settings (
  id TINYINT UNSIGNED PRIMARY KEY,
  base_fare DECIMAL(10, 2) NOT NULL,
  per_km_rate DECIMAL(10, 2) NOT NULL,
  minimum_fare DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  night_fee DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  additional_passenger_fee DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  updated_by BIGINT UNSIGNED NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT fk_fare_updated_by
    FOREIGN KEY (updated_by) REFERENCES users(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
);

INSERT INTO fare_settings (id, base_fare, per_km_rate, updated_by)
VALUES (1, 20.00, 12.00, NULL)
ON DUPLICATE KEY UPDATE id = id;

CREATE TABLE IF NOT EXISTS bookings (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  passenger_id BIGINT UNSIGNED NOT NULL,
  driver_id BIGINT UNSIGNED NULL,
  offer_expires_at DATETIME NULL,
  pickup_pin_hash VARCHAR(100) NULL,
  pickup_pin VARCHAR(6) NULL,
  pin_attempts INT NOT NULL DEFAULT 0,
  pin_verified_at DATETIME NULL,
  pickup_address VARCHAR(255) NULL,
  pickup_lat DECIMAL(10, 7) NOT NULL,
  pickup_lng DECIMAL(10, 7) NOT NULL,
  dropoff_address VARCHAR(255) NULL,
  dropoff_lat DECIMAL(10, 7) NOT NULL,
  dropoff_lng DECIMAL(10, 7) NOT NULL,
  passenger_count TINYINT UNSIGNED NOT NULL DEFAULT 1,
  distance_km DECIMAL(8, 3) NOT NULL,
  estimated_fare DECIMAL(10, 2) NOT NULL,
  final_fare DECIMAL(10, 2) NULL,
  fare_breakdown_json JSON NULL,
  payment_method ENUM('cash') NOT NULL DEFAULT 'cash',
  status ENUM('pending', 'searching', 'accepted', 'assigned', 'arriving', 'ongoing', 'on_ride', 'completed', 'cancelled', 'archived') NOT NULL DEFAULT 'pending',
  requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  accepted_at DATETIME NULL,
  started_at DATETIME NULL,
  completed_at DATETIME NULL,
  cancelled_at DATETIME NULL,
  archived_at DATETIME NULL,
  cancelled_by ENUM('passenger', 'driver', 'system') NULL,
  decline_reason VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT fk_booking_passenger
    FOREIGN KEY (passenger_id) REFERENCES users(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT fk_booking_driver
    FOREIGN KEY (driver_id) REFERENCES drivers(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  INDEX idx_booking_status (status),
  INDEX idx_bookings_status_requested (status, requested_at),
  INDEX idx_bookings_deleted_archived (deleted_at, archived_at),
  INDEX idx_booking_passenger_status (passenger_id, status),
  INDEX idx_booking_driver_status (driver_id, status)
);

CREATE TABLE IF NOT EXISTS ratings (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id BIGINT UNSIGNED NOT NULL UNIQUE,
  passenger_id BIGINT UNSIGNED NOT NULL,
  driver_id BIGINT UNSIGNED NOT NULL,
  stars TINYINT UNSIGNED NOT NULL,
  feedback TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT chk_rating_stars CHECK (stars BETWEEN 1 AND 5),
  CONSTRAINT fk_rating_booking
    FOREIGN KEY (booking_id) REFERENCES bookings(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_rating_passenger
    FOREIGN KEY (passenger_id) REFERENCES users(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT fk_rating_driver
    FOREIGN KEY (driver_id) REFERENCES drivers(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  revoked_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_refresh_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  INDEX idx_refresh_lookup (user_id, revoked_at, expires_at)
);

-- Email one-time codes. `purpose` scopes a code to one flow (NULL =
-- registration, 'password_reset', 'change_password', 'driver_application').
CREATE TABLE IF NOT EXISTS otp_codes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(120) NOT NULL,
  purpose VARCHAR(40) NULL,
  code VARCHAR(6) NOT NULL,
  attempts INT UNSIGNED NOT NULL DEFAULT 0,
  is_verified TINYINT(1) NOT NULL DEFAULT 0,
  expires_at DATETIME NOT NULL,
  verified_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_otp_email_expires (email, expires_at),
  INDEX idx_otp_email_verified (email, is_verified)
);

-- notifications table for admin events
CREATE TABLE IF NOT EXISTS notifications (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NULL,
  recipient_role ENUM('everyone', 'driver', 'passenger', 'admin') NOT NULL DEFAULT 'everyone',
  sent_by BIGINT UNSIGNED NULL,
  type VARCHAR(80) NOT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT,
  metadata_json JSON DEFAULT NULL,
  is_read TINYINT DEFAULT 0,
  read_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT fk_notification_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_notification_sent_by
    FOREIGN KEY (sent_by) REFERENCES users(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  INDEX idx_notifications_recipient_read (recipient_role, is_read, created_at),
  INDEX idx_notifications_user_read (user_id, is_read, created_at),
  INDEX idx_notifications_deleted (deleted_at)
);

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
  license_birth_date DATE NULL,
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
  CONSTRAINT fk_driver_applications_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT fk_driver_applications_driver
    FOREIGN KEY (driver_id) REFERENCES drivers(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  CONSTRAINT fk_driver_applications_reviewed_by
    FOREIGN KEY (reviewed_by) REFERENCES users(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  INDEX idx_driver_applications_status_submitted (status, submitted_at),
  INDEX idx_driver_applications_user (user_id),
  INDEX idx_driver_applications_deleted (deleted_at)
);

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
  CONSTRAINT fk_booking_timeline_booking
    FOREIGN KEY (booking_id) REFERENCES bookings(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  INDEX idx_booking_timeline_booking_created (booking_id, created_at),
  INDEX idx_booking_timeline_deleted (deleted_at)
);

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
  CONSTRAINT fk_sos_booking
    FOREIGN KEY (booking_id) REFERENCES bookings(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  CONSTRAINT fk_sos_passenger
    FOREIGN KEY (passenger_id) REFERENCES users(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT fk_sos_driver
    FOREIGN KEY (driver_id) REFERENCES drivers(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  CONSTRAINT fk_sos_resolved_by
    FOREIGN KEY (resolved_by) REFERENCES users(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  INDEX idx_sos_status_created (status, created_at),
  INDEX idx_sos_deleted (deleted_at)
);

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
  CONSTRAINT fk_complaints_reporter
    FOREIGN KEY (reporter_id) REFERENCES users(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT fk_complaints_reported_user
    FOREIGN KEY (reported_user_id) REFERENCES users(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  CONSTRAINT fk_complaints_booking
    FOREIGN KEY (booking_id) REFERENCES bookings(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  CONSTRAINT fk_complaints_resolved_by
    FOREIGN KEY (resolved_by) REFERENCES users(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  INDEX idx_complaints_status_created (status, created_at),
  INDEX idx_complaints_reporter (reporter_id),
  INDEX idx_complaints_deleted (deleted_at)
);

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
  CONSTRAINT fk_favorite_destinations_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  INDEX idx_favorites_user_deleted (user_id, deleted_at)
);

CREATE TABLE IF NOT EXISTS barangays (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL UNIQUE,
  is_enabled TINYINT(1) NOT NULL DEFAULT 1,
  service_notes VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  INDEX idx_barangays_enabled_deleted (is_enabled, deleted_at)
);

CREATE TABLE IF NOT EXISTS system_settings (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  setting_key VARCHAR(120) NOT NULL UNIQUE,
  setting_value TEXT NULL,
  value_type ENUM('string', 'number', 'boolean', 'json') NOT NULL DEFAULT 'string',
  updated_by BIGINT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT fk_system_settings_updated_by
    FOREIGN KEY (updated_by) REFERENCES users(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  INDEX idx_system_settings_deleted (deleted_at)
);

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
  CONSTRAINT fk_activity_logs_admin
    FOREIGN KEY (admin_id) REFERENCES users(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  INDEX idx_activity_logs_created (created_at),
  INDEX idx_activity_logs_admin_created (admin_id, created_at),
  INDEX idx_activity_logs_target (target_type, target_id)
);

INSERT INTO system_settings (setting_key, setting_value, value_type)
VALUES
  ('app_name', 'FindMeTricycle', 'string'),
  ('support_email', 'support@findmetricycle.local', 'string'),
  ('contact_number', '09990000000', 'string'),
  ('operating_hours', '{"start":"05:00","end":"22:00"}', 'json')
ON DUPLICATE KEY UPDATE setting_key = VALUES(setting_key);
