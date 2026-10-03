-- Multiple admin accounts with roles (super_admin, operations_admin,
-- sos_responder). Permissions per role live in
-- src/constants/admin-permissions.js. The default role is the least
-- privileged one, so a row inserted without a role can't do much.
ALTER TABLE admins ADD COLUMN admin_role ENUM('super_admin', 'operations_admin', 'sos_responder') NOT NULL DEFAULT 'sos_responder';
ALTER TABLE admins ADD COLUMN status ENUM('active', 'disabled') NOT NULL DEFAULT 'active';
ALTER TABLE admins ADD COLUMN created_by BIGINT UNSIGNED NULL;
ALTER TABLE admins ADD COLUMN last_login_at DATETIME NULL;
ALTER TABLE admins ADD COLUMN password_set_at DATETIME NULL;
ALTER TABLE admins ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- The foreign key only when missing: a fresh install already has it from
-- schema.sql, and MySQL reports a duplicate constraint as a generic
-- "can't create table" error the migration runner can't safely skip.
SET @db_name = DATABASE();
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = @db_name AND TABLE_NAME = 'admins' AND CONSTRAINT_NAME = 'fk_admins_created_by');
SET @sql = IF(@exists = 0, 'ALTER TABLE admins ADD CONSTRAINT fk_admins_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Admins that existed before roles had full access, so they become Super
-- Admins. Only those: an admin made after roles existed always has
-- password_set_at (first admin signup) or created_by (added by a Super
-- Admin), so running this migration late can never promote them.
UPDATE admins
SET admin_role = 'super_admin', status = 'active', password_set_at = created_at
WHERE password_set_at IS NULL AND created_by IS NULL;

-- Admin notifications are shared rows, so "read" is now tracked per admin
-- here instead of in notifications.is_read. No foreign key on
-- notification_id: notifications.id is signed on databases created by
-- older migrations (unsigned on fresh installs), and notifications are only
-- ever soft-deleted, so a read row can't point at a missing notification.
CREATE TABLE IF NOT EXISTS admin_notification_reads (
  notification_id BIGINT UNSIGNED NOT NULL,
  admin_user_id BIGINT UNSIGNED NOT NULL,
  read_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (notification_id, admin_user_id),
  INDEX idx_admin_notification_reads_admin (admin_user_id),
  CONSTRAINT fk_admin_notification_reads_admin
    FOREIGN KEY (admin_user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Keep what the existing admin had already read.
INSERT IGNORE INTO admin_notification_reads (notification_id, admin_user_id, read_at)
SELECT n.id, a.user_id, COALESCE(n.read_at, NOW())
FROM notifications n
CROSS JOIN admins a
WHERE n.is_read = 1
  AND n.user_id IS NULL
  AND n.recipient_role IN ('admin', 'everyone')
  AND n.deleted_at IS NULL;

-- The acting admin's name at the time of the action, alongside admin_id.
ALTER TABLE activity_logs ADD COLUMN admin_name VARCHAR(120) NULL;
UPDATE activity_logs al JOIN users u ON u.id = al.admin_id SET al.admin_name = u.full_name WHERE al.admin_name IS NULL;
