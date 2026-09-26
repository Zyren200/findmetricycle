const express = require("express");
const passengerController = require("../controllers/passenger.controller");
const accountSecurityController = require("../controllers/account-security.controller");
const authMiddleware = require("../middlewares/auth.middleware");
const requireRole = require("../middlewares/role.middleware");
const roles = require("../constants/roles");
const validate = require("../middlewares/validate.middleware");
const passengerSchema = require("../validations/passenger.schema");
const accountSecuritySchema = require("../validations/account-security.schema");
const upload = require("../middlewares/upload.middleware");

const router = express.Router();
const profileUpload = upload.createImageUpload("profile-images");

router.use(authMiddleware, requireRole(roles.PASSENGER));

router.post("/bookings/find-ride", validate(passengerSchema.findRideSchema), passengerController.findRide);
router.get("/bookings/history", passengerController.getBookingHistory);
router.get("/fare", passengerController.getFare);
router.get("/notifications", passengerController.getNotifications);
router.post("/sos", validate(passengerSchema.sosSchema), passengerController.triggerSos);
router.patch(
  "/profile",
  profileUpload.single("profileImage"),
  validate(passengerSchema.updateProfileSchema),
  passengerController.updateProfile
);
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
router.delete(
  "/account",
  validate(passengerSchema.deleteAccountSchema),
  passengerController.deleteAccount
);
router.get(
  "/bookings/:bookingId",
  validate(passengerSchema.bookingIdParamSchema),
  passengerController.getBooking
);
router.post(
  "/bookings/:bookingId/cancel",
  validate(passengerSchema.bookingIdParamSchema),
  passengerController.cancelRide
);
router.post(
  "/bookings/:bookingId/rate",
  validate(passengerSchema.ratingSchema),
  passengerController.rateRide
);
router.post(
  "/bookings/:bookingId/choose-driver",
  validate(passengerSchema.chooseDriverSchema),
  passengerController.chooseDriver
);
router.get(
  "/bookings/:bookingId/nearby-drivers",
  validate(passengerSchema.bookingIdParamSchema),
  passengerController.getNearbyDrivers
);

module.exports = router;
