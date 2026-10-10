const db = require("../config/db");

async function createMessage({ name, email, subject = null, message, ipAddress = null }) {
  const result = await db.query(
    `
      INSERT INTO contact_messages (name, email, subject, message, status, ip_address)
      VALUES (?, ?, ?, ?, 'open', ?)
    `,
    [name, email, subject, message, ipAddress]
  );
  return findById(result.insertId);
}

async function findById(id) {
  const rows = await db.query("SELECT * FROM contact_messages WHERE id = ? LIMIT 1", [id]);
  return rows[0] || null;
}

// Newest first, open ones on top.
async function listForAdmin({ limit = 200 } = {}) {
  return db.query(
    `
      SELECT *
      FROM contact_messages
      ORDER BY (status = 'open') DESC, created_at DESC
      LIMIT ?
    `,
    [Number(limit)]
  );
}

async function listReplies(messageIds) {
  if (!messageIds.length) return [];
  const placeholders = messageIds.map(() => "?").join(", ");
  return db.query(
    `
      SELECT *
      FROM contact_message_replies
      WHERE message_id IN (${placeholders})
      ORDER BY created_at ASC, id ASC
    `,
    messageIds
  );
}

async function addReply({ messageId, adminId, adminName, body }) {
  await db.query(
    `
      INSERT INTO contact_message_replies (message_id, admin_id, admin_name, body)
      VALUES (?, ?, ?, ?)
    `,
    [messageId, adminId, adminName, body]
  );
}

async function setStatus(id, status) {
  await db.query("UPDATE contact_messages SET status = ? WHERE id = ?", [status, id]);
  return findById(id);
}

module.exports = {
  createMessage,
  findById,
  listForAdmin,
  listReplies,
  addReply,
  setStatus,
};
