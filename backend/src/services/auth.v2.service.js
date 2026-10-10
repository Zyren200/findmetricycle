const crypto = require("crypto");
const dns = require("dns").promises;
const bcrypt = require("bcryptjs");
const db = require("../config/db");
const nodemailer = require("nodemailer");
const licenseValidationService = require("./license-validation.service");
const notificationService = require("./notification.service");
const statusHistoryModel = require("../models/application-status-history.model");
const refreshTokenModel = require("../models/refresh-token.model");
const ApiError = require("../utils/api-error");
const escapeHtml = require("../utils/escape-html");
const { checkLicenseIdentity } = require("../utils/license-identity");

const PASSWORD_RESET_PURPOSE = "password_reset";
// How long a verified registration code stays usable for the follow-up
// register call.
const VERIFIED_OTP_WINDOW_MS = 30 * 60 * 1000;

// Generate a 6-digit OTP from a CSPRNG (Math.random is predictable).
function generateOTP() {
  return crypto.randomInt(100000, 1000000).toString();
}

function buildTransporter() {
  return nodemailer.createTransport({
    host: process.env.BREVO_SMTP_HOST,
    port: parseInt(process.env.BREVO_SMTP_PORT) || 587,
    secure: false,
    auth: {
      user: process.env.BREVO_SENDER_EMAIL,
      pass: process.env.BREVO_SMTP_PASSWORD,
    },
  });
}

// Send OTP via email (using Brevo SMTP)
async function sendOTPEmail(email, otp) {
  try {
    const transporter = buildTransporter();

    const mailOptions = {
      from: `"FindMeTricycle" <${process.env.BREVO_FROM_EMAIL || process.env.BREVO_SENDER_EMAIL || "noreply@findmetricycle.local"}>`,
      to: email,
      subject: "FindMeTricycle - OTP Verification",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #0E8C46;">FindMeTricycle</h2>
          <p>Your OTP verification code:</p>
          <div style="background: #f0f0f0; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0;">
            <h1 style="letter-spacing: 10px; color: #0E8C46; margin: 0;">${otp}</h1>
          </div>
          <p><strong>Valid for 5 minutes</strong></p>
          <p>If you didn't request this code, please ignore this email.</p>
          <hr style="border: none; border-top: 1px solid #ccc; margin: 20px 0;">
          <p style="color: #666; font-size: 12px;">© FindMeTricycle 2024</p>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);
    if (process.env.NODE_ENV === "production") {
      console.log(`✓ OTP sent to ${email}`);
    } else {
      console.log(`✓ OTP sent to ${email}: ${otp}`);
    }
    return true;
  } catch (error) {
    console.error(`✗ Failed to send OTP to ${email}:`, error.message);
    return false;
  }
}

// Send password-reset OTP via email — a separate template from the
// registration OTP so it's unambiguous which flow the code is for.
async function sendPasswordResetEmail(email, otp) {
  try {
    const transporter = buildTransporter();

    const mailOptions = {
      from: `"FindMeTricycle" <${process.env.BREVO_FROM_EMAIL || process.env.BREVO_SENDER_EMAIL || "noreply@findmetricycle.local"}>`,
      to: email,
      subject: "FindMeTricycle - Password Reset Code",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #0E8C46;">FindMeTricycle</h2>
          <p>You requested to reset your password. Use the code below:</p>
          <div style="background: #f0f0f0; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0;">
            <h1 style="letter-spacing: 10px; color: #0E8C46; margin: 0;">${otp}</h1>
          </div>
          <p><strong>Valid for 5 minutes</strong></p>
          <p>If you didn't request this, you can safely ignore this email — your password will not change.</p>
          <hr style="border: none; border-top: 1px solid #ccc; margin: 20px 0;">
          <p style="color: #666; font-size: 12px;">© FindMeTricycle 2024</p>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`✓ Password reset code sent to ${email}`);
    return true;
  } catch (error) {
    console.error(`✗ Failed to send password reset code to ${email}:`, error.message);
    return false;
  }
}

