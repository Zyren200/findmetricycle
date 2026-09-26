const rateLimit = require("express-rate-limit");

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

module.exports = { authLimiter, loginLimiter };
