const notificationModel = require("../models/notification.model");

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

    if (["admin", "everyone"].includes(payload.recipientRole || "everyone")) {
      io.to("role:admin").emit("admin:notification_created", sanitized);
    }

    // A notification addressed to one user (driver or passenger) should
    // reach them live, not just sit there until they next pull the list.
    if (payload.userId) {
      io.to(`user:${payload.userId}`).emit("notification:created", sanitized);
    }
  } catch (err) {
    // Socket layer may not be initialized (e.g. in scripts/tests) — safe to ignore.
  }

  return sanitized;
}

async function listNotifications(filters = {}) {
  const rows = await notificationModel.listNotifications(filters);
  return rows.map(sanitize);
}

async function markRead(id) {
  const row = await notificationModel.markRead(id);
  return sanitize(row);
}

async function countUnreadForAdmin() {
  return notificationModel.countUnreadForAdmin();
}

async function markAllRead() {
  await notificationModel.markAllRead();
  return true;
}

module.exports = {
  createNotification,
  listNotifications,
  markRead,
  markAllRead,
  countUnreadForAdmin,
};
