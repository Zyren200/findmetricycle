-- Driver Mode Phase 3 (ride-request timeout) + Phase 5 (passenger pickup PIN).
ALTER TABLE bookings
  ADD COLUMN offer_expires_at DATETIME NULL AFTER driver_id,
  ADD COLUMN pickup_pin_hash VARCHAR(100) NULL AFTER offer_expires_at,
  ADD COLUMN pin_attempts INT NOT NULL DEFAULT 0 AFTER pickup_pin_hash,
  ADD COLUMN pin_verified_at DATETIME NULL AFTER pin_attempts;

-- complaints/driver-reports table already exists in schema.sql (Phase 9) —
-- nothing to add here, just making sure this migration file is scoped to
-- Phase 3/5 as its name says.
