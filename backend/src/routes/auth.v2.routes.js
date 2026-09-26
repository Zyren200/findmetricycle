const express = require("express");
const rateLimit = require("express-rate-limit");
const validate = require("../middlewares/validate.middleware");
const { z } = require("zod");
const authV2Service = require("../services/auth.v2.service");
const authService = require("../services/auth.service");
const authMiddleware = require("../middlewares/auth.middleware");
const upload = require("../middlewares/upload.middleware");
const { requireCaptcha, signCaptchaSessionToken } = require("../middlewares/captcha.middleware");
const captchaService = require("../services/captcha.service");
const ApiError = require("../utils/api-error");

const router = express.Router();

// Sending an email costs a Brevo credit and can be aimed at someone else's
// inbox, so OTP dispatch is capped much tighter than normal auth traffic —
// per IP, and independently per email address to stop one IP from farming
// codes across many accounts or one target's inbox being flooded from many IPs.
const otpEmailTargets = new Map(); // email -> array of send timestamps
const OTP_EMAIL_WINDOW_MS = 15 * 60 * 1000;
const OTP_EMAIL_MAX = 3;

function otpPerEmailLimiter(req, res, next) {
  const email = String(req.body?.email || "").toLowerCase().trim();
  if (!email) return next();

  const now = Date.now();
  const hits = (otpEmailTargets.get(email) || []).filter((t) => now - t < OTP_EMAIL_WINDOW_MS);

  if (hits.length >= OTP_EMAIL_MAX) {
    return res.status(429).json({
      success: false,
      message: "Too many codes requested for this email. Please wait a few minutes and try again.",
    });
  }

  hits.push(now);
  otpEmailTargets.set(email, hits);
  next();
}

const otpIpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: "Too many requests. Please try again later." },
});

// Schema definitions
const sendOTPSchema = z.object({
  body: z.object({
    email: z.string().email(),
    purpose: z.enum(["driver_application"]).optional(),
  }),
});

const verifyOTPSchema = z.object({
  body: z.object({
    email: z.string().email(),
    code: z.string().length(6, "Code must be 6 digits"),
    purpose: z.enum(["driver_application"]).optional(),
  }),
});

const forgotPasswordRequestSchema = z.object({
  body: z.object({
    email: z.string().email(),
  }),
});

const forgotPasswordResetSchema = z.object({
  body: z.object({
    email: z.string().email(),
    code: z.string().length(6, "Code must be 6 digits"),
    newPassword: z.string().min(8, "Password must be at least 8 characters"),
  }),
});

const registerPassengerSchema = z.object({
  body: z.object({
    email: z.string().email(),
    firstName: z.string().min(1),
    middleName: z.string().optional().nullable(),
    lastName: z.string().min(1),
    phone: z.string().regex(/^\+?[0-9]{10,15}$/, "Invalid phone number"),
    password: z.string().min(8, "Password must be at least 8 characters"),
  }),
});

const applyAsDriverSchema = z.object({
  body: z.object({
    plateNumber: z.string().min(1),
    franchiseNumber: z.string().trim().max(60).optional(),
    licenseType: z.string().trim().max(40).optional(),
    address: z.string().trim().max(255).optional(),
    emergencyContactName: z.string().trim().max(120).optional(),
    emergencyContactPhone: z.string().trim().max(20).optional(),
    licenseOcrText: z.string().optional(),
    livenessStatus: z.enum(["passed", "needs_review", "failed"]).optional(),
    // Confirmed by the applicant on the license-review step — what they
    // typed after checking the OCR read against the physical card.
    confirmedFullName: z.string().trim().min(1).max(120).optional(),
    confirmedLicenseNumber: z.string().trim().min(1).max(80).optional(),
    confirmedBirthDate: z.string().trim().min(4).max(40).optional(),
    confirmedExpiryDate: z.string().trim().min(4).max(40).optional(),
  }),
});

const driverDocumentUpload = upload.fields([
  { name: "licenseImage", maxCount: 1 },
  { name: "businessPermitImage", maxCount: 1 },
  { name: "selfieImage", maxCount: 1 },
]);

// Public endpoints

/**
 * POST /auth/v2/send-otp
 * Send OTP to email
 */
