const db = require("../config/db");
const nodemailer = require("nodemailer");
const licenseValidationService = require("./license-validation.service");
const notificationService = require("./notification.service");
const statusHistoryModel = require("../models/application-status-history.model");
const ApiError = require("../utils/api-error");

// Generate a 6-digit OTP
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
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
    console.log(`✓ OTP sent to ${email}: ${otp}`);
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
          <h2 style="color: #0E8C46;">🎉 Congratulations, ${fullName}!</h2>
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
          <p>Hi ${fullName},</p>
          <p>Thank you for applying as a driver. Unfortunately, your application could not be approved at this time.</p>
          <p><strong>Reason:</strong></p>
          <div style="background: #fff3cd; padding: 15px; border-radius: 6px; border-left: 4px solid #FFC107;">
            ${reason || "Please contact support for more details."}
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
    throw new Error("Invalid or expired OTP");
  }

  if (pending.attempts >= MAX_OTP_ATTEMPTS) {
    throw new Error("Too many attempts. Please request a new code.");
  }

  if (pending.code !== code) {
    await db.query("UPDATE otp_codes SET attempts = attempts + 1 WHERE id = ?", [pending.id]);
    throw new Error("Invalid or expired OTP");
  }

  await db.query("UPDATE otp_codes SET is_verified = 1, verified_at = NOW() WHERE id = ?", [pending.id]);

  return { success: true, message: "OTP verified" };
}

// Request a password reset code
async function requestPasswordReset(email) {
  const users = await db.query("SELECT id FROM users WHERE email = ?", [email]);
  if (users.length === 0) {
    // Don't reveal whether the email is registered.
    return { success: true, message: "If that email is registered, a reset code has been sent." };
  }

  const otp = generateOTP();
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

  const existing = await db.query(
    "SELECT id FROM otp_codes WHERE email = ? AND is_verified = 0 AND expires_at > NOW()",
    [email]
  );

  if (existing.length > 0) {
    await db.query(
      "UPDATE otp_codes SET code = ?, attempts = 0, expires_at = ? WHERE email = ?",
      [otp, expiresAt, email]
    );
  } else {
    await db.query(
      "INSERT INTO otp_codes (email, code, attempts, expires_at) VALUES (?, ?, 0, ?)",
      [email, otp, expiresAt]
    );
  }

  await sendPasswordResetEmail(email, otp);
  return { success: true, message: "If that email is registered, a reset code has been sent." };
}

// Verify the reset code and update the password
async function resetPasswordWithOTP(email, code, newPassword) {
  const result = await db.query(
    "SELECT * FROM otp_codes WHERE email = ? AND code = ? AND is_verified = 0 AND expires_at > NOW()",
    [email, code]
  );

  if (result.length === 0) {
    await db.query(
      "UPDATE otp_codes SET attempts = attempts + 1 WHERE email = ? AND is_verified = 0",
      [email]
    );
    throw new Error("Invalid or expired code");
  }

  const users = await db.query("SELECT id FROM users WHERE email = ?", [email]);
  if (users.length === 0) {
    throw new Error("Account not found");
  }

  const bcrypt = require("bcryptjs");
  const passwordHash = await bcrypt.hash(newPassword, 10);

  await db.query("UPDATE users SET password_hash = ? WHERE email = ?", [passwordHash, email]);
  await db.query("UPDATE otp_codes SET is_verified = 1, verified_at = NOW() WHERE email = ? AND code = ?", [email, code]);

  return { success: true, message: "Password updated successfully." };
}

// Register Passenger (after OTP verification)
async function registerPassenger(fullName, email, phone, password, middleName = null) {
  const existing = await db.query("SELECT id FROM users WHERE email = ?", [email]);
  if (existing.length > 0) {
    throw new Error("Email already registered");
  }

  const existingPhone = await db.query("SELECT id FROM users WHERE phone = ?", [phone]);
  if (existingPhone.length > 0) {
    throw new Error("Phone number already registered");
  }

  const bcrypt = require("bcryptjs");
  const passwordHash = await bcrypt.hash(password, 10);

  const result = await db.query(
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
    throw new Error("User not found");
  }
  if (user[0].role !== "passenger") {
    throw new ApiError(403, "Only passenger accounts can apply to become a driver.");
  }

  const userData = user[0];
  const ocr = applyConfirmedLicenseOverrides(buildOcrFields(licenseOcrText), confirmedLicense);

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

// Resubmit driver application
async function resubmitDriverApplication(
  userId,
  licenseImageUrl,
  businessPermitImageUrl,
  licenseOcrText,
  selfieImageUrl,
  livenessStatus,
  confirmedLicense
) {
  const user = await db.query("SELECT * FROM users WHERE id = ?", [userId]);
  if (user.length === 0) {
    throw new Error("User not found");
  }
  if (user[0].role !== "passenger") {
    throw new ApiError(403, "Only passenger accounts can apply to become a driver.");
  }
  const userData = user[0];

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
      prev.address || null,
      prev.emergency_contact_name || null,
      prev.emergency_contact_phone || null,
      plateNumber,
      prev.franchise_number || null,
      licenseImageUrl,
      businessPermitImageUrl,
      selfieImageUrl || null,
      ocr.licenseNumber,
      prev.license_type || null,
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
  sendOTP,
  verifyOTP,
  requestPasswordReset,
  resetPasswordWithOTP,
  registerPassenger,
  applyAsDriver,
  getDriverApplicationStatus,
  getDriverApplicationTimeline,
  resubmitDriverApplication,
  sendDriverApprovalEmail,
  sendDriverRejectionEmail,
};
