const express = require("express");
const adminController = require("../controllers/admin.controller");
const adminAccountsController = require("../controllers/admin-accounts.controller");
const authMiddleware = require("../middlewares/auth.middleware");
const requireRole = require("../middlewares/role.middleware");
const roles = require("../constants/roles");
const validate = require("../middlewares/validate.middleware");
const adminSchema = require("../validations/admin.schema");
const adminAudit = require("../middlewares/adminAudit.middleware");
const {
  requireActiveAdmin,
  requirePermission: can,
  requireAnyPermission: canAny,
  requireBookingAccess,
} = require("../middlewares/adminAccess.middleware");
const { PERMISSIONS: P } = require("../constants/admin-permissions");

const router = express.Router();

// Every route below also names the permission it needs — the role check
// alone only says "some admin". tests/admin-route-permissions.test.js fails
// if a route is added without one.
router.use(authMiddleware, requireRole(roles.ADMIN), requireActiveAdmin, adminAudit);

router.get("/drivers", can(P.DRIVERS_VIEW), adminController.getAllDrivers);
router.get("/drivers/pending", can(P.DRIVER_APPLICATIONS_VIEW), adminController.getPendingDrivers);
router.get(
  "/drivers/licenses",
  can(P.DRIVERS_VIEW),
  validate(adminSchema.driverLicenseQuerySchema),
  adminController.getDriverLicenseExpirations
);
// The application includes the license, permit and selfie photos.
router.get(
  "/drivers/:driverId",
  can(P.DRIVER_APPLICATIONS_VIEW),
  validate(adminSchema.driverParamSchema),
  adminController.getDriverApplication
);
router.get(
  "/drivers/:driverId/timeline",
  can(P.DRIVER_APPLICATIONS_VIEW),
  validate(adminSchema.driverParamSchema),
  adminController.getDriverApplicationTimeline
);
router.post(
  "/drivers/:driverId/approve",
  can(P.DRIVER_APPLICATIONS_REVIEW),
  validate(adminSchema.driverParamSchema),
  adminController.approveDriver
);
router.post(
  "/drivers/:driverId/revoke",
  can(P.DRIVERS_MANAGE),
  validate(adminSchema.driverParamSchema),
  adminController.revokeDriverApproval
);
router.post(
  "/drivers/:driverId/reject",
  can(P.DRIVER_APPLICATIONS_REVIEW),
  validate(adminSchema.rejectDriverSchema),
  adminController.rejectDriver
);

router.get("/driver-applications", can(P.DRIVER_APPLICATIONS_VIEW), adminController.getPendingDrivers);
router.get(
  "/driver-applications/:driverId",
  can(P.DRIVER_APPLICATIONS_VIEW),
  validate(adminSchema.driverParamSchema),
  adminController.getDriverApplication
);
router.post(
  "/driver-applications/:driverId/approve",
  can(P.DRIVER_APPLICATIONS_REVIEW),
  validate(adminSchema.driverParamSchema),
  adminController.approveDriver
);
router.post(
  "/driver-applications/:driverId/reject",
  can(P.DRIVER_APPLICATIONS_REVIEW),
  validate(adminSchema.rejectDriverSchema),
  adminController.rejectDriver
);

router.post(
  "/drivers/:driverId/request-correction",
  can(P.DRIVER_APPLICATIONS_REVIEW),
  validate(adminSchema.requestCorrectionSchema),
  adminController.postRequestCorrection
);

router.post(
  "/drivers/:driverId/suspend",
  can(P.DRIVERS_MANAGE),
  validate(adminSchema.driverParamSchema),
  adminController.postSuspendDriver
);

router.post(
  "/drivers/:driverId/reinstate",
  can(P.DRIVERS_MANAGE),
  validate(adminSchema.driverParamSchema),
  adminController.postReinstateDriver
);

router.get("/passengers", can(P.USERS_VIEW), adminController.getAllPassengers);

router.post("/passengers/:passengerId/suspend", can(P.USERS_MANAGE), adminController.postSuspendPassenger);
router.post("/passengers/:passengerId/reinstate", can(P.USERS_MANAGE), adminController.postReinstatePassenger);

router.get("/rides/history", can(P.RIDES_VIEW), adminController.getRideHistory);
router.get("/approvals/pending", can(P.DRIVER_APPLICATIONS_VIEW), adminController.getPendingApprovals);

