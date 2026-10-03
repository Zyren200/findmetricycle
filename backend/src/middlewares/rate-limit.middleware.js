const rateLimit = require("express-rate-limit");
const jwt = require("jsonwebtoken");
const env = require("../config/env");

// Key for the general /api limiter. Requests carrying a valid admin access
// token are counted per admin account: several admins in one office share
// a public IP, and every open dashboard refreshes its data every 15
// seconds, so counting them by IP throttled them all. Everyone else
// (passengers, drivers, anonymous) is still counted by IP.
function apiRateLimitKey(req) {
  const header = req.headers.authorization || "";
  if (header.startsWith("Bearer ")) {
    try {
      const payload = jwt.verify(header.slice(7), env.jwt.secret);
      if (payload.role === "admin" && payload.type === "access" && payload.userId) {
        return `admin:${payload.userId}`;
      }
    } catch (_) {
      // Invalid or expired token: counted by IP like any other request.
    }
  }
  return req.ip;
}

// Shared by the v1 (/auth) and v2 (/auth/v2) routers so an attacker can't
// double their budget by alternating between the two sets of endpoints.

// General budget for account endpoints (register, OTP, refresh, ...).
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 50,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: "Too many requests. Please try again later." },
});

// Password guessing: only failed attempts count, so a user who logs in
// successfully is never locked out by their own traffic.
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  skipSuccessfulRequests: true,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: "Too many failed login attempts. Please try again in 15 minutes." },
});

// Sending an email costs a Brevo credit and can be aimed at someone else's
// inbox, so OTP dispatch is capped much tighter than normal auth traffic —
// per IP, and independently per email address to stop one IP from farming
// codes across many accounts or one target's inbox being flooded from many IPs.
// One budget per address across every flow that emails a code (passenger,
// driver, and each admin's own forgot-password).
const otpEmailTargets = new Map(); // email -> array of send timestamps
const OTP_EMAIL_WINDOW_MS = 15 * 60 * 1000;
const OTP_EMAIL_MAX = 3;

function otpPerEmailLimiter(req, res, next) {
  return limitOtpForEmail(req.body?.email, res, next);
}

// Same budget, keyed on the signed-in user's own email.
function otpPerUserLimiter(req, res, next) {
  return limitOtpForEmail(req.user?.email, res, next);
}

function limitOtpForEmail(rawEmail, res, next) {
  if (!takeEmailBudget(rawEmail)) {
    return res.status(429).json({
      success: false,
      message: "Too many codes requested for this email. Please wait a few minutes and try again.",
    });
  }
  next();
}

// Counts one email to this address against the shared budget. Returns
// false (and counts nothing) once the address has had its share. Also used
// directly by flows that email an address that isn't in the request body
// (a Super Admin sending another admin a password reset).
function takeEmailBudget(rawEmail) {
  const email = String(rawEmail || "").toLowerCase().trim();
  if (!email) return true;

  const now = Date.now();
  const hits = (otpEmailTargets.get(email) || []).filter((t) => now - t < OTP_EMAIL_WINDOW_MS);
  if (hits.length >= OTP_EMAIL_MAX) return false;

  hits.push(now);
  otpEmailTargets.set(email, hits);
  return true;
}

// Drop emails whose window has fully elapsed so the map doesn't grow
// forever on a long-running server.
setInterval(() => {
  const cutoff = Date.now() - OTP_EMAIL_WINDOW_MS;
  for (const [email, hits] of otpEmailTargets) {
    if (hits.every((t) => t < cutoff)) otpEmailTargets.delete(email);
  }
}, OTP_EMAIL_WINDOW_MS).unref();

module.exports = {
  apiRateLimitKey,
  authLimiter,
  loginLimiter,
  otpPerEmailLimiter,
  otpPerUserLimiter,
  takeEmailBudget,
};
