const notificationModel = require("../models/notification.model");
const pushService = require("./push.service");
const {
  notificationPermission,
  permissionRoom,
  visibleNotificationTypes,
} = require("../constants/admin-permissions");

function sanitize(n) {
  if (!n) return null;
  return {
    id: n.id,
    type: n.type,
    title: n.title,
    body: n.body,
    metadata: n.metadata_json ? JSON.parse(n.metadata_json) : null,
    recipientRole: n.recipient_role,
    isRead: Boolean(n.is_read),
    createdAt: n.created_at,
  };
}

async function createNotification(payload) {
  const n = await notificationModel.createNotification({
    type: payload.type,
    title: payload.title,
    body: payload.body,
    metadataJson: payload.metadataJson ? JSON.stringify(payload.metadataJson) : null,
    userId: payload.userId || null,
    recipientRole: payload.recipientRole || "everyone",
    sentBy: payload.sentBy || null,
  });
  const sanitized = sanitize(n);

  try {
    // Lazy require avoids a circular dependency at module load time.
    const { getIO } = require("../sockets");
    const io = getIO();

    // Shared admin-feed rows only, and only to the admins whose
    // permissions cover this type (the same rule the feed itself uses).
    if (!payload.userId && ["admin", "everyone"].includes(payload.recipientRole || "everyone")) {
      io.to(permissionRoom(notificationPermission(sanitized.type))).emit("admin:notification_created", sanitized);
    }

    // A notification addressed to one user (driver or passenger) should
    // reach them live, not just sit there until they next pull the list.
    if (payload.userId) {
      io.to(`user:${payload.userId}`).emit("notification:created", sanitized);
    }
  } catch (err) {
    // Socket layer may not be initialized (e.g. in scripts/tests) — safe to ignore.
  }

  // And to their phone when the app isn't open. Not awaited: a slow push
  // must never hold up the ride flow (it never throws either).
  if (payload.userId) pushService.notifyUser(payload.userId, sanitized);

  return sanitized;
}

// An admin announcement: one shared row (no user_id) that shows up in the
// notification list of every passenger and/or driver, pushed live to
// everyone connected — the apps keep only the ones for their mode.
async function createAnnouncement({ title, body, audience = "everyone", sentBy = null }) {
  const n = await notificationModel.createNotification({
    type: "announcement",
    title,
    body,
    userId: null,
    recipientRole: audience,
    sentBy,
  });
  const sanitized = sanitize(n);
  try {
    const { getIO } = require("../sockets");
    getIO().emit("notification:created", sanitized);
  } catch (err) {
    // Socket layer may not be initialized (e.g. in scripts/tests) — safe to ignore.
  }
  pushService.notifyAudience(audience, sanitized);
  return sanitized;
}

async function listAnnouncements({ limit = 50 } = {}) {
  const rows = await notificationModel.listAnnouncements({ limit });
  return rows.map(sanitize);
}

// The admin feed is per admin: only the types their permissions cover,
// with their own read state. `admin` is req.admin.
function adminViewer(admin) {
  return {
    userId: admin.userId,
    since: admin.since,
    types: visibleNotificationTypes(admin.permissions),
  };
}

async function listForAdmin(admin, filters = {}) {
  const rows = await notificationModel.listForAdmin(adminViewer(admin), filters);
  return rows.map(sanitize);
}

async function markReadForAdmin(admin, id) {
  const row = await notificationModel.markReadForAdmin(adminViewer(admin), id);
  return sanitize(row);
}

async function countUnreadForAdmin(admin) {
  return notificationModel.countUnreadForAdmin(adminViewer(admin));
}

async function markAllReadForAdmin(admin) {
  await notificationModel.markAllReadForAdmin(adminViewer(admin));
  return true;
}

module.exports = {
  createAnnouncement,
  listAnnouncements,
  createNotification,
  listForAdmin,
  markReadForAdmin,
  markAllReadForAdmin,
  countUnreadForAdmin,
};
