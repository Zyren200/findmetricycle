const ApiError = require("../utils/api-error");
const roles = require("../constants/roles");
const db = require("../config/db");
const { PERMISSIONS } = require("../constants/admin-permissions");
const { loadAdminContext } = require("../services/admin-access.service");

// Runs after authMiddleware: makes sure req.admin holds the admin's role,
// status and permissions ({ userId, role, status, since, permissions }),
// read from the database on this request. A disabled admin gets 401 so the
// dashboard signs them out.
async function requireActiveAdmin(req, _res, next) {
  try {
    if (!req.user) throw new ApiError(401, "Unauthorized");
    if (req.user.role !== roles.ADMIN) throw new ApiError(403, "Forbidden for this role.");

    const admin = req.admin || (await loadAdminContext(req.user.id));
    if (!admin) throw new ApiError(403, "Admin account not found.");
    if (admin.status !== "active") throw new ApiError(401, "This admin account has been disabled.");

    req.admin = admin;
    return next();
  } catch (error) {
    return next(error);
  }
}

function hasPermission(req, permission) {
  return Boolean(req.admin && req.admin.permissions.includes(permission));
}

function deny(next) {
  return next(new ApiError(403, "You do not have permission to do this."));
}

// Guards are tagged with the permissions they check so a test can confirm
// every admin route has one.
function tagGuard(guard, permissions) {
  guard.requiredPermissions = permissions;
  return guard;
}

/** Every listed permission is required. */
function requirePermission(...permissions) {
  return tagGuard((req, _res, next) => {
    if (!req.admin) return next(new ApiError(401, "Unauthorized"));
    return permissions.every((p) => hasPermission(req, p)) ? next() : deny(next);
  }, permissions);
}

/** Any one of the listed permissions is enough. */
function requireAnyPermission(...permissions) {
  return tagGuard((req, _res, next) => {
    if (!req.admin) return next(new ApiError(401, "Unauthorized"));
    return permissions.some((p) => hasPermission(req, p)) ? next() : deny(next);
  }, permissions);
}

// A booking's details: anyone who can view bookings, or an SOS responder
// opening the booking an SOS alert was raised on.
const requireBookingAccess = tagGuard(
  async (req, _res, next) => {
    try {
      if (!req.admin) return next(new ApiError(401, "Unauthorized"));
      if (hasPermission(req, PERMISSIONS.BOOKINGS_VIEW)) return next();
      if (hasPermission(req, PERMISSIONS.SOS_VIEW)) {
        const bookingId = Number(req.params.bookingId);
        const rows = await db.query("SELECT id FROM sos_alerts WHERE booking_id = ? AND deleted_at IS NULL LIMIT 1", [bookingId]);
        if (rows.length > 0) return next();
      }
      return deny(next);
    } catch (error) {
      return next(error);
    }
  },
  [PERMISSIONS.BOOKINGS_VIEW, PERMISSIONS.SOS_VIEW]
);

module.exports = {
  requireActiveAdmin,
  requirePermission,
  requireAnyPermission,
  requireBookingAccess,
  hasPermission,
};