router.post(
  "/send-otp",
  otpIpLimiter,
  otpPerEmailLimiter,
  validate(sendOTPSchema),
  (req, res, next) => (req.body.purpose === "driver_application" ? requireCaptcha(req, res, next) : next()),
  async (req, res, next) => {
    try {
      const { email, purpose } = req.body;
      const result = await authV2Service.sendOTP(email, purpose || null);
      res.json(result);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * POST /auth/v2/verify-otp
 * Verify OTP code
 */
router.post("/verify-otp", otpIpLimiter, validate(verifyOTPSchema), async (req, res, next) => {
  try {
    const { email, code, purpose } = req.body;
    const result = await authV2Service.verifyOTP(email, code, purpose || null);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

/**
 * POST /auth/v2/verify-captcha
 * Verify a reCAPTCHA v2 response token and issue a short-lived session
 * token the website presents to unlock driver_application OTP dispatch.
 */
router.post(
  "/verify-captcha",
  otpIpLimiter,
  validate(
    z.object({
      body: z.object({ token: z.string().min(1) }),
    })
  ),
  async (req, res, next) => {
    try {
      const ok = await captchaService.verifyRecaptcha(req.body.token, req.ip);
      if (!ok) {
        throw new ApiError(400, "CAPTCHA verification failed. Please try again.");
      }
      res.json({ success: true, captchaSessionToken: signCaptchaSessionToken() });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * POST /auth/v2/forgot-password/request
 * Send a password reset code to an account's email
 */
router.post("/forgot-password/request", otpIpLimiter, otpPerEmailLimiter, validate(forgotPasswordRequestSchema), async (req, res, next) => {
  try {
    const { email } = req.body;
    const result = await authV2Service.requestPasswordReset(email);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

/**
 * POST /auth/v2/forgot-password/reset
 * Verify the reset code and set a new password
 */
router.post("/forgot-password/reset", otpIpLimiter, validate(forgotPasswordResetSchema), async (req, res, next) => {
  try {
    const { email, code, newPassword } = req.body;
    const result = await authV2Service.resetPasswordWithOTP(email, code, newPassword);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

/**
 * POST /auth/v2/register
 * Register as passenger after OTP verification
 */
router.post("/register", validate(registerPassengerSchema), async (req, res, next) => {
  try {
    const { email, firstName, middleName, lastName, phone, password } = req.body;
    const fullName = `${firstName} ${lastName}`.trim();

    const result = await authV2Service.registerPassenger(
      fullName,
      email,
      phone,
      password,
      middleName
    );

    // Auto-login after registration
    const loginResult = await authService.login({ email, password });

    res.json({
      success: true,
      message: "Registration successful",
      data: {
        userId: result.userId,
        ...loginResult,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /auth/v2/login
 * Login with email or phone
 */
router.post("/login", async (req, res, next) => {
  try {
    const { email, phone, password } = req.body;

    if (!email && !phone) {
      return res.status(400).json({
        success: false,
        message: "Email or phone is required",
      });
    }

    const result = await authService.login({ email, phone, password });

    res.json({
      success: true,
      message: "Login successful",
      data: result,
    });
  } catch (error) {
    next(error);
  }
});

// Protected endpoints (require authentication)

/**
 * POST /auth/v2/apply-driver
 * Apply as driver
 */
router.post(
  "/apply-driver",
  authMiddleware,
  driverDocumentUpload,
  validate(applyAsDriverSchema),
  async (req, res, next) => {
    try {
      const {
        plateNumber,
        franchiseNumber,
        licenseType,
        address,
        emergencyContactName,
        emergencyContactPhone,
        licenseOcrText,
        livenessStatus,
        confirmedFullName,
        confirmedLicenseNumber,
        confirmedBirthDate,
        confirmedExpiryDate,
      } = req.body;
      const files = req.files || {};
      const license = files.licenseImage?.[0];
      const permit = files.businessPermitImage?.[0];
      const selfie = files.selfieImage?.[0];

      if (!license || !permit) {
        throw new ApiError(400, "Driver's license and business permit photos are both required.");
      }

      const result = await authV2Service.applyAsDriver(
        req.user.id,
        plateNumber,
        `/uploads/driver-docs/${license.filename}`,
        `/uploads/driver-docs/${permit.filename}`,
        licenseOcrText,
        selfie ? `/uploads/driver-docs/${selfie.filename}` : null,
        livenessStatus,
        {
          fullName: confirmedFullName || null,
          licenseNumber: confirmedLicenseNumber || null,
          birthDate: confirmedBirthDate || null,
          expiresAt: confirmedExpiryDate || null,
        },
        {
          franchiseNumber: franchiseNumber || null,
          licenseType: licenseType || null,
          address: address || null,
          emergencyContactName: emergencyContactName || null,
          emergencyContactPhone: emergencyContactPhone || null,
        }
      );

      res.json(result);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * GET /auth/v2/driver-status
 * Get driver application status
 */
router.get("/driver-status", authMiddleware, async (req, res, next) => {
  try {
    const status = await authV2Service.getDriverApplicationStatus(req.user.id);

    if (!status) {
      return res.json({
        success: true,
        data: null,
        message: "No active application",
      });
    }

    res.json({
      success: true,
      data: status,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /auth/v2/driver-application/timeline
 * Status-change history for the caller's own current application.
 */
router.get("/driver-application/timeline", authMiddleware, async (req, res, next) => {
  try {
    const data = await authV2Service.getDriverApplicationTimeline(req.user.id);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /auth/v2/resubmit-driver-application
 * Resubmit driver application
 */
router.post(
  "/resubmit-driver-application",
  authMiddleware,
  driverDocumentUpload,
  async (req, res, next) => {
    try {
      const {
        licenseOcrText,
        livenessStatus,
        confirmedFullName,
        confirmedLicenseNumber,
        confirmedBirthDate,
        confirmedExpiryDate,
      } = req.body;
      const files = req.files || {};
      const license = files.licenseImage?.[0];
      const permit = files.businessPermitImage?.[0];
      const selfie = files.selfieImage?.[0];

      if (!license || !permit) {
        throw new ApiError(400, "Driver's license and business permit photos are both required.");
      }

      const result = await authV2Service.resubmitDriverApplication(
        req.user.id,
        `/uploads/driver-docs/${license.filename}`,
        `/uploads/driver-docs/${permit.filename}`,
        licenseOcrText,
        selfie ? `/uploads/driver-docs/${selfie.filename}` : null,
        livenessStatus,
        {
          fullName: confirmedFullName || null,
          licenseNumber: confirmedLicenseNumber || null,
          birthDate: confirmedBirthDate || null,
          expiresAt: confirmedExpiryDate || null,
        }
      );

      res.json(result);
    } catch (error) {
      next(error);
    }
  }
);

module.exports = router;