router.get("/fare", can(P.FARES_MANAGE), adminController.getFare);
router.put("/fare", can(P.FARES_MANAGE), validate(adminSchema.fareUpdateSchema), adminController.setFare);

router.get("/live-map", can(P.LIVE_MAP_VIEW), adminController.getLiveMap);
// The summary itself drops the figures the admin isn't allowed to see.
router.get("/dashboard", can(P.DASHBOARD_VIEW), adminController.getDashboard);
// Earnings columns are dropped without earnings.view.
router.get("/reports/ride-activity", canAny(P.REPORTS_VIEW, P.EARNINGS_VIEW), adminController.getRideActivity);
router.get("/bookings", can(P.BOOKINGS_VIEW), adminController.getBookings);
router.get("/bookings/:bookingId", requireBookingAccess, adminController.getBookingDetail);
router.post(
  "/bookings/:bookingId/close",
  can(P.BOOKINGS_CLOSE),
  validate(adminSchema.bookingCloseSchema),
  adminController.postCloseBooking
);
router.get("/sos", can(P.SOS_VIEW), adminController.getSosAlerts);
// Open → acknowledged ("I'm handling this", one admin only) → resolved
// with a note.
router.post(
  "/sos/:id/acknowledge",
  can(P.SOS_RESPOND),
  validate(adminSchema.sosParamSchema),
  adminController.acknowledgeSosAlert
);
router.post(
  "/sos/:id/resolve",
  can(P.SOS_RESPOND),
  validate(adminSchema.sosResolveSchema),
  adminController.resolveSosAlert
);
router.get("/complaints", can(P.COMPLAINTS_VIEW), adminController.getComplaints);
router.post(
  "/complaints/:id/resolve",
  can(P.COMPLAINTS_RESOLVE),
  validate(adminSchema.complaintResolveSchema),
  adminController.resolveComplaint
);
// Each admin sees only the notification types their permissions cover,
// with their own read state.
router.get("/notifications", can(P.NOTIFICATIONS_VIEW), adminController.getNotifications);
router.post("/notifications/:id/read", can(P.NOTIFICATIONS_VIEW), adminController.postMarkNotificationRead);
router.post("/notifications/mark_all_read", can(P.NOTIFICATIONS_VIEW), adminController.postMarkAllNotificationsRead);
// Announcements: broadcast to every passenger, every driver, or both.
router.get("/announcements", can(P.ANNOUNCEMENTS_MANAGE), adminController.getAnnouncements);
router.post(
  "/announcements",
  can(P.ANNOUNCEMENTS_MANAGE),
  validate(adminSchema.announcementSchema),
  adminController.postAnnouncement
);

router.get("/activity-logs", can(P.ACTIVITY_LOGS_VIEW), adminController.getActivityLogs);

router.get("/barangays", can(P.BARANGAYS_MANAGE), adminController.getBarangays);
router.put(
  "/barangays/:barangayId",
  can(P.BARANGAYS_MANAGE),
  validate(adminSchema.barangayUpdateSchema),
  adminController.putBarangay
);

// Admin Accounts. The safety rules (not yourself, never the last Super
// Admin) are enforced in admin-accounts.service.
router.get("/admins", can(P.ADMINS_MANAGE), adminAccountsController.list);
router.post("/admins", can(P.ADMINS_MANAGE), validate(adminSchema.createAdminSchema), adminAccountsController.create);
router.put(
  "/admins/:userId/role",
  can(P.ADMINS_MANAGE),
  validate(adminSchema.adminRoleSchema),
  adminAccountsController.changeRole
);
router.post(
  "/admins/:userId/disable",
  can(P.ADMINS_MANAGE),
  validate(adminSchema.adminParamSchema),
  adminAccountsController.disable
);
router.post(
  "/admins/:userId/enable",
  can(P.ADMINS_MANAGE),
  validate(adminSchema.adminParamSchema),
  adminAccountsController.enable
);
router.post(
  "/admins/:userId/send-password-reset",
  can(P.ADMINS_MANAGE),
  validate(adminSchema.adminParamSchema),
  adminAccountsController.sendPasswordReset
);

router.get("/settings", can(P.SETTINGS_MANAGE), adminController.getSystemSettings);
router.put(
  "/settings",
  can(P.SETTINGS_MANAGE),
  validate(adminSchema.systemSettingsSchema),
  adminController.putSystemSettings
);

module.exports = router;
