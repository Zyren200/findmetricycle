-- FindMeTricycle V2 Migration
-- Multi-role single account system, OTP authentication, Favorites

USE findme_tricycle;

-- 1. OTP Codes Table (for email verification)
CREATE TABLE IF NOT EXISTS otp_codes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(120) NOT NULL,
  code VARCHAR(6) NOT NULL,
  attempts INT UNSIGNED NOT NULL DEFAULT 0,
  is_verified TINYINT(1) NOT NULL DEFAULT 0,
  expires_at DATETIME NOT NULL,
  verified_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_otp_email_expires (email, expires_at),
  INDEX idx_otp_email_verified (email, is_verified)
);

-- 2. Favorite Destinations Table
CREATE TABLE IF NOT EXISTS favorite_destinations (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  nickname VARCHAR(120) NOT NULL,
  pickup_address VARCHAR(255) NOT NULL,
  pickup_lat DECIMAL(10, 7) NOT NULL,
  pickup_lng DECIMAL(10, 7) NOT NULL,
  destination_address VARCHAR(255) NOT NULL,
  destination_lat DECIMAL(10, 7) NOT NULL,
  destination_lng DECIMAL(10, 7) NOT NULL,
  frequency INT UNSIGNED NOT NULL DEFAULT 0,
  last_used DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT fk_favorite_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  INDEX idx_favorite_user_deleted (user_id, deleted_at),
  INDEX idx_favorite_last_used (user_id, last_used)
);

-- 3. Approval Notifications (to track which approvals the user has seen)
CREATE TABLE IF NOT EXISTS approval_notifications_seen (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL UNIQUE,
  seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_approval_notification_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- 4. Update users table to support multi-role (add driver approval status)
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS driver_approval_status ENUM('none', 'pending', 'approved', 'rejected') NOT NULL DEFAULT 'none',
ADD COLUMN IF NOT EXISTS is_driver_account TINYINT(1) NOT NULL DEFAULT 0,
ADD INDEX IF NOT EXISTS idx_users_driver_approval (driver_approval_status);

-- 5. Update drivers table to remove redundant approval_status field (use users.driver_approval_status instead)
-- Note: Keep approval_status for now for backwards compatibility, but new code should use users.driver_approval_status

-- 6. Payment methods Table (currently cash only, but extensible)
CREATE TABLE IF NOT EXISTS payment_methods (
  id TINYINT UNSIGNED PRIMARY KEY,
  name VARCHAR(60) NOT NULL,
  is_enabled TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO payment_methods (id, name, is_enabled) 
VALUES (1, 'cash', 1)
ON DUPLICATE KEY UPDATE id = id;
