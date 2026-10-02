-- Firebase Cloud Messaging tokens, one row per device: ride requests and
-- ride updates are pushed here so they reach the user while the app is in
-- the background or closed. A token moves to whoever logs in on the device.
CREATE TABLE IF NOT EXISTS push_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  token VARCHAR(255) CHARACTER SET ascii NOT NULL,
  platform VARCHAR(20) NOT NULL DEFAULT 'android',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_push_tokens_token (token),
  INDEX idx_push_tokens_user (user_id),
  CONSTRAINT fk_push_tokens_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);
