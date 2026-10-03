const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const env = require("../config/env");
const roles = require("../constants/roles");
const userModel = require("../models/user.model");
const refreshTokenModel = require("../models/refresh-token.model");
const ApiError = require("../utils/api-error");
const hashToken = require("../utils/token-hash");
const parseDurationMs = require("../utils/parse-duration-ms");
const sanitizeUser = require("../utils/sanitize-user");
const db = require("../config/db");
const authV2Service = require("./auth.v2.service");
const adminAccountModel = require("../models/admin-account.model");
const { loadAdminContext, describeAdmin, signOutEverywhere } = require("./admin-access.service");
const { ADMIN_ROLES } = require("../constants/admin-permissions");
const { createFailureLimiter } = require("../utils/failure-limiter");

const refreshDurationMs = parseDurationMs(env.jwt.refreshExpiresIn) || 30 * 24 * 60 * 60 * 1000;

// Wrong passwords per admin account, on top of the per-IP login limiter, so
// one admin can't be brute-forced from many addresses.
const adminLoginFailures = createFailureLimiter({ windowMs: 15 * 60 * 1000, max: 10 });

function signAccessToken(user) {
  return jwt.sign({ userId: user.id, role: user.role, type: "access" }, env.jwt.secret, {
    expiresIn: env.jwt.accessExpiresIn,
  });
}

function signRefreshToken(user, tokenId) {
  return jwt.sign(
    { userId: user.id, role: user.role, tokenId, type: "refresh" },
    env.jwt.refreshSecret,
    {
      expiresIn: env.jwt.refreshExpiresIn,
    }
  );
}

async function issueAuthPayload(user, options = {}) {
  const client = options.client || db;

  if (options.revokeAllForUser) {
    await refreshTokenModel.revokeAllByUserId(user.id, client);
  }

  const accessToken = signAccessToken(user);
  const refreshToken = signRefreshToken(user, crypto.randomUUID());
  const expiresAt = new Date(Date.now() + refreshDurationMs);

  await refreshTokenModel.createToken(
    {
      userId: user.id,
      tokenHash: hashToken(refreshToken),
      expiresAt,
    },
    client
  );

  // Admins also get their role and permission list; the dashboard builds
  // its menus from it (the server still checks every request).
  const sanitized = sanitizeUser(user);
  if (user.role === roles.ADMIN) {
    sanitized.admin = describeAdmin(options.adminContext || (await loadAdminContext(user.id, client)));
  }

  return {
    user: sanitized,
    token: accessToken,
    accessToken,
    refreshToken,
  };
}

async function ensureUniqueIdentity({ phone, email }, client = db) {
  const byPhone = await userModel.findByPhone(phone, client);
  if (byPhone) {
    throw new ApiError(409, "Phone number is already registered.");
  }

  if (email) {
    const byEmail = await userModel.findByEmail(email, client);
    if (byEmail) {
      throw new ApiError(409, "Email is already registered.");
    }
  }
}

async function registerPassenger(payload) {
  const email = payload.email ? String(payload.email).trim() : null;

  if (!payload.fullName || !payload.phone || !payload.password || !email) {
    throw new ApiError(400, "fullName, phone, email, and password are required.");
  }

  if (payload.password.length < 8) {
    throw new ApiError(400, "Password must be at least 8 characters.");
  }

  return db.withTransaction(async (client) => {
    await ensureUniqueIdentity({ ...payload, email }, client);
    await authV2Service.consumeVerifiedEmailOtp(email, client);
    const passwordHash = await bcrypt.hash(payload.password, 12);

    const user = await userModel.createUser(
      {
        fullName: payload.fullName,
        phone: payload.phone,
        email,
        passwordHash,
        role: roles.PASSENGER,
        status: "active",
      },
      client
    );

    return issueAuthPayload(user, { client });
  });
}

async function adminExists() {
  const [{ count }] = await db.query(
    "SELECT COUNT(*) as count FROM admins a JOIN users u ON u.id = a.user_id WHERE u.deleted_at IS NULL"
  );
  return Number(count) > 0;
}

async function assertNoAdminExists(client = db) {
  const [{ count }] = await client.query(
    "SELECT COUNT(*) as count FROM admins a JOIN users u ON u.id = a.user_id WHERE u.deleted_at IS NULL"
  );
  if (Number(count) > 0) {
    throw new ApiError(
      409,
      "An admin account already exists. New admins are added by a Super Admin from Admin Accounts."
    );
  }
}