async function sendDriverApprovalEmail(email, fullName) {
  try {
    const transporter = buildTransporter();

    const mailOptions = {
      from: `"FindMeTricycle" <${process.env.BREVO_FROM_EMAIL || process.env.BREVO_SENDER_EMAIL || "noreply@findmetricycle.local"}>`,
      to: email,
      subject: "🎉 Driver Application Approved!",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #0E8C46;">🎉 Congratulations, ${escapeHtml(fullName)}!</h2>
          <p>Your driver application has been <strong>approved</strong>!</p>
          <p>You can now:</p>
          <ul style="line-height: 1.8;">
            <li>✓ Switch to Driver mode in the app</li>
            <li>✓ Start accepting rides and earning money</li>
            <li>✓ View your earnings and ratings</li>
          </ul>
          <hr style="border: none; border-top: 1px solid #ccc; margin: 20px 0;">
          <p style="color: #666; font-size: 12px;">© FindMeTricycle 2024</p>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`✓ Driver approval email sent to ${email}`);
    return true;
  } catch (error) {
    console.error(`✗ Failed to send approval email to ${email}:`, error.message);
    return false;
  }
}

async function sendDriverRejectionEmail(email, fullName, reason) {
  try {
    const transporter = buildTransporter();

    const mailOptions = {
      from: `"FindMeTricycle" <${process.env.BREVO_FROM_EMAIL || process.env.BREVO_SENDER_EMAIL || "noreply@findmetricycle.local"}>`,
      to: email,
      subject: "Driver Application Status Update",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #D32F2F;">Application Update</h2>
          <p>Hi ${escapeHtml(fullName)},</p>
          <p>Thank you for applying as a driver. Unfortunately, your application could not be approved at this time.</p>
          <p><strong>Reason:</strong></p>
          <div style="background: #fff3cd; padding: 15px; border-radius: 6px; border-left: 4px solid #FFC107;">
            ${escapeHtml(reason || "Please contact support for more details.")}
          </div>
          <p style="margin-top: 20px;">You can resubmit your application with updated documents.</p>
          <p style="color: #666; font-size: 12px;">If you have questions, please contact our support team.</p>
          <hr style="border: none; border-top: 1px solid #ccc; margin: 20px 0;">
          <p style="color: #666; font-size: 12px;">© FindMeTricycle 2024</p>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`✓ Driver rejection email sent to ${email}`);
    return true;
  } catch (error) {
    console.error(`✗ Failed to send rejection email to ${email}:`, error.message);
    return false;
  }
}

const MAX_OTP_ATTEMPTS = 5;

