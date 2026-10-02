const express = require("express");
const driverController = require("../controllers/driver.controller");
const accountSecurityController = require("../controllers/account-security.controller");
const authMiddleware = require("../middlewares/auth.middleware");
const requireDriverAccess = require("../middlewares/driverAccess.middleware");
const validate = require("../middlewares/validate.middleware");
const driverSchema = require("../validations/driver.schema");
const accountSecuritySchema = require("../validations/account-security.schema");
const upload = require("../middlewares/upload.middleware");

const router = express.Router();
const profileUpload = upload.createImageUpload("profile-images");

router.use(authMiddleware, requireDriverAccess);

router.patch("/status", validate(driverSchema.statusSchema), driverController.setOnlineStatus);
router.patch("/location", validate(driverSchema.locationSchema), driverController.updateLocation);
router.patch(
  "/profile",
  profileUpload.single("profileImage"),
  validate(driverSchema.profileUpdateSchema),
  driverController.updateProfile
);
router.post(
  "/bookings/:bookingId/respond",
  validate(driverSchema.bookingResponseSchema),
  driverController.respondBooking
);
router.post(
  "/bookings/:bookingId/arrive",
  validate(driverSchema.bookingParamSchema),
  driverController.arriveAtPickup
);
router.post(
  "/bookings/:bookingId/start",
  validate(driverSchema.startRideSchema),
  driverController.startRide
);
router.post(
  "/bookings/:bookingId/no-show",
  validate(driverSchema.noShowSchema),
  driverController.markNoShow
);
router.post(
  "/bookings/:bookingId/cancel",
  validate(driverSchema.driverCancelRideSchema),
  driverController.cancelRide
);
router.post(
  "/bookings/:bookingId/complete",
  validate(driverSchema.completeRideSchema),
  driverController.completeRide
);
router.get("/profile", driverController.getProfile);
router.get("/bookings/incoming", driverController.getIncomingBooking);
router.get("/bookings/active", driverController.getActiveBooking);
router.get("/bookings/history", driverController.getRideHistory);
router.get("/bookings/completed", driverController.getCompletedHistory);
router.get("/earnings", driverController.getEarnings);
router.get("/performance", driverController.getPerformance);
router.get("/ratings", driverController.getRatings);
router.get("/notifications", driverController.getNotifications);
router.post("/notifications/read", driverController.markNotificationsRead);
router.post("/sos", validate(driverSchema.sosSchema), driverController.triggerSos);
router.post("/report", validate(driverSchema.reportDriverSchema), driverController.reportIssue);
router.post(
  "/change-password/request-otp",
  validate(accountSecuritySchema.requestPasswordChangeSchema),
  accountSecurityController.requestPasswordChangeOtp
);
router.post(
  "/change-password/confirm",
  validate(accountSecuritySchema.confirmPasswordChangeSchema),
  accountSecurityController.confirmPasswordChange
);

module.exports = router;
