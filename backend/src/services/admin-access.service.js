// Who an admin is and what they may do, read fresh from the database on
// every request and socket connection — so a role change or a disabled
// account takes effect immediately instead of when the token expires.
const adminAccountModel = require("../models/admin-account.model");
const refreshTokenModel = require("../models/refresh-token.model");
const ApiError = require("../utils/api-error");
const { ROLE_LABELS, permissionsForRole } = require("../constants/admin-permissions");

/** The admin behind a user id, or null when it isn't an admin account. */
async function loadAdminContext(userId, client) {
  let row;
  try {
    row = await adminAccountModel.findByUserId(userId, client);
  } catch (error) {
    if (error.code === "ER_BAD_FIELD_ERROR") {
      throw new ApiError(503, "Admin roles need a database update. Run `npm run migrate` on the backend.");
    }
    throw error;
  }
  if (!row) return null;
  return {
    userId: Number(row.user_id),
    role: row.admin_role,
    status: row.status,
    since: row.created_at,
    permissions: permissionsForRole(row.admin_role),
  };
}

/** What the dashboard needs to know about the signed-in admin. */
function describeAdmin(context) {
  if (!context) return null;
  return {
    role: context.role,
    roleLabel: ROLE_LABELS[context.role] || context.role,
    status: context.status,
    permissions: context.permissions,
  };
}

/**
 * Ends every session of an admin whose access just changed: refresh tokens
 * are revoked (no new access tokens) and live sockets are dropped, so no
 * more admin events reach them. With a `reason` ("disabled",
 * "role_changed"), their open dashboard is told first so it can sign out
 * with an explanation instead of failing on the next request.
 */
async function signOutEverywhere(userId, { reason = null } = {}) {
  await refreshTokenModel.revokeAllByUserId(userId);
  try {
    // Lazy require: the socket layer itself depends on this service.
    const { getIO } = require("../sockets");
    const io = getIO();
    const room = `user:${userId}`;
    if (!reason) {
      io.in(room).disconnectSockets(true);
      return;
    }
    io.to(room).emit("admin:access_changed", { reason });
    // A moment for that message to arrive before the connection is cut.
    const timer = setTimeout(() => io.in(room).disconnectSockets(true), 500);
    if (typeof timer.unref === "function") timer.unref();
  } catch (_) {
    // Socket layer not initialized (tests, scripts).
  }
}

module.exports = {
  loadAdminContext,
  describeAdmin,
  signOutEverywhere,
};
