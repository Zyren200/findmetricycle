const fs = require("fs");
const express = require("express");
const rateLimit = require("express-rate-limit");
const validate = require("../middlewares/validate.middleware");
const { z } = require("zod");
const authV2Service = require("../services/auth.v2.service");
const documentCheckService = require("../services/document-check.service");
const authService = require("../services/auth.service");
const authMiddleware = require("../middlewares/auth.middleware");
const upload = require("../middlewares/upload.middleware");
const { requireCaptcha, signCaptchaSessionToken } = require("../middlewares/captcha.middleware");
const captchaService = require("../services/captcha.service");
const ApiError = require("../utils/api-error");
const {
  authLimiter,
  loginLimiter,
  otpPerEmailLimiter,
  otpPerUserLimiter,
} = require("../middlewares/rate-limit.middleware");

const router = express.Router();

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

const loginSchema = z.object({
  body: z.object({
    email: z.string().trim().email().max(120).optional().or(z.literal("")),
    phone: z.string().trim().max(20).optional().or(z.literal("")),
    password: z.string().min(1).max(100),
  }),
});

// Shared by apply + resubmit. The liveness result is reported by the
// applicant's browser, so it's stored only as a screening hint for the
// admin reviewer, never as proof on its own.
const licenseConfirmationFields = {
  licenseOcrText: z.string().max(5000).optional(),
  livenessStatus: z.enum(["passed", "needs_review", "failed"]).optional(),
  // Confirmed by the applicant on the license-review step — what they
  // typed after checking the OCR read against the physical card.
  confirmedFullName: z.string().trim().min(1).max(120).optional(),
  confirmedLicenseNumber: z.string().trim().min(1).max(80).optional(),
  confirmedBirthDate: z.string().trim().min(4).max(40).optional(),
  confirmedExpiryDate: z.string().trim().min(4).max(40).optional(),
};

const resubmitDriverApplicationSchema = z.object({
  body: z.object(licenseConfirmationFields),
});

const applyAsDriverSchema = z.object({
  body: z.object({
    plateNumber: z.string().min(1),
    franchiseNumber: z.string().trim().max(60).optional(),
    licenseType: z.string().trim().max(40).optional(),
    address: z.string().trim().max(255).optional(),
    emergencyContactName: z.string().trim().max(120).optional(),
    emergencyContactPhone: z.string().trim().max(20).optional(),
    ...licenseConfirmationFields,
  }),
});

const driverDocumentUpload = upload.fields([
  { name: "licenseImage", maxCount: 1 },
  { name: "businessPermitImage", maxCount: 1 },
  { name: "selfieImage", maxCount: 1 },
]);

// Multer writes the files before validation runs — if the request is then
// rejected, delete them so failed submissions don't pile up sensitive
// ID photos on disk.
function removeUploadedFilesOnError(error, req, _res, next) {
  for (const list of Object.values(req.files || {})) {
    for (const file of list) {
      fs.unlink(file.path, () => {});
    }
  }
  next(error);
}

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
router.post("/register", authLimiter, validate(registerPassengerSchema), async (req, res, next) => {
  try {
    const { email, firstName, middleName, lastName, phone, password } = req.body;
    // There's no separate middle-name column, so it's kept in full_name
    // instead of being silently dropped.
    const fullName = [firstName, middleName, lastName]
      .map((part) => String(part || "").trim())
      .filter(Boolean)
      .join(" ");

    const result = await authV2Service.registerPassenger(fullName, email, phone, password);

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
router.post("/login", authLimiter, loginLimiter, validate(loginSchema), async (req, res, next) => {
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

// Rejects an application before multer writes any ID photos to disk when
// the applicant hasn't recently confirmed their email.
async function requireDriverApplicationOtp(req, _res, next) {
  try {
    await authV2Service.assertDriverApplicationOtp(req.user.email);
    next();
  } catch (error) {
    next(error);
  }
}

/**
 * POST /auth/v2/driver-application/otp/send
 * Emails the signed-in user a code to confirm a driver application.
 */
router.post(
  "/driver-application/otp/send",
  authMiddleware,
  otpIpLimiter,
  otpPerUserLimiter,
  async (req, res, next) => {
    try {
      if (!req.user.email) {
        throw new ApiError(400, "Add an email address to your account before applying as a driver.");
      }
      await authV2Service.sendOTP(req.user.email, authV2Service.DRIVER_APPLICATION_PURPOSE);
      res.json({ success: true, message: "Verification code sent.", email: req.user.email });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * POST /auth/v2/driver-application/otp/verify
 * Confirms the code; the next application submitted within an hour passes.
 */
router.post(
  "/driver-application/otp/verify",
  authMiddleware,
  otpIpLimiter,
  validate(z.object({ body: z.object({ code: z.string().regex(/^\d{6}$/, "Code must be 6 digits") }) })),
  async (req, res, next) => {
    try {
      const result = await authV2Service.verifyOTP(
        req.user.email,
        req.body.code,
        authV2Service.DRIVER_APPLICATION_PURPOSE
      );
      res.json(result);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * POST /auth/v2/apply-driver
 * Apply as driver
 */
router.post(
  "/apply-driver",
  authMiddleware,
  requireDriverApplicationOtp,
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
        selfie ? livenessStatus : null,
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

      documentCheckService.scheduleCheck(result.applicationId);
      res.json(result);
    } catch (error) {
      next(error);
    }
  },
  removeUploadedFilesOnError
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
  requireDriverApplicationOtp,
  driverDocumentUpload,
  validate(resubmitDriverApplicationSchema),
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
        selfie ? livenessStatus : null,
        {
          fullName: confirmedFullName || null,
          licenseNumber: confirmedLicenseNumber || null,
          birthDate: confirmedBirthDate || null,
          expiresAt: confirmedExpiryDate || null,
        }
      );

      documentCheckService.scheduleCheck(result.applicationId);
      res.json(result);
    } catch (error) {
      next(error);
    }
  },
  removeUploadedFilesOnError
);

module.exports = router;
