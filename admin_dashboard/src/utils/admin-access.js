// Which permission each dashboard page needs. The signed-in admin's
// permission list comes from the backend (login and /auth/me), which also
// checks every request — hiding a page here is for clarity, not protection.
export const PERMISSIONS = {
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
  SOS_ESCALATIONS_RECEIVE: "sos.escalations",
  COMPLAINTS_VIEW: "complaints.view",
  COMPLAINTS_RESOLVE: "complaints.resolve",
  SUPPORT_VIEW: "support.view",
  SUPPORT_REPLY: "support.reply",
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

export const SECTION_PERMISSIONS = {
  dashboard: P.DASHBOARD_VIEW,
  live: P.LIVE_MAP_VIEW,
  users: P.USERS_VIEW,
  applications: P.DRIVER_APPLICATIONS_VIEW,
  drivers: P.DRIVERS_VIEW,
  bookings: P.BOOKINGS_VIEW,
  rides: P.RIDES_VIEW,
  sos: P.SOS_VIEW,
  complaints: P.COMPLAINTS_VIEW,
  support: P.SUPPORT_VIEW,
  notifications: P.NOTIFICATIONS_VIEW,
  announcements: P.ANNOUNCEMENTS_MANAGE,
  reports: P.REPORTS_VIEW,
  earnings: P.EARNINGS_VIEW,
  activity: P.ACTIVITY_LOGS_VIEW,
  barangays: P.BARANGAYS_MANAGE,
  fares: P.FARES_MANAGE,
  settings: P.SETTINGS_MANAGE,
  admins: P.ADMINS_MANAGE,
};

/** Whether the admin may open a page (unknown pages: no). */
export function canOpenSection(can, key) {
  const permission = SECTION_PERMISSIONS[key];
  return Boolean(permission && can(permission));
}

/** The first page in sidebar order the admin may open. */
export function firstAllowedSection(can, orderedKeys) {
  return orderedKeys.find((key) => canOpenSection(can, key)) || null;
}

// Plain-language summary of each role, for the Admin Accounts page.
export const ROLE_DESCRIPTIONS = {
  super_admin: "Everything, including admin accounts, fares, barangays and system settings.",
  operations_admin: "Day-to-day operations: users, drivers and applications, bookings, complaints, contact messages, announcements and reports.",
  sos_responder: "SOS alerts, the live map, and the bookings an SOS was raised on.",
};
