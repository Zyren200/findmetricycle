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
// announcements admins themselves broadcast to users. Queries alias the
// notifications table as `n`.
const ADMIN_SCOPE =
  "n.user_id IS NULL AND n.recipient_role IN ('admin', 'everyone') AND n.type <> 'announcement'";

// One admin's slice of the admin feed. `viewer` is
// { userId, since, types }: `types` is the list of notification types their
// permissions cover (null = every type), and anything created before
// `since` (when their account was made) counts as already read.
function adminViewerFilter(viewer) {
  if (viewer.types === null) return { sql: "", params: [] };
  if (!viewer.types.length) return { sql: "AND 1 = 0", params: [] };
  return { sql: `AND n.type IN (${viewer.types.map(() => "?").join(", ")})`, params: [...viewer.types] };
}

// Admin read state lives in admin_notification_reads, one row per admin,
// since the notification row itself is shared by every admin.
function withAdminReadState(row) {
  if (!row) return null;
  const { admin_is_read: adminIsRead, admin_read_at: adminReadAt, ...rest } = row;
  return { ...rest, is_read: Number(adminIsRead) ? 1 : 0, read_at: adminReadAt || null };
}

const ADMIN_READ_COLUMNS = `
  n.*,
  (r.notification_id IS NOT NULL OR n.created_at < ?) AS admin_is_read,
  r.read_at AS admin_read_at
`;

async function listAnnouncements({ limit = 50 } = {}, client = db) {
  return client.query(
    `SELECT * FROM notifications
      WHERE deleted_at IS NULL AND type = 'announcement' AND user_id IS NULL
      ORDER BY created_at DESC
      LIMIT ?`,
    [Number(limit)]
  );
}

async function listForAdmin(viewer, { search = "", limit = 50, offset = 0 } = {}, client = db) {
  const term = `%${String(search || "").trim()}%`;
  const typeFilter = adminViewerFilter(viewer);
  const rows = await client.query(
    `
      SELECT ${ADMIN_READ_COLUMNS}
      FROM notifications n
      LEFT JOIN admin_notification_reads r ON r.notification_id = n.id AND r.admin_user_id = ?
      WHERE n.deleted_at IS NULL
        AND ${ADMIN_SCOPE}
        ${typeFilter.sql}
        AND (? = '' OR n.title LIKE ? OR n.body LIKE ? OR n.type LIKE ?)
      ORDER BY n.created_at DESC
      LIMIT ? OFFSET ?
    `,
    [
      viewer.since,
      viewer.userId,
      ...typeFilter.params,
      String(search || "").trim(),
      term,
      term,
      term,
      Number(limit),
      Number(offset),
    ]
  );
  return rows.map(withAdminReadState);
}

async function findForAdmin(viewer, notificationId, client = db) {
  const typeFilter = adminViewerFilter(viewer);
  const rows = await client.query(
    `
      SELECT ${ADMIN_READ_COLUMNS}
      FROM notifications n
      LEFT JOIN admin_notification_reads r ON r.notification_id = n.id AND r.admin_user_id = ?
      WHERE n.id = ? AND n.deleted_at IS NULL AND ${ADMIN_SCOPE} ${typeFilter.sql}
      LIMIT 1
    `,
    [viewer.since, viewer.userId, notificationId, ...typeFilter.params]
  );
  return withAdminReadState(rows[0]);
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

async function countUnreadForAdmin(viewer, client = db) {
  const typeFilter = adminViewerFilter(viewer);
  const [row] = await client.query(
    `SELECT COUNT(*) AS n FROM notifications n
      WHERE n.deleted_at IS NULL AND ${ADMIN_SCOPE} ${typeFilter.sql}
        AND n.created_at >= ?
        AND NOT EXISTS (
          SELECT 1 FROM admin_notification_reads r WHERE r.notification_id = n.id AND r.admin_user_id = ?
        )`,
    [...typeFilter.params, viewer.since, viewer.userId]
  );
  return Number(row?.n || 0);
}

// Marks it read for this admin only. Scoped to the admin feed and the
// admin's visible types, so it can't touch a passenger's or driver's own
// notifications or one the admin isn't allowed to see. Returns null then.
async function markReadForAdmin(viewer, notificationId, client = db) {
  const typeFilter = adminViewerFilter(viewer);
  await client.query(
    `INSERT IGNORE INTO admin_notification_reads (notification_id, admin_user_id)
      SELECT n.id, ? FROM notifications n
      WHERE n.id = ? AND n.deleted_at IS NULL AND ${ADMIN_SCOPE} ${typeFilter.sql}`,
    [viewer.userId, notificationId, ...typeFilter.params]
  );
  return findForAdmin(viewer, notificationId, client);
}

async function markAllReadForAdmin(viewer, client = db) {
  const typeFilter = adminViewerFilter(viewer);
  await client.query(
    `INSERT IGNORE INTO admin_notification_reads (notification_id, admin_user_id)
      SELECT n.id, ? FROM notifications n
      WHERE n.deleted_at IS NULL AND ${ADMIN_SCOPE} ${typeFilter.sql}
        AND n.created_at >= ?`,
    [viewer.userId, ...typeFilter.params, viewer.since]
  );
  return true;
}

module.exports = {
  listAnnouncements,
  createNotification,
  listForAdmin,
  findForAdmin,
  listForUser,
  markReadForAdmin,
  markAllReadForAdmin,
  countUnreadForAdmin,
  countUnreadForUser,
  markReadForUser,
};
