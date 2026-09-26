const env = require("../config/env");

async function verifyRecaptcha(token, remoteIp) {
  if (!token) return false;
  if (!env.captcha.recaptchaSecretKey) {
    console.warn("RECAPTCHA_SECRET_KEY is not set — CAPTCHA verification is disabled.");
    return false;
  }

  const params = new URLSearchParams({
    secret: env.captcha.recaptchaSecretKey,
    response: token,
  });
  if (remoteIp) params.set("remoteip", remoteIp);

  try {
    const response = await fetch("https://www.google.com/recaptcha/api/siteverify", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: params.toString(),
    });
    const result = await response.json();
    return Boolean(result.success);
  } catch (error) {
    console.error("reCAPTCHA verification request failed:", error.message);
    return false;
  }
}

module.exports = { verifyRecaptcha };