async function sendAdminOtp(email) {
  const trimmedEmail = String(email || "").trim();
  if (!trimmedEmail) {
    throw new ApiError(400, "Email is required.");
  }

  await assertNoAdminExists();

  const existingUser = await userModel.findByEmail(trimmedEmail);
  if (existingUser) {
    throw new ApiError(409, "Email is already registered.");
  }

  return authV2Service.sendOTP(trimmedEmail);
}

async function verifyAdminOtp(email, code) {
  const trimmedEmail = String(email || "").trim();
  if (!trimmedEmail || !code) {
    throw new ApiError(400, "Email and code are required.");
  }

  try {
    return await authV2Service.verifyOTP(trimmedEmail, code);
  } catch (error) {
    throw new ApiError(error.statusCode || 400, error.message || "Invalid or expired OTP.");
  }
}

async function registerAdmin(payload) {
  const email = payload.email ? String(payload.email).trim() : null;

  if (!payload.fullName || !payload.phone || !payload.password || !email) {
    throw new ApiError(400, "fullName, phone, email, and password are required.");
  }

  if (payload.password.length < 8) {
    throw new ApiError(400, "Password must be at least 8 characters.");
  }

  return db.withTransaction(async (client) => {
    await assertNoAdminExists(client);
    await ensureUniqueIdentity({ phone: payload.phone, email }, client);
    // Also consumes the registration OTP so it can't be reused afterwards.
    await authV2Service.consumeVerifiedEmailOtp(email, client);
    const passwordHash = await bcrypt.hash(payload.password, 12);

    const user = await userModel.createUser(
      {
        fullName: payload.fullName,
        phone: payload.phone,
        email,
        passwordHash,
        role: roles.ADMIN,
        status: "active",
      },
      client
    );

    // The very first admin sets up the system, so they're a Super Admin.
    await adminAccountModel.createProfile(user.id, { role: ADMIN_ROLES.SUPER_ADMIN, passwordSet: true }, client);
    const adminContext = await loadAdminContext(user.id, client);

    // Consume the registration OTP so it can't double as a pre-verified
    // code for the forgot-password flow right after signup.
    await client.query("DELETE FROM otp_codes WHERE email = ?", [email]);

    return issueAuthPayload(user, { client, adminContext });
  });
}

// Admin forgot-password works on the admin's own email: every admin has
// one, so the address typed in decides whose password is reset. Only
// active admin accounts qualify — a passenger's email gets nothing here.
async function findResettableAdmin(rawEmail) {
  const email = String(rawEmail || "").trim();
  if (!email) {
    throw new ApiError(400, "Email is required.", { field: "email" });
  }
  const admin = await adminAccountModel.findByEmail(email);
  if (!admin) {
    throw new ApiError(404, "No admin account uses this email.", { field: "email" });
  }
  if (admin.status !== "active") {
    throw new ApiError(403, "This admin account has been disabled.", { field: "email" });
  }
  return { email, admin };
}

async function requestAdminPasswordReset(rawEmail) {
  const { email } = await findResettableAdmin(rawEmail);
  return authV2Service.requestPasswordReset(email);
}

async function verifyAdminPasswordResetOtp(rawEmail, code) {
  const { email } = await findResettableAdmin(rawEmail);
  try {
    await authV2Service.verifyOTP(email, code, authV2Service.PASSWORD_RESET_PURPOSE);
    return { success: true, message: "Code verified." };
  } catch (error) {
    throw new ApiError(error.statusCode || 400, error.message || "Invalid or expired code.");
  }
}

