const express = require("express");
const authController = require("../controllers/auth.controller");
const authMiddleware = require("../middlewares/auth.middleware");
const upload = require("../middlewares/upload.middleware");
const validate = require("../middlewares/validate.middleware");
const authSchema = require("../validations/auth.schema");
const { authLimiter, loginLimiter } = require("../middlewares/rate-limit.middleware");

const router = express.Router();

router.post(
  "/passenger/register",
  authLimiter,
  validate(authSchema.registerPassengerSchema),
  authController.registerPassenger
);

router.post(
  "/driver/register",
  authLimiter,
  upload.fields([
    { name: "licenseImage", maxCount: 1 },
    { name: "businessPermitImage", maxCount: 1 },
  ]),
  validate(authSchema.registerDriverSchema),
  authController.registerDriver
);

router.get("/admin/exists", authController.adminExists);
router.post(
  "/admin/send-otp",
  authLimiter,
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
router.post(
  "/admin/forgot-password/request",
  authLimiter,
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
