const dotenv = require("dotenv");
const path = require("path");

dotenv.config({ path: path.resolve(__dirname, "../../.env") });

const required = ["DB_HOST", "DB_USER", "DB_NAME", "JWT_SECRET"];

for (const key of required) {
  if (!process.env[key]) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
}

module.exports = {
  nodeEnv: process.env.NODE_ENV || "development",
  port: Number(process.env.PORT || 5000),
  clientOrigins: (process.env.CLIENT_ORIGIN || "*")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean),

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
  },

  captcha: {
    recaptchaSecretKey: process.env.RECAPTCHA_SECRET_KEY || "",
  },
};
