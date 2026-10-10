const dotenv = require("dotenv");
const path = require("path");

dotenv.config({ path: path.resolve(__dirname, "../../.env") });

const required = ["DB_HOST", "DB_USER", "DB_NAME", "JWT_SECRET"];

for (const key of required) {
  if (!process.env[key]) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
}

// Anyone who knows the JWT secret can mint an admin token, so refuse to
// start in production with a placeholder or short secret.
if (process.env.NODE_ENV === "production") {
  const weakSecret = (value) =>
    !value || value.length < 32 || /^(dev|test|change|replace|secret)/i.test(value);
  for (const key of ["JWT_SECRET", "JWT_REFRESH_SECRET"]) {
    if (weakSecret(process.env[key])) {
      throw new Error(
        `${key} must be a random value of at least 32 characters in production ` +
          "(generate one with: node -e \"console.log(require('crypto').randomBytes(48).toString('hex'))\")."
      );
    }
  }
}

module.exports = {
  nodeEnv: process.env.NODE_ENV || "development",
  port: Number(process.env.PORT || 5000),
  clientOrigins: (process.env.CLIENT_ORIGIN || "*")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean),
  // Where admins sign in; linked from the emails new admins receive.
  // Optional — without it the email just names the admin dashboard.
  adminDashboardUrl: /^https?:\/\//i.test(process.env.ADMIN_DASHBOARD_URL || "")
    ? process.env.ADMIN_DASHBOARD_URL.trim()
    : "",

  db: {
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_NAME,
  },

  jwt: {
    secret: process.env.JWT_SECRET,
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || process.env.JWT_EXPIRES_IN || "15m",
    refreshSecret: process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET,
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || "30d",
  },

  upload: {
    dir: process.env.UPLOAD_DIR || "uploads",
    maxUploadMb: Number(process.env.MAX_UPLOAD_MB || 5),
  },

  geofence: {
    // On: bookings outside Guiuan are refused. GEOFENCE_ENABLED=false turns
    // it off (only for testing from outside the service area).
    enabled: process.env.GEOFENCE_ENABLED !== "false",
    // "polygon": Guiuan's municipal boundary (data/service-area); "radius":
    // the older circle around GEOFENCE_CENTER_*.
    mode: process.env.GEOFENCE_MODE === "radius" ? "radius" : "polygon",
    // Tolerance outside the boundary for GPS error along borders and coasts.
    bufferMeters: Math.max(0, Number(process.env.GEOFENCE_BUFFER_METERS ?? 300) || 0),
    centerLat: Number(process.env.GEOFENCE_CENTER_LAT || 11.033),
    centerLng: Number(process.env.GEOFENCE_CENTER_LNG || 125.722),
    radiusKm: Number(process.env.GEOFENCE_RADIUS_KM || 50),
  },

  mail: {
    smtpHost: process.env.BREVO_SMTP_HOST || "",
    smtpPort: Number(process.env.BREVO_SMTP_PORT || 587),
    senderEmail: process.env.BREVO_SENDER_EMAIL || "",
    smtpPassword: process.env.BREVO_SMTP_PASSWORD || "",
    fromEmail: process.env.BREVO_FROM_EMAIL || process.env.BREVO_SENDER_EMAIL || "noreply@findmetricycle.local",
    // Sender name on Contact Support replies (same address as the OTP emails).
    supportFromName: (process.env.SUPPORT_FROM_NAME || "").trim() || "support.findmetricycle",
  },

  captcha: {
    recaptchaSecretKey: process.env.RECAPTCHA_SECRET_KEY || "",
  },
};
