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

const refreshDurationMs = parseDurationMs(env.jwt.refreshExpiresIn) || 30 * 24 * 60 * 60 * 1000;

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

  return {
    user: sanitizeUser(user),
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
    throw new ApiError(409, "An admin account already exists. Only one admin account is allowed.");
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

    await userModel.createAdminProfile(user.id, client);

    // Consume the registration OTP so it can't double as a pre-verified
    // code for the forgot-password flow right after signup.
    await client.query("DELETE FROM otp_codes WHERE email = ?", [email]);

    return issueAuthPayload(user, { client });
  });
}

async function getRegisteredAdminEmail() {
  const rows = await db.query(
    "SELECT u.email FROM admins a JOIN users u ON u.id = a.user_id WHERE u.deleted_at IS NULL LIMIT 1"
  );
  const email = rows[0]?.email || null;
  if (!email) {
    throw new ApiError(404, "No admin account exists.");
  }
  return email;
}

async function requestAdminPasswordReset() {
  const email = await getRegisteredAdminEmail();
  return authV2Service.requestPasswordReset(email);
}

async function verifyAdminPasswordResetOtp(code) {
  const email = await getRegisteredAdminEmail();
  try {
    await authV2Service.verifyOTP(email, code, authV2Service.PASSWORD_RESET_PURPOSE);
    return { success: true, message: "Code verified." };
  } catch (error) {
    throw new ApiError(error.statusCode || 400, error.message || "Invalid or expired code.");
  }
}

async function resetAdminPassword(newPassword) {
  const email = await getRegisteredAdminEmail();

  // Only a verified *password reset* code counts — a registration code
  // for the same address must not unlock this.
  const latestOtp = await db.query(
    "SELECT is_verified, verified_at FROM otp_codes WHERE email = ? AND purpose = ? ORDER BY id DESC LIMIT 1",
    [email, authV2Service.PASSWORD_RESET_PURPOSE]
  );
  const isVerified =
    latestOtp.length > 0 &&
    Number(latestOtp[0].is_verified) === 1 &&
    new Date(latestOtp[0].verified_at).getTime() > Date.now() - 30 * 60 * 1000;
  if (!isVerified) {
    throw new ApiError(400, "Please verify the code sent to your email first.");
  }

  const user = await userModel.findByEmail(email);
  if (!user) {
    throw new ApiError(404, "Admin account not found.");
  }

  const passwordHash = await bcrypt.hash(newPassword, 12);
  await userModel.updatePasswordHash(user.id, passwordHash);
  await db.query("DELETE FROM otp_codes WHERE email = ?", [email]);
  await refreshTokenModel.revokeAllByUserId(user.id);

  return { success: true, message: "Password updated successfully." };
}

async function login({ email, phone, password }) {
  const identifier = email ? String(email).trim() : phone ? String(phone).trim() : "";
  if (!identifier || !password) {
    throw new ApiError(400, "email or phone and password are required.");
  }

  const user = email ? await userModel.findByEmail(identifier) : await userModel.findByPhone(identifier);
  if (!user) {
    throw new ApiError(401, "Invalid credentials.");
  }

  const valid = await bcrypt.compare(password, user.password_hash);
  if (!valid) {
    throw new ApiError(401, "Invalid credentials.");
  }

  if (user.role === roles.DRIVER && user.status === "pending") {
    throw new ApiError(403, "Driver account is pending admin approval.");
  }

  if (user.status !== "active") {
    throw new ApiError(403, `Account is ${user.status}.`);
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

  await refreshTokenModel.revokeTokenByHash(tokenHash);
  return issueAuthPayload(user);
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
