const jwt = require("jsonwebtoken");
const env = require("../config/env");
const ApiError = require("../utils/api-error");

const CAPTCHA_TOKEN_PURPOSE = "captcha_verified";

function signCaptchaSessionToken() {
  return jwt.sign({ purpose: CAPTCHA_TOKEN_PURPOSE }, env.jwt.secret, { expiresIn: "30m" });
}

// Gate for driver-application entry points: the website exchanges a
// completed reCAPTCHA for one of these short-lived tokens (via
// POST /auth/v2/verify-captcha) and must present it here before the
// backend will send an OTP for the driver-application flow.
function requireCaptcha(req, _res, next) {
  try {
    const token = req.headers["x-captcha-token"] || req.body.captchaSessionToken;
    if (!token) {
      throw new ApiError(403, "CAPTCHA verification is required.");
    }
    const payload = jwt.verify(token, env.jwt.secret);
    if (payload.purpose !== CAPTCHA_TOKEN_PURPOSE) {
      throw new ApiError(403, "Invalid CAPTCHA session.");
    }
    next();
  } catch (error) {
    if (error.name === "JsonWebTokenError" || error.name === "TokenExpiredError") {
      return next(new ApiError(403, "CAPTCHA session expired. Please verify again."));
    }
    next(error);
  }
}

module.exports = { requireCaptcha, signCaptchaSessionToken };
