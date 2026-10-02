const express = require("express");
const adminController = require("../controllers/admin.controller");
const authMiddleware = require("../middlewares/auth.middleware");
const requireRole = require("../middlewares/role.middleware");
const roles = require("../constants/roles");
const validate = require("../middlewares/validate.middleware");
const adminSchema = require("../validations/admin.schema");

const router = express.Router();

const adminAudit = require("../middlewares/adminAudit.middleware");

router.use(authMiddleware, requireRole(roles.ADMIN), adminAudit);

router.get("/drivers", adminController.getAllDrivers);
router.get("/drivers/pending", adminController.getPendingDrivers);
router.get(
  "/drivers/licenses",
  validate(adminSchema.driverLicenseQuerySchema),
  adminController.getDriverLicenseExpirations
);
router.get("/drivers/:driverId", validate(adminSchema.driverParamSchema), adminController.getDriverApplication);
router.get(
  "/drivers/:driverId/timeline",
  validate(adminSchema.driverParamSchema),
  adminController.getDriverApplicationTimeline
);
router.post(
  "/drivers/:driverId/approve",
  validate(adminSchema.driverParamSchema),
  adminController.approveDriver
);
router.post(
  "/drivers/:driverId/revoke",
  validate(adminSchema.driverParamSchema),
  adminController.revokeDriverApproval
);
router.post(
  "/drivers/:driverId/reject",
  validate(adminSchema.rejectDriverSchema),
  adminController.rejectDriver
);

router.get("/driver-applications", adminController.getPendingDrivers);
router.get(
  "/driver-applications/:driverId",
  validate(adminSchema.driverParamSchema),
  adminController.getDriverApplication
);
router.post(
  "/driver-applications/:driverId/approve",
  validate(adminSchema.driverParamSchema),
  adminController.approveDriver
);
router.post(
  "/driver-applications/:driverId/reject",
  validate(adminSchema.rejectDriverSchema),
  adminController.rejectDriver
);

router.post(
  "/drivers/:driverId/request-correction",
  validate(adminSchema.requestCorrectionSchema),
  adminController.postRequestCorrection
);

router.post(
  "/drivers/:driverId/suspend",
  validate(adminSchema.driverParamSchema),
  adminController.postSuspendDriver
);

router.post(
  "/drivers/:driverId/reinstate",
  validate(adminSchema.driverParamSchema),
  adminController.postReinstateDriver
);

router.get("/passengers", adminController.getAllPassengers);

router.post("/passengers/:passengerId/suspend", adminController.postSuspendPassenger);
router.post("/passengers/:passengerId/reinstate", adminController.postReinstatePassenger);

router.get("/rides/history", adminController.getRideHistory);
router.get("/approvals/pending", adminController.getPendingApprovals);

router.get("/fare", adminController.getFare);
router.put("/fare", validate(adminSchema.fareUpdateSchema), adminController.setFare);

router.get("/live-map", adminController.getLiveMap);
router.get("/dashboard", adminController.getDashboard);
router.get("/reports/ride-activity", adminController.getRideActivity);
router.get("/bookings", adminController.getBookings);
router.get("/bookings/:bookingId", adminController.getBookingDetail);
router.post("/bookings/:bookingId/close", validate(adminSchema.bookingCloseSchema), adminController.postCloseBooking);
router.get("/sos", adminController.getSosAlerts);
router.post("/sos/:id/resolve", adminController.resolveSosAlert);
router.get("/complaints", adminController.getComplaints);
router.post("/complaints/:id/resolve", adminController.resolveComplaint);
router.get("/notifications", adminController.getNotifications);
router.post("/notifications/:id/read", adminController.postMarkNotificationRead);
router.post("/notifications/mark_all_read", adminController.postMarkAllNotificationsRead);
// Announcements: broadcast to every passenger, every driver, or both.
router.get("/announcements", adminController.getAnnouncements);
router.post("/announcements", validate(adminSchema.announcementSchema), adminController.postAnnouncement);

router.get("/activity-logs", adminController.getActivityLogs);

router.get("/barangays", adminController.getBarangays);
router.put("/barangays/:barangayId", validate(adminSchema.barangayUpdateSchema), adminController.putBarangay);

router.get("/settings", adminController.getSystemSettings);
router.put("/settings", validate(adminSchema.systemSettingsSchema), adminController.putSystemSettings);

module.exports = router;
