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

// The admin feed: notifications addressed to admins (or everyone) — never
// the personal ones sent to a specific passenger or driver, and not the
// announcements admins themselves broadcast to users.
const ADMIN_SCOPE =
  "user_id IS NULL AND recipient_role IN ('admin', 'everyone') AND type <> 'announcement'";

async function listAnnouncements({ limit = 50 } = {}, client = db) {
  return client.query(
    `SELECT * FROM notifications
      WHERE deleted_at IS NULL AND type = 'announcement' AND user_id IS NULL
      ORDER BY created_at DESC
      LIMIT ?`,
    [Number(limit)]
  );
}

async function listNotifications({ search = "", limit = 50, offset = 0 } = {}, client = db) {
  const term = `%${String(search || "").trim()}%`;
  return client.query(
    `
      SELECT *
      FROM notifications
      WHERE deleted_at IS NULL
        AND ${ADMIN_SCOPE}
        AND (? = '' OR title LIKE ? OR body LIKE ? OR type LIKE ?)
      ORDER BY created_at DESC
      LIMIT ? OFFSET ?
    `,
    [String(search || "").trim(), term, term, term, Number(limit), Number(offset)]
  );
}

// A user's feed for one app mode. One account can be both passenger and
// driver, so personal notifications are split by the role they were sent
// to — ride requests don't show up in the passenger app and vice versa.
const USER_SCOPE = `(
  (user_id = ? AND recipient_role IN (?, 'everyone'))
  OR (user_id IS NULL AND recipient_role IN ('everyone', ?))
)`;

async function listForUser(userId, { limit = 50, offset = 0, role = "passenger" } = {}, client = db) {
  return client.query(
    `
      SELECT *
      FROM notifications
      WHERE deleted_at IS NULL
        AND ${USER_SCOPE}
        AND type NOT LIKE 'wallet_%'
      ORDER BY created_at DESC
      LIMIT ? OFFSET ?
    `,
    [userId, role, role, Number(limit), Number(offset)]
  );
}

// Unread / mark-read cover the user's personal notifications only (a
// broadcast row is shared by everyone, so one user can't mark it read).
async function countUnreadForUser(userId, role, client = db) {
  const [row] = await client.query(
    `SELECT COUNT(*) AS n FROM notifications
      WHERE deleted_at IS NULL AND is_read = 0 AND user_id = ?
        AND recipient_role IN (?, 'everyone') AND type NOT LIKE 'wallet_%'`,
    [userId, role]
  );
  return Number(row?.n || 0);
}

async function markReadForUser(userId, role, ids = null, client = db) {
  const idFilter = Array.isArray(ids) && ids.length ? `AND id IN (${ids.map(() => "?").join(", ")})` : "";
  await client.query(
    `UPDATE notifications SET is_read = 1, read_at = COALESCE(read_at, NOW())
      WHERE deleted_at IS NULL AND is_read = 0 AND user_id = ?
        AND recipient_role IN (?, 'everyone') ${idFilter}`,
    [userId, role, ...(idFilter ? ids : [])]
  );
}

async function countUnreadForAdmin(client = db) {
  const [row] = await client.query(
    `SELECT COUNT(*) AS n FROM notifications WHERE deleted_at IS NULL AND is_read = 0 AND ${ADMIN_SCOPE}`
  );
  return Number(row?.n || 0);
}

// Scoped to the admin feed, so an admin action can never mark a
// passenger's or driver's own notifications as read.
async function markRead(notificationId, client = db) {
  await client.query(
    `UPDATE notifications SET is_read = 1, read_at = COALESCE(read_at, NOW()) WHERE id = ? AND deleted_at IS NULL AND ${ADMIN_SCOPE}`,
    [notificationId]
  );
  const rows = await client.query(
    `SELECT * FROM notifications WHERE id = ? AND deleted_at IS NULL AND ${ADMIN_SCOPE} LIMIT 1`,
    [notificationId]
  );
  return rows[0] || null;
}

async function markAllRead(client = db) {
  await client.query(
    `UPDATE notifications SET is_read = 1, read_at = COALESCE(read_at, NOW()) WHERE is_read = 0 AND deleted_at IS NULL AND ${ADMIN_SCOPE}`
  );
  return true;
}

module.exports = {
  listAnnouncements,
  createNotification,
  listNotifications,
  listForUser,
  markRead,
  markAllRead,
  countUnreadForAdmin,
  countUnreadForUser,
  markReadForUser,
};
