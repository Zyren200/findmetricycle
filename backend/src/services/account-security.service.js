// Password-change OTP confirmation — shared by both the passenger and
// driver routers (a driver is the same `users` account, so there is only
// ever one password to change regardless of which mode the app is in).
const bcrypt = require("bcryptjs");
const userModel = require("../models/user.model");
const authV2Service = require("./auth.v2.service");
const ApiError = require("../utils/api-error");

const CHANGE_PASSWORD_PURPOSE = "change_password";

function maskEmail(email) {
  const [name, domain] = String(email).split("@");
  if (!domain) return email;
  const visible = name.slice(0, 2);
  return `${visible}${"*".repeat(Math.max(name.length - 2, 1))}@${domain}`;
}

// Step 1: confirm the caller actually knows the current password, then
// email them a 6-digit code — nothing about the password changes yet.
async function requestPasswordChangeOtp(userId, currentPassword) {
  const user = await userModel.findById(userId);
  if (!user) {
    throw new ApiError(404, "Account not found.");
  }

  const valid = await bcrypt.compare(currentPassword, user.password_hash);
  if (!valid) {
    throw new ApiError(400, "Current password is incorrect.");
  }

  if (!user.email) {
    throw new ApiError(400, "Add an email address to your account before changing your password.");
  }

  await authV2Service.sendOTP(user.email, CHANGE_PASSWORD_PURPOSE);

  return {
    success: true,
    message: "A verification code was sent to your email.",
    email: maskEmail(user.email),
  };
}

// Step 2: re-checks the current password (it may have been changed by
// someone else in the meantime) and the OTP before actually writing the
// new password hash. The OTP check is the hard gate — a wrong/expired
// code throws and the password is left untouched.
async function confirmPasswordChange(userId, { currentPassword, newPassword, otp }) {
  const user = await userModel.findById(userId);
  if (!user) {
    throw new ApiError(404, "Account not found.");
  }

  const valid = await bcrypt.compare(currentPassword, user.password_hash);
  if (!valid) {
    throw new ApiError(400, "Current password is incorrect.");
  }

  if (!user.email) {
    throw new ApiError(400, "Add an email address to your account before changing your password.");
  }

  try {
    await authV2Service.verifyOTP(user.email, otp, CHANGE_PASSWORD_PURPOSE);
  } catch (err) {
    throw new ApiError(err.statusCode || 400, err.message || "Invalid or expired code.");
  }

  const passwordHash = await bcrypt.hash(newPassword, 12);
  await userModel.updatePasswordHash(userId, passwordHash);

  return { success: true, message: "Password updated." };
}

module.exports = {
  requestPasswordChangeOtp,
  confirmPasswordChange,
};
