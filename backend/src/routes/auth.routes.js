const express = require("express");
const authController = require("../controllers/auth.controller");
const authMiddleware = require("../middlewares/auth.middleware");
const validate = require("../middlewares/validate.middleware");
const authSchema = require("../validations/auth.schema");
const { authLimiter, loginLimiter, otpPerEmailLimiter } = require("../middlewares/rate-limit.middleware");

const router = express.Router();

router.post(
  "/passenger/register",
  authLimiter,
  validate(authSchema.registerPassengerSchema),
  authController.registerPassenger
);

// Retired: created driver accounts without email verification. Riders now
// register as passengers and apply through the driver application site
// (POST /auth/v2/apply-driver), which requires an email OTP.
router.post("/driver/register", (_req, res) => {
  res.status(410).json({
    success: false,
    message:
      "Driver sign-up has moved. Create a passenger account, then apply as a driver from the app.",
  });
});

router.get("/admin/exists", authController.adminExists);
router.post(
  "/admin/send-otp",
  authLimiter,
  otpPerEmailLimiter,
  validate(authSchema.adminSendOtpSchema),
  authController.sendAdminOtp
);
router.post(
  "/admin/verify-otp",
  authLimiter,
  validate(authSchema.adminVerifyOtpSchema),
  authController.verifyAdminOtp
);
router.post(
  "/admin/register",
  authLimiter,
  validate(authSchema.registerAdminSchema),
  authController.registerAdmin
);
// Each admin resets their own password through their own email.
router.post(
  "/admin/forgot-password/request",
  authLimiter,
  otpPerEmailLimiter,
  validate(authSchema.adminForgotPasswordRequestSchema),
  authController.requestAdminPasswordReset
);
router.post(
  "/admin/forgot-password/verify-otp",
  authLimiter,
  validate(authSchema.adminForgotPasswordVerifySchema),
  authController.verifyAdminPasswordResetOtp
);
router.post(
  "/admin/forgot-password/reset",
  authLimiter,
  validate(authSchema.adminForgotPasswordResetSchema),
  authController.resetAdminPassword
);

router.post("/login", authLimiter, loginLimiter, validate(authSchema.loginSchema), authController.login);
router.post("/refresh", authLimiter, validate(authSchema.refreshSchema), authController.refresh);
router.post("/logout", authLimiter, validate(authSchema.logoutSchema), authController.logout);

router.get("/me", authMiddleware, authController.me);
router.post("/logout-all", authMiddleware, authController.logoutAll);

module.exports = router;