function codeMatches(expected, actual) {
  const a = Buffer.from(String(expected || ""));
  const b = Buffer.from(String(actual || ""));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

async function resetAdminPassword(rawEmail, code, newPassword) {
  const { email, admin } = await findResettableAdmin(rawEmail);

  // Only a verified *password reset* code counts — a registration code
  // for the same address must not unlock this — and the code has to be
  // sent again here, so knowing the email alone is never enough.
  const [otp] = await db.query(
    "SELECT code, is_verified, verified_at FROM otp_codes WHERE email = ? AND purpose = ? ORDER BY id DESC LIMIT 1",
    [email, authV2Service.PASSWORD_RESET_PURPOSE]
  );
  const isVerified =
    Boolean(otp) &&
    Number(otp.is_verified) === 1 &&
    new Date(otp.verified_at).getTime() > Date.now() - 30 * 60 * 1000 &&
    codeMatches(otp.code, code);
  if (!isVerified) {
    throw new ApiError(400, "Please verify the code sent to your email first.");
  }

  const passwordHash = await bcrypt.hash(newPassword, 12);
  await userModel.updatePasswordHash(admin.user_id, passwordHash);
  await adminAccountModel.markPasswordSet(admin.user_id);
  await db.query("DELETE FROM otp_codes WHERE email = ?", [email]);
  // Every session on the old password ends, sockets included.
  await signOutEverywhere(admin.user_id);
  adminLoginFailures.reset(String(admin.user_id));

  return { success: true, message: "Password updated successfully." };
}

async function login({ email, phone, password }) {
  const identifier = email ? String(email).trim() : phone ? String(phone).trim() : "";
  if (!identifier || !password) {
    throw new ApiError(400, "email or phone and password are required.");
  }

  // Login forms show these under the matching input (details.field), so the
  // user knows whether to fix the email/phone or just retype the password.
  const user = email ? await userModel.findByEmail(identifier) : await userModel.findByPhone(identifier);
  if (!user) {
    throw new ApiError(
      401,
      email ? "This email is not registered." : "This mobile number is not registered.",
      { field: email ? "email" : "phone" }
    );
  }

  const isAdmin = user.role === roles.ADMIN;
  const failureKey = String(user.id);
  if (isAdmin && adminLoginFailures.isBlocked(failureKey)) {
    throw new ApiError(429, "Too many failed login attempts for this account. Please try again in 15 minutes.");
  }

  const valid = await bcrypt.compare(password, user.password_hash);
  if (!valid) {
    if (isAdmin) adminLoginFailures.recordFailure(failureKey);
    throw new ApiError(401, "Invalid password. Please try again.", { field: "password" });
  }

  if (user.role === roles.DRIVER && user.status === "pending") {
    throw new ApiError(403, "Driver account is pending admin approval.");
  }

  if (user.status !== "active") {
    throw new ApiError(403, `Account is ${user.status}.`);
  }

  if (isAdmin) {
    const adminContext = await loadAdminContext(user.id);
    if (!adminContext || adminContext.status !== "active") {
      throw new ApiError(403, "This admin account has been disabled.");
    }
    adminLoginFailures.reset(failureKey);
    await adminAccountModel.touchLastLogin(user.id);
    return issueAuthPayload(user, { adminContext });
  }

  return issueAuthPayload(user);
}

async function refreshAccessToken({ refreshToken }) {
  if (!refreshToken) {
    throw new ApiError(400, "refreshToken is required.");
  }

  let payload;
  try {
    payload = jwt.verify(refreshToken, env.jwt.refreshSecret);
  } catch (_error) {
    throw new ApiError(401, "Invalid or expired refresh token.");
  }

  if (payload.type && payload.type !== "refresh") {
    throw new ApiError(401, "Invalid token type for refresh.");
  }

  const tokenHash = hashToken(refreshToken);
  const storedToken = await refreshTokenModel.findActiveTokenByHash(tokenHash);
  if (!storedToken) {
    throw new ApiError(401, "Refresh token is not active.");
  }

  if (Number(storedToken.user_id) !== Number(payload.userId)) {
    throw new ApiError(401, "Refresh token user mismatch.");
  }

  const user = await userModel.findById(payload.userId);
  if (!user || user.status !== "active") {
    await refreshTokenModel.revokeTokenByHash(tokenHash);
    throw new ApiError(403, "Account is not active.");
  }

  let adminContext;
  if (user.role === roles.ADMIN) {
    adminContext = await loadAdminContext(user.id);
    if (!adminContext || adminContext.status !== "active") {
      await refreshTokenModel.revokeAllByUserId(user.id);
      throw new ApiError(401, "This admin account has been disabled.");
    }
  }

  await refreshTokenModel.revokeTokenByHash(tokenHash);
  return issueAuthPayload(user, { adminContext });
}

async function logout({ refreshToken }) {
  if (!refreshToken) {
    throw new ApiError(400, "refreshToken is required.");
  }

  await refreshTokenModel.revokeTokenByHash(hashToken(refreshToken));
  return { ok: true };
}

async function logoutAll({ userId }) {
  await refreshTokenModel.revokeAllByUserId(userId);
  return { ok: true };
}

module.exports = {
  registerPassenger,
  registerAdmin,
  adminExists,
  sendAdminOtp,
  verifyAdminOtp,
  requestAdminPasswordReset,
  verifyAdminPasswordResetOtp,
  resetAdminPassword,
  login,
  refreshAccessToken,
  logout,
  logoutAll,
};
