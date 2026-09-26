const db = require("../config/db");

async function createNotification(
  { type, title, body, metadataJson = null, userId = null, recipientRole = "everyone", sentBy = null },
  client = db
) {
  const result = await client.query(
    `
      INSERT INTO notifications (user_id, recipient_role, sent_by, type, title, body, metadata_json, is_read)
      VALUES (?, ?, ?, ?, ?, ?, ?, 0)
    `,
    [userId, recipientRole, sentBy, type, title, body, metadataJson]
  );
  const rows = await client.query("SELECT * FROM notifications WHERE id = ? AND deleted_at IS NULL LIMIT 1", [result.insertId]);
  return rows[0] || null;
}

async function listNotifications({ search = "", limit = 50, offset = 0 } = {}, client = db) {
  const term = `%${String(search || "").trim()}%`;
  return client.query(
    `
      SELECT *
      FROM notifications
      WHERE deleted_at IS NULL
        AND (? = '' OR title LIKE ? OR body LIKE ? OR type LIKE ?)
      ORDER BY created_at DESC
      LIMIT ? OFFSET ?
    `,
    [String(search || "").trim(), term, term, term, Number(limit), Number(offset)]
  );
}

async function listForUser(userId, { limit = 50, offset = 0, role = "passenger" } = {}, client = db) {
  return client.query(
    `
      SELECT *
      FROM notifications
      WHERE deleted_at IS NULL
        AND (user_id = ? OR (user_id IS NULL AND recipient_role IN ('everyone', ?)))
        AND type NOT LIKE 'wallet_%'
      ORDER BY created_at DESC
      LIMIT ? OFFSET ?
    `,
    [userId, role, Number(limit), Number(offset)]
  );
}

async function markRead(notificationId, client = db) {
  await client.query("UPDATE notifications SET is_read = 1, read_at = NOW() WHERE id = ? AND deleted_at IS NULL", [notificationId]);
  const rows = await client.query("SELECT * FROM notifications WHERE id = ? AND deleted_at IS NULL LIMIT 1", [notificationId]);
  return rows[0] || null;
}

async function markAllRead(client = db) {
  await client.query("UPDATE notifications SET is_read = 1, read_at = COALESCE(read_at, NOW()) WHERE is_read = 0 AND deleted_at IS NULL");
  return true;
}

module.exports = {
  createNotification,
  listNotifications,
  listForUser,
  markRead,
  markAllRead,
};
