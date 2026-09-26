-- Supports the Passenger Profile & Settings update: an editable address
-- field on the shared users table (no separate passenger-profile table
-- needed — this keeps the single-account model intact).
ALTER TABLE users
  ADD COLUMN address VARCHAR(255) NULL AFTER email;
