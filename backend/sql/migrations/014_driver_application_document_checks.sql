-- Server-side document checks: the uploaded license / permit photos are
-- OCR'd on the server and classified, so a wrong document (a certificate,
-- a random photo) is flagged to the admin instead of silently passing.
-- Status: verified | suspicious | unreadable | error.
ALTER TABLE driver_applications ADD COLUMN license_check_status VARCHAR(20) NULL;
ALTER TABLE driver_applications ADD COLUMN permit_check_status VARCHAR(20) NULL;
ALTER TABLE driver_applications ADD COLUMN document_check_json TEXT NULL;
ALTER TABLE driver_applications ADD COLUMN documents_checked_at DATETIME NULL;