function safeCodeEquals(expected, actual) {
  const a = Buffer.from(String(expected || ""));
  const b = Buffer.from(String(actual || ""));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

// Whether `email`'s most recent code for `purpose` (null = registration)
// was verified within `windowMs`.
async function hasVerifiedOtp(email, purpose = null, windowMs = VERIFIED_OTP_WINDOW_MS, client = db) {
  if (!email) return false;
  const rows = await client.query(
    "SELECT is_verified, verified_at FROM otp_codes WHERE email = ? AND purpose <=> ? ORDER BY id DESC LIMIT 1",
    [email, purpose]
  );
  const latest = rows[0];
  return Boolean(
    latest &&
      Number(latest.is_verified) === 1 &&
      new Date(latest.verified_at).getTime() > Date.now() - windowMs
  );
}

// Deletes every code for `email` + `purpose`, so a verification can only
// ever be used once.
async function consumeOtp(email, purpose = null, client = db) {
  await client.query("DELETE FROM otp_codes WHERE email = ? AND purpose <=> ?", [email, purpose]);
}

// Throws unless `email` has a registration OTP (purpose NULL) that was
// verified within VERIFIED_OTP_WINDOW_MS, then consumes it so the same
// verification can't be reused for a second account or another flow.
async function consumeVerifiedEmailOtp(email, client = db) {
  if (!(await hasVerifiedOtp(email, null, VERIFIED_OTP_WINDOW_MS, client))) {
    throw new ApiError(400, "Please verify your email with the code sent to it first.");
  }
  await consumeOtp(email, null, client);
}

// Driver applications (new or resubmitted) require the applicant to have
// confirmed their email within the last hour — enforced on the server, so
// it can't be skipped by calling the API directly.
const DRIVER_APPLICATION_PURPOSE = "driver_application";
const DRIVER_APPLICATION_OTP_WINDOW_MS = 60 * 60 * 1000;

async function assertDriverApplicationOtp(email) {
  if (!email) {
    throw new ApiError(400, "Add an email address to your account before applying as a driver.");
  }
  if (!(await hasVerifiedOtp(email, DRIVER_APPLICATION_PURPOSE, DRIVER_APPLICATION_OTP_WINDOW_MS))) {
    throw new ApiError(403, "Please verify your email with the code we send you before submitting.", {
      code: "OTP_REQUIRED",
    });
  }
}

// Send OTP. `purpose` scopes the code to a specific flow (e.g.
// "driver_application") so a code issued for one flow can't be replayed
// to verify a different one. Purpose is optional for backward
// compatibility with the existing registration/login OTP callers.
async function sendOTP(email, purpose = null) {
  const otp = generateOTP();
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

  const existing = await db.query(
    "SELECT id FROM otp_codes WHERE email = ? AND purpose <=> ? AND is_verified = 0 AND expires_at > NOW()",
    [email, purpose]
  );

  if (existing.length > 0) {
    await db.query(
      "UPDATE otp_codes SET code = ?, attempts = 0, expires_at = ? WHERE id = ?",
      [otp, expiresAt, existing[0].id]
    );
  } else {
    await db.query(
      "INSERT INTO otp_codes (email, purpose, code, attempts, expires_at) VALUES (?, ?, ?, 0, ?)",
      [email, purpose, otp, expiresAt]
    );
  }

  await sendOTPEmail(email, otp);
  return { success: true, message: "OTP sent to email" };
}

// Verify OTP, scoped to the same purpose it was requested under. Locks
// out further attempts on a code once MAX_OTP_ATTEMPTS is reached —
// the caller must request a fresh code instead of continuing to guess.
async function verifyOTP(email, code, purpose = null) {
  const [pending] = await db.query(
    "SELECT * FROM otp_codes WHERE email = ? AND purpose <=> ? AND is_verified = 0 AND expires_at > NOW() ORDER BY id DESC LIMIT 1",
    [email, purpose]
  );

  if (!pending) {
    throw new ApiError(400, "Invalid or expired OTP");
  }

  if (pending.attempts >= MAX_OTP_ATTEMPTS) {
    throw new ApiError(429, "Too many attempts. Please request a new code.");
  }

  if (!safeCodeEquals(pending.code, code)) {
    await db.query("UPDATE otp_codes SET attempts = attempts + 1 WHERE id = ?", [pending.id]);
    throw new ApiError(400, "Invalid or expired OTP");
  }

  await db.query("UPDATE otp_codes SET is_verified = 1, verified_at = NOW() WHERE id = ?", [pending.id]);

  return { success: true, message: "OTP verified" };
}

// Request a password reset code
async function requestPasswordReset(email) {
  const users = await db.query("SELECT id FROM users WHERE email = ? AND deleted_at IS NULL", [email]);
  if (users.length === 0) {
    // Login already says when an email isn't registered, so hiding it here
    // protects nothing — it would only leave the user waiting for a code
    // that never arrives.
    throw new ApiError(404, "This email is not registered.", { field: "email" });
  }

  const otp = generateOTP();
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

  // Reset codes carry their own purpose so a registration or
  // driver-application code can never reset a password. Older reset codes
  // (verified ones too) are dropped so only the newest one counts.
  await db.query("DELETE FROM otp_codes WHERE email = ? AND purpose = ?", [
    email,
    PASSWORD_RESET_PURPOSE,
  ]);
  await db.query(
    "INSERT INTO otp_codes (email, purpose, code, attempts, expires_at) VALUES (?, ?, ?, 0, ?)",
    [email, PASSWORD_RESET_PURPOSE, otp, expiresAt]
  );

  await sendPasswordResetEmail(email, otp);
  return { success: true, message: "A reset code has been sent to your email." };
}

// Step 2 of the app's forgot-password flow: checks the emailed code before
// the new-password screen opens. Nothing changes yet — the verified code
// stays usable for RESET_VERIFIED_WINDOW_MINUTES and has to be sent again
// with the new password.
async function verifyPasswordResetCode(email, code) {
  try {
    await verifyOTP(email, code, PASSWORD_RESET_PURPOSE);
  } catch (error) {
    throw new ApiError(error.statusCode || 400, error.statusCode === 429 ? error.message : "Invalid or expired code");
  }
  return { success: true, message: "Code verified." };
}

// How long a reset code checked by verifyPasswordResetCode can still be
// used to set the new password.
const RESET_VERIFIED_WINDOW_MINUTES = 15;

// Verify the reset code and update the password. The code is either still
// pending (one-step reset) or was verified in the previous step; wrong
// guesses count against MAX_OTP_ATTEMPTS either way, and every existing
// session is signed out once the password changes.
async function resetPasswordWithOTP(email, code, newPassword) {
  const [pending] = await db.query(
    `SELECT * FROM otp_codes
      WHERE email = ? AND purpose = ?
        AND ((is_verified = 0 AND expires_at > NOW())
          OR (is_verified = 1 AND verified_at > NOW() - INTERVAL ${RESET_VERIFIED_WINDOW_MINUTES} MINUTE))
      ORDER BY id DESC LIMIT 1`,
    [email, PASSWORD_RESET_PURPOSE]
  );

  if (!pending) {
    throw new ApiError(400, "Invalid or expired code");
  }

  if (pending.attempts >= MAX_OTP_ATTEMPTS) {
    throw new ApiError(429, "Too many attempts. Please request a new code.");
  }

  if (!safeCodeEquals(pending.code, code)) {
    await db.query("UPDATE otp_codes SET attempts = attempts + 1 WHERE id = ?", [pending.id]);
    throw new ApiError(400, "Invalid or expired code");
  }

  const [user] = await db.query("SELECT id FROM users WHERE email = ?", [email]);
  if (!user) {
    throw new ApiError(404, "Account not found");
  }

  const passwordHash = await bcrypt.hash(newPassword, 12);

  await db.withTransaction(async (client) => {
    await client.query("UPDATE users SET password_hash = ? WHERE id = ?", [passwordHash, user.id]);
    await client.query("DELETE FROM otp_codes WHERE email = ? AND purpose = ?", [email, PASSWORD_RESET_PURPOSE]);
    await refreshTokenModel.revokeAllByUserId(user.id, client);
  });

  return { success: true, message: "Password updated successfully." };
}

// DNS codes meaning "this domain has no mail server / doesn't exist".
const NO_MAIL_DOMAIN_CODES = new Set(["ENOTFOUND", "ENODATA", "ENOENT", "NXDOMAIN"]);

const COMMON_DOMAIN_TYPOS = {
  "gmial.com": "gmail.com",
  "gmai.com": "gmail.com",
  "gmal.com": "gmail.com",
  "gmaill.com": "gmail.com",
  "gamil.com": "gmail.com",
  "gnail.com": "gmail.com",
  "gmail.co": "gmail.com",
  "gmail.con": "gmail.com",
  "gmail.cm": "gmail.com",
  "yaho.com": "yahoo.com",
  "yahooo.com": "yahoo.com",
  "yahoo.con": "yahoo.com",
  "hotmial.com": "hotmail.com",
  "hotmail.con": "hotmail.com",
  "outlok.com": "outlook.com",
  "outlook.con": "outlook.com",
  "iclod.com": "icloud.com",
};

// Some machines hand Node a DNS server that doesn't answer (e.g.
// 127.0.0.1 on Windows); then public resolvers are asked instead.
const publicResolver = new dns.Resolver({ timeout: 3000, tries: 1 });
publicResolver.setServers(["1.1.1.1", "8.8.8.8"]);

async function resolveWithFallback(method, domain) {
  try {
    return await dns[method](domain);
  } catch (error) {
    if (NO_MAIL_DOMAIN_CODES.has(error.code)) throw error;
    return publicResolver[method](domain);
  }
}

// Refuses an email whose domain can't receive mail (made-up or misspelled
// domains like "gmial.com"), so no code is sent to nowhere. The mailbox
// itself can't be checked without sending — the OTP proves that. A DNS
// outage lets the email through rather than blocking sign-ups.
async function assertEmailDomainReceivesMail(email) {
  const domain = String(email || "").split("@")[1]?.trim().toLowerCase();
  const invalid = new ApiError(400, "This email address doesn't exist. Check it and try again.", { field: "email" });
  if (!domain) throw invalid;
  // Misspellings of big providers are real domains that do take mail —
  // just never the user's.
  const meant = COMMON_DOMAIN_TYPOS[domain];
  if (meant) {
    throw new ApiError(400, `Check the email address — did you mean @${meant}?`, { field: "email" });
  }
  try {
    const mx = await resolveWithFallback("resolveMx", domain);
    if (mx.some((r) => r.exchange && r.exchange !== ".")) return;
    throw invalid;
  } catch (error) {
    if (error === invalid) throw error;
    if (!NO_MAIL_DOMAIN_CODES.has(error.code)) return;
  }
  // No MX record: mail falls back to the domain's own address, if any.
  try {
    await resolveWithFallback("resolve4", domain);
  } catch (error) {
    if (NO_MAIL_DOMAIN_CODES.has(error.code)) throw invalid;
  }
}

// Sign-up's first step: refuses an email another account already uses
// (shown under the email field via details.field).
async function assertEmailAvailable(email) {
  const existing = await db.query("SELECT id FROM users WHERE email = ? AND deleted_at IS NULL", [email]);
  if (existing.length > 0) {
    throw new ApiError(409, "This email is already registered. Log in instead.", { field: "email" });
  }
}

// Register Passenger — only after the email's registration OTP was verified.
async function registerPassenger(fullName, email, phone, password) {
  const passwordHash = await bcrypt.hash(password, 12);

  return db.withTransaction(async (client) => {
    const existing = await client.query("SELECT id FROM users WHERE email = ?", [email]);
    if (existing.length > 0) {
      throw new ApiError(409, "Email already registered");
    }

    const existingPhone = await client.query("SELECT id FROM users WHERE phone = ?", [phone]);
    if (existingPhone.length > 0) {
      throw new ApiError(409, "Phone number already registered");
    }

    await consumeVerifiedEmailOtp(email, client);

    const result = await client.query(
      `INSERT INTO users
        (full_name, email, phone, password_hash, role, status, driver_approval_status, is_driver_account)
       VALUES (?, ?, ?, ?, 'passenger', 'active', 'none', 0)`,
      [fullName, email, phone, passwordHash]
    );

    return {
      success: true,
      message: "Passenger account created. You can now login.",
      userId: result.insertId,
    };
  });
}

// Runs on-device-OCR-extracted text through the same screening signals used
// elsewhere (license-validation.service) — never throws, since OCR is a
// screening aid only and a failed/absent scan should never block submission.
function buildOcrFields(ocrText) {
  const text = String(ocrText || "").trim();
  if (text.length < 10) {
    return {
      licenseNumber: null,
      licenseHolderName: null,
      licenseExpiresAt: null,
      ocrStatus: "failed",
      ocrFailureReason: text.length === 0 ? "No OCR text provided" : "OCR text too short to be reliable",
    };
  }

  try {
    const signals = licenseValidationService.extractLicenseSignals(text);
    const expiryDate = licenseValidationService.extractExpiryDate(text);
    const birthDate = licenseValidationService.extractBirthDate(text);
    return {
      licenseNumber: signals.licenseNumber || null,
      licenseHolderName: signals.licenseHolderName || null,
      licenseBirthDate: birthDate || null,
      licenseExpiresAt: expiryDate || null,
      ocrStatus: "passed",
      ocrFailureReason: null,
    };
  } catch (error) {
    return {
      licenseNumber: null,
      licenseHolderName: null,
      licenseBirthDate: null,
      licenseExpiresAt: null,
      ocrStatus: "failed",
      ocrFailureReason: error.message || "Unable to process OCR text",
    };
  }
}

// The license photo must be a readable Philippine LTO license in the
// applicant's own name — someone else's license (or a different ID) is
// refused before anything is saved. The website runs the same check first
// (driver_apply/src/utils/licenseIdentity.js) and asks for a new photo.
function assertLicenseBelongsToApplicant(licenseOcrText, accountName) {
  const identity = checkLicenseIdentity(licenseOcrText, accountName);
  if (!identity.readable) {
    throw new ApiError(
      400,
      "Hindi mabasa ang driver's license sa litrato. Mag-upload ng malinaw at hindi malabong litrato ng buong license.",
      { code: "LICENSE_UNREADABLE" }
    );
  }
  if (!identity.licenseNumber) {
    throw new ApiError(
      400,
      "Walang nakitang LTO license number (hal. A12-34-567890). Mag-upload ng malinaw na litrato ng Philippine driver's license mo.",
      { code: "LICENSE_NOT_PH_FORMAT" }
    );
  }
  if (identity.nameStatus !== "match") {
    throw new ApiError(
      400,
      `Hindi tugma ang pangalan sa license sa pangalan ng account mo (${accountName}). Sariling driver's license mo ang dapat i-upload.`,
      { code: "LICENSE_NAME_MISMATCH", missingNames: identity.missingNames }
    );
  }
  return identity;
}

// Merge the applicant's confirmed license details (from the review step —
// what they typed after checking the OCR read against the physical card)
// over the raw OCR signals. Confirmed values are authoritative: the
// applicant has visually verified them, so ocrStatus is forced to
// "passed" whenever any confirmed field is present, even if the raw OCR
// text itself was noisy or empty.
function applyConfirmedLicenseOverrides(ocr, confirmedLicense) {
  const confirmed = confirmedLicense || {};
  const hasAnyConfirmedField =
    confirmed.fullName || confirmed.licenseNumber || confirmed.birthDate || confirmed.expiresAt;

  return {
    licenseNumber: confirmed.licenseNumber || ocr.licenseNumber,
    licenseHolderName: confirmed.fullName || ocr.licenseHolderName,
    licenseBirthDate: confirmed.birthDate || ocr.licenseBirthDate || null,
    licenseExpiresAt: confirmed.expiresAt || ocr.licenseExpiresAt,
    ocrStatus: hasAnyConfirmedField ? "passed" : ocr.ocrStatus,
    ocrFailureReason: hasAnyConfirmedField ? null : ocr.ocrFailureReason,
  };
}

// Apply as Driver
async function applyAsDriver(
  userId,
  plateNumber,
  licenseImageUrl,
  businessPermitImageUrl,
  licenseOcrText,
  selfieImageUrl,
  livenessStatus,
  confirmedLicense,
  extraFields = {}
) {
  const user = await db.query("SELECT * FROM users WHERE id = ?", [userId]);
  if (user.length === 0) {
    throw new ApiError(404, "User not found");
  }
  if (user[0].role !== "passenger") {
    throw new ApiError(403, "Only passenger accounts can apply to become a driver.");
  }

  const userData = user[0];
  await assertDriverApplicationOtp(userData.email);
  const identity = assertLicenseBelongsToApplicant(licenseOcrText, userData.full_name);
  const ocr = applyConfirmedLicenseOverrides(buildOcrFields(licenseOcrText), confirmedLicense);
  ocr.licenseNumber = ocr.licenseNumber || identity.licenseNumber;

  const result = await db.query(
    `INSERT INTO driver_applications
      (user_id, full_name, email, phone, address, emergency_contact_name, emergency_contact_phone,
       plate_number, franchise_number, license_image_url, business_permit_image_url,
       selfie_image_url, license_number, license_type, license_holder_name, license_birth_date, license_expires_at,
       ocr_status, ocr_failure_reason, liveness_status, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
    [
      userId,
      userData.full_name,
      userData.email,
      userData.phone,
      extraFields.address || null,
      extraFields.emergencyContactName || null,
      extraFields.emergencyContactPhone || null,
      plateNumber,
      extraFields.franchiseNumber || null,
      licenseImageUrl,
      businessPermitImageUrl,
      selfieImageUrl || null,
      ocr.licenseNumber,
      extraFields.licenseType || null,
      ocr.licenseHolderName,
      ocr.licenseBirthDate,
      ocr.licenseExpiresAt,
      ocr.ocrStatus,
      ocr.ocrFailureReason,
      livenessStatus || "pending",
    ]
  );

  await db.query(
    "UPDATE users SET driver_approval_status = 'pending' WHERE id = ?",
    [userId]
  );

  await statusHistoryModel.logStatus(result.insertId, "pending", "Application submitted.", null);
  await consumeOtp(userData.email, DRIVER_APPLICATION_PURPOSE);

  try {
    await notificationService.createNotification({
      type: "driver_application",
      title: "New driver application",
      body: `${userData.full_name} applied to become a driver.`,
      recipientRole: "admin",
      metadataJson: { userId, applicationId: result.insertId },
    });
  } catch (_error) {
    // Notification failure should not block the application itself.
  }

  return {
    success: true,
    message: "Driver application submitted. Admin will review your documents.",
    applicationId: result.insertId,
  };
}

// Get driver application status
async function getDriverApplicationStatus(userId) {
  const result = await db.query(
    `SELECT da.*, u.driver_approval_status
     FROM driver_applications da
     JOIN users u ON u.id = da.user_id
     WHERE da.user_id = ? AND da.status != 'archived'
     ORDER BY da.submitted_at DESC
     LIMIT 1`,
    [userId]
  );

  if (result.length === 0) {
    return null;
  }

  return result[0];
}

// Get the status-change timeline for the caller's own most recent
// (non-archived) driver application.
async function getDriverApplicationTimeline(userId) {
  const application = await getDriverApplicationStatus(userId);
  if (!application) {
    return [];
  }
  return statusHistoryModel.listForApplication(application.id);
}

// Resubmit driver application. The applicant's corrected details
// (`extraFields`: address, emergency contact, license type, franchise
// number) replace the previous ones; anything left out is carried over.
// The plate number always stays: a revoked driver's profile keeps its
// tricycle number when re-approved.
async function resubmitDriverApplication(
  userId,
  licenseImageUrl,
  businessPermitImageUrl,
  licenseOcrText,
  selfieImageUrl,
  livenessStatus,
  confirmedLicense,
  extraFields = {}
) {
  const user = await db.query("SELECT * FROM users WHERE id = ?", [userId]);
  if (user.length === 0) {
    throw new ApiError(404, "User not found");
  }
  if (user[0].role !== "passenger") {
    throw new ApiError(403, "Only passenger accounts can apply to become a driver.");
  }
  const userData = user[0];
  await assertDriverApplicationOtp(userData.email);
  // Before archiving anything: a rejected photo must not cost them their
  // current application.
  const identity = assertLicenseBelongsToApplicant(licenseOcrText, userData.full_name);

  // Archive old application
  await db.query(
    "UPDATE driver_applications SET status = 'archived' WHERE user_id = ? AND status != 'archived'",
    [userId]
  );

  const prevApp = await db.query(
    "SELECT plate_number, franchise_number, license_type, address, emergency_contact_name, emergency_contact_phone FROM driver_applications WHERE user_id = ? ORDER BY submitted_at DESC LIMIT 1",
    [userId]
  );

  const prev = prevApp[0] || {};
  const plateNumber = prev.plate_number || "TBD";
  const ocr = applyConfirmedLicenseOverrides(buildOcrFields(licenseOcrText), confirmedLicense);
  ocr.licenseNumber = ocr.licenseNumber || identity.licenseNumber;
  const corrected = (value, previous) => value || previous || null;

  const result = await db.query(
    `INSERT INTO driver_applications
      (user_id, full_name, email, phone, address, emergency_contact_name, emergency_contact_phone,
       plate_number, franchise_number, license_image_url, business_permit_image_url,
       selfie_image_url, license_number, license_type, license_holder_name, license_birth_date, license_expires_at,
       ocr_status, ocr_failure_reason, liveness_status, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
    [
      userId,
      userData.full_name,
      userData.email,
      userData.phone,
      corrected(extraFields.address, prev.address),
      corrected(extraFields.emergencyContactName, prev.emergency_contact_name),
      corrected(extraFields.emergencyContactPhone, prev.emergency_contact_phone),
      plateNumber,
      corrected(extraFields.franchiseNumber, prev.franchise_number),
      licenseImageUrl,
      businessPermitImageUrl,
      selfieImageUrl || null,
      ocr.licenseNumber,
      corrected(extraFields.licenseType, prev.license_type),
      ocr.licenseHolderName,
      ocr.licenseBirthDate,
      ocr.licenseExpiresAt,
      ocr.ocrStatus,
      ocr.ocrFailureReason,
      livenessStatus || "pending",
    ]
  );

  await db.query(
    "UPDATE users SET driver_approval_status = 'pending' WHERE id = ?",
    [userId]
  );

  await statusHistoryModel.logStatus(result.insertId, "pending", "Application resubmitted.", null);
  await consumeOtp(userData.email, DRIVER_APPLICATION_PURPOSE);

  try {
    await notificationService.createNotification({
      type: "driver_document_resubmission",
      title: "Driver documents resubmitted",
      body: `${userData.full_name} resubmitted driver application documents for review.`,
      recipientRole: "admin",
      metadataJson: { userId, applicationId: result.insertId },
    });
  } catch (_error) {
    // Notification failure should not block the resubmission itself.
  }

  return {
    success: true,
    message: "Application resubmitted. Admin will review your documents.",
    applicationId: result.insertId,
  };
}

module.exports = {
  PASSWORD_RESET_PURPOSE,
  DRIVER_APPLICATION_PURPOSE,
  assertDriverApplicationOtp,
  consumeVerifiedEmailOtp,
  sendOTP,
  verifyOTP,
  requestPasswordReset,
  assertEmailAvailable,
  assertEmailDomainReceivesMail,
  verifyPasswordResetCode,
  resetPasswordWithOTP,
  registerPassenger,
  applyAsDriver,
  getDriverApplicationStatus,
  getDriverApplicationTimeline,
  resubmitDriverApplication,
  sendDriverApprovalEmail,
  sendDriverRejectionEmail,
};
