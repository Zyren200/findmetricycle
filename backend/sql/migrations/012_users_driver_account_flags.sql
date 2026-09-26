-- Multi-role account flags that previously only existed in the one-off
-- sql/v2-migration.sql, so databases created from schema.sql alone were
-- missing them. One statement per column so the migration runner can skip
-- whichever ones an existing database already has.

ALTER TABLE users
  ADD COLUMN driver_approval_status ENUM('none', 'pending', 'approved', 'rejected') NOT NULL DEFAULT 'none';

ALTER TABLE users
  ADD COLUMN is_driver_account TINYINT(1) NOT NULL DEFAULT 0;

ALTER TABLE users
  ADD INDEX idx_users_driver_approval (driver_approval_status);
