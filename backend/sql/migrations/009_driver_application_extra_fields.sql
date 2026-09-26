-- Additional applicant-supplied fields collected by the Driver Application
-- Website (personal + driver info steps) that had no column to land in yet.
ALTER TABLE driver_applications
  ADD COLUMN address VARCHAR(255) NULL AFTER phone,
  ADD COLUMN emergency_contact_name VARCHAR(120) NULL AFTER address,
  ADD COLUMN emergency_contact_phone VARCHAR(20) NULL AFTER emergency_contact_name,
  ADD COLUMN license_type VARCHAR(40) NULL AFTER license_number,
  ADD COLUMN franchise_number VARCHAR(60) NULL AFTER plate_number;
