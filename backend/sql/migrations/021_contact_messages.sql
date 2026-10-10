-- Messages sent from the website's Contact page, and the admins' replies
-- (each reply is emailed to the sender's address).
CREATE TABLE IF NOT EXISTS contact_messages (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(190) NOT NULL,
  subject VARCHAR(160) NULL,
  message TEXT NOT NULL,
  status ENUM('open', 'replied', 'closed') NOT NULL DEFAULT 'open',
  ip_address VARCHAR(45) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_contact_messages_status_created (status, created_at)
);

CREATE TABLE IF NOT EXISTS contact_message_replies (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  message_id BIGINT UNSIGNED NOT NULL,
  admin_id BIGINT UNSIGNED NULL,
  admin_name VARCHAR(120) NULL,
  body TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_contact_replies_message
    FOREIGN KEY (message_id) REFERENCES contact_messages(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_contact_replies_admin
    FOREIGN KEY (admin_id) REFERENCES users(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  INDEX idx_contact_replies_message (message_id, created_at)
);
