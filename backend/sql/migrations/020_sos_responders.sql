-- SOS handling for several responders: open ('active') → acknowledged →
-- resolved. Only one admin can acknowledge an alert (the service updates it
-- only while it is still open); the resolution note says what was done.
ALTER TABLE sos_alerts MODIFY status ENUM('active', 'acknowledged', 'resolved', 'dismissed', 'archived') NOT NULL DEFAULT 'active';
ALTER TABLE sos_alerts ADD COLUMN acknowledged_by BIGINT UNSIGNED NULL;
ALTER TABLE sos_alerts ADD COLUMN acknowledged_at DATETIME NULL;
ALTER TABLE sos_alerts ADD COLUMN resolution_note VARCHAR(500) NULL;
-- Set once, when an alert still open past the escalation time was sent to
-- the Super Admins.
ALTER TABLE sos_alerts ADD COLUMN escalated_at DATETIME NULL;
-- Who pressed SOS. passenger_id is always the ride's passenger, even when
-- the driver sent the alert, so it can't say who to tell it's being handled.
ALTER TABLE sos_alerts ADD COLUMN triggered_by_user_id BIGINT UNSIGNED NULL;
ALTER TABLE sos_alerts ADD COLUMN triggered_by_role ENUM('passenger', 'driver') NULL;

SET @db_name = DATABASE();
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = @db_name AND TABLE_NAME = 'sos_alerts' AND CONSTRAINT_NAME = 'fk_sos_acknowledged_by');
SET @sql = IF(@exists = 0, 'ALTER TABLE sos_alerts ADD CONSTRAINT fk_sos_acknowledged_by FOREIGN KEY (acknowledged_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = @db_name AND TABLE_NAME = 'sos_alerts' AND CONSTRAINT_NAME = 'fk_sos_triggered_by');
SET @sql = IF(@exists = 0, 'ALTER TABLE sos_alerts ADD CONSTRAINT fk_sos_triggered_by FOREIGN KEY (triggered_by_user_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Alerts that were already open before this change shouldn't all escalate
-- at once the moment the server restarts.
UPDATE sos_alerts SET escalated_at = created_at WHERE status = 'active' AND escalated_at IS NULL AND created_at < NOW() - INTERVAL 10 MINUTE;
