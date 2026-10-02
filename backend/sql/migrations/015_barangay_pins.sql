-- Barangay pins: each barangay gets an approximate centre point so a
-- pickup / drop-off can be matched to the barangay with the nearest pin.
-- That is how "Disabled" in the admin Barangay Manager blocks bookings.
-- The 60 Guiuan barangays and their pins are inserted on server start from
-- src/data/guiuan-barangays.js (see barangay.service.js).
ALTER TABLE barangays ADD COLUMN lat DECIMAL(10, 7) NULL;
ALTER TABLE barangays ADD COLUMN lng DECIMAL(10, 7) NULL;

-- System settings: the admin Settings page saves camelCase keys
-- (appName, supportEmail, ...). The original snake_case seed rows were
-- never read by anything — retire them so there's one copy of each value.
UPDATE system_settings
SET deleted_at = NOW()
WHERE setting_key IN ('app_name', 'support_email', 'contact_number', 'operating_hours')
  AND deleted_at IS NULL;
