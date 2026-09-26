-- Supports the Driver Application Website: an audit trail of every
-- application status change (for the applicant-facing timeline), and
-- purpose-binding for OTP codes so a code issued for one flow (e.g.
-- registration) can't be replayed to verify a different flow (e.g. the
-- driver-application login step).

CREATE TABLE IF NOT EXISTS application_status_history (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  application_id BIGINT UNSIGNED NOT NULL,
  status VARCHAR(30) NOT NULL,
  note TEXT NULL,
  changed_by BIGINT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_status_history_application
    FOREIGN KEY (application_id) REFERENCES driver_applications(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_status_history_admin
    FOREIGN KEY (changed_by) REFERENCES users(id)
    ON DELETE SET NULL,
  INDEX idx_status_history_application (application_id, created_at)
);

ALTER TABLE otp_codes
  ADD COLUMN purpose VARCHAR(40) NULL AFTER email;
