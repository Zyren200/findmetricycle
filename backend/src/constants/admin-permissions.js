// Admin roles and what each may do — the single source of truth. Backend
// middleware checks these permissions (never role names), and the admin
// dashboard gets the signed-in admin's permission list from the API instead
// of keeping its own copy.

const ADMIN_ROLES = {
  SUPER_ADMIN: "super_admin",
  OPERATIONS_ADMIN: "operations_admin",
  SOS_RESPONDER: "sos_responder",
};

const ROLE_LABELS = {
  super_admin: "Super Admin",
  operations_admin: "Operations Admin",
  sos_responder: "SOS Responder",
};

const PERMISSIONS = {
  DASHBOARD_VIEW: "dashboard.view",
  LIVE_MAP_VIEW: "live_map.view",
  USERS_VIEW: "users.view",
  USERS_MANAGE: "users.manage",
  DRIVER_APPLICATIONS_VIEW: "driver_applications.view",
  DRIVER_APPLICATIONS_REVIEW: "driver_applications.review",
  DRIVERS_VIEW: "drivers.view",
  DRIVERS_MANAGE: "drivers.manage",
  BOOKINGS_VIEW: "bookings.view",
  BOOKINGS_CLOSE: "bookings.close",
  RIDES_VIEW: "rides.view",
  SOS_VIEW: "sos.view",
  SOS_RESPOND: "sos.respond",
  // Alerted when an SOS stays open too long (Super Admins).
  SOS_ESCALATIONS_RECEIVE: "sos.escalations",
  COMPLAINTS_VIEW: "complaints.view",
  COMPLAINTS_RESOLVE: "complaints.resolve",
  NOTIFICATIONS_VIEW: "notifications.view",
  ANNOUNCEMENTS_MANAGE: "announcements.manage",
  REPORTS_VIEW: "reports.view",
  EARNINGS_VIEW: "earnings.view",
  ACTIVITY_LOGS_VIEW: "activity_logs.view",
  BARANGAYS_MANAGE: "barangays.manage",
  FARES_MANAGE: "fares.manage",
  SETTINGS_MANAGE: "settings.manage",
  ADMINS_MANAGE: "admins.manage",
};

const P = PERMISSIONS;

const ROLE_PERMISSIONS = {
  [ADMIN_ROLES.SUPER_ADMIN]: Object.values(PERMISSIONS),
  [ADMIN_ROLES.OPERATIONS_ADMIN]: [
    P.DASHBOARD_VIEW,
    P.LIVE_MAP_VIEW,
    P.USERS_VIEW,
    P.USERS_MANAGE,
    P.DRIVER_APPLICATIONS_VIEW,
    P.DRIVER_APPLICATIONS_REVIEW,
    P.DRIVERS_VIEW,
    P.DRIVERS_MANAGE,
    P.BOOKINGS_VIEW,
    P.BOOKINGS_CLOSE,
    P.RIDES_VIEW,
    P.COMPLAINTS_VIEW,
    P.COMPLAINTS_RESOLVE,
    P.NOTIFICATIONS_VIEW,
    P.ANNOUNCEMENTS_MANAGE,
    P.REPORTS_VIEW,
  ],
  [ADMIN_ROLES.SOS_RESPONDER]: [P.DASHBOARD_VIEW, P.LIVE_MAP_VIEW, P.SOS_VIEW, P.SOS_RESPOND, P.NOTIFICATIONS_VIEW],
};

// Which permission an admin needs to see each admin notification type.
// Types not listed here are shown only to admins who manage admins.
const NOTIFICATION_TYPE_PERMISSIONS = {
  driver_application: P.DRIVER_APPLICATIONS_VIEW,
  driver_document_resubmission: P.DRIVER_APPLICATIONS_VIEW,
  driver_documents_flagged: P.DRIVER_APPLICATIONS_VIEW,
  sos_alert: P.SOS_VIEW,
  sos_escalation: P.SOS_ESCALATIONS_RECEIVE,
  driver_report: P.COMPLAINTS_VIEW,
  new_booking: P.BOOKINGS_VIEW,
  booking_cancelled: P.BOOKINGS_VIEW,
};

const UNLISTED_NOTIFICATION_PERMISSION = P.ADMINS_MANAGE;

function isAdminRole(role) {
  return Object.prototype.hasOwnProperty.call(ROLE_PERMISSIONS, role);
}

function permissionsForRole(role) {
  return isAdminRole(role) ? [...ROLE_PERMISSIONS[role]] : [];
}

function notificationPermission(type) {
  return NOTIFICATION_TYPE_PERMISSIONS[type] || UNLISTED_NOTIFICATION_PERMISSION;
}

/**
 * Notification types the admin may see: null means every type (admins who
 * can see unlisted types see everything), otherwise an explicit list.
 */
function visibleNotificationTypes(permissions) {
  const granted = new Set(permissions);
  if (granted.has(UNLISTED_NOTIFICATION_PERMISSION)) return null;
  return Object.entries(NOTIFICATION_TYPE_PERMISSIONS)
    .filter(([, permission]) => granted.has(permission))
    .map(([type]) => type);
}

// Socket.IO room for everyone holding a permission, so events reach only
// the admins allowed to see them.
function permissionRoom(permission) {
  return `perm:${permission}`;
}

module.exports = {
  ADMIN_ROLES,
  ROLE_LABELS,
  PERMISSIONS,
  ROLE_PERMISSIONS,
  NOTIFICATION_TYPE_PERMISSIONS,
  isAdminRole,
  permissionsForRole,
  notificationPermission,
  visibleNotificationTypes,
  permissionRoom,
};
