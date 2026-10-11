const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const morgan = require("morgan");
const path = require("path");
const multer = require("multer");
const rateLimit = require("express-rate-limit");
const env = require("./config/env");
const apiRoutes = require("./routes");
const errorMiddleware = require("./middlewares/error.middleware");
const ApiError = require("./utils/api-error");
const { isAllowedOrigin, allowAll } = require("./utils/cors-origin");
const { apiRateLimitKey } = require("./middlewares/rate-limit.middleware");

// Baseline abuse protection for every /api route — existing per-route
// limiters (auth, OTP) stay in place and are stricter than this; this is
// just the floor for everything else (driver location updates, booking
// creation, SOS, etc) that previously had none at all. Admin dashboards are
// counted per admin account rather than per IP (see apiRateLimitKey).
const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  keyGenerator: apiRateLimitKey,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: "Too many requests. Please slow down." },
});

const app = express();

// Railway (and most hosts) sit one proxy in front of the app; trust it so
// req.ip is the real client IP and rate limits aren't shared by everyone.
app.set("trust proxy", 1);

// helmet's default CSP blocks the admin dashboard's live map when it is
// served from backend/public/admin: MapLibre runs its tile worker from a
// blob: URL and loads the basemap style/tiles from CARTO.
const MAP_HOSTS = ["https://basemaps.cartocdn.com", "https://*.basemaps.cartocdn.com"];
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        connectSrc: ["'self'", "ws:", "wss:", ...MAP_HOSTS],
        workerSrc: ["'self'", "blob:"],
        childSrc: ["'self'", "blob:"],
        imgSrc: ["'self'", "data:", "blob:", ...MAP_HOSTS],
      },
    },
  })
);

if (allowAll && env.nodeEnv === "production") {
  console.warn(
    "WARNING: CLIENT_ORIGIN is not set — CORS is reflecting every origin with credentials enabled. " +
      "Set CLIENT_ORIGIN to your admin dashboard's real URL before running in production."
  );
}
app.use(
  cors({
    origin: (origin, callback) => {
      if (isAllowedOrigin(origin)) {
        callback(null, true);
        return;
      }
      callback(new ApiError(403, "CORS origin not allowed."));
    },
    credentials: true,
  })
);
// Document links carry the admin's access token as ?token= (an <a href>
// can't send headers) — keep it out of the request log.
morgan.token("safe-url", (req) =>
  (req.originalUrl || req.url).replace(/([?&]token=)[^&]+/gi, "$1[redacted]")
);
app.use(morgan(":method :safe-url :status :response-time ms - :res[content-length]"));
app.use(express.json({ limit: "2mb" }));
app.use(express.urlencoded({ extended: true }));

// Driver license/permit/selfie documents are sensitive — never served
// publicly. Applicants and admins must fetch them via the authenticated
// /api/documents/driver/:filename route instead.
app.use("/uploads/driver-docs", (_req, res) => {
  res.status(403).json({
    success: false,
    message: "This document requires authentication. Use /api/documents/driver/:filename.",
  });
});

app.use(
  "/uploads",
  express.static(path.resolve(process.cwd(), env.upload.dir), {
    maxAge: "1d",
  })
);

// Serve static files (prototypes, public assets)
app.use(
  express.static(path.resolve(__dirname, "../public"), {
    maxAge: "1d",
  })
);

app.use("/api", apiLimiter, apiRoutes);

app.use((error, _req, _res, next) => {
  if (error instanceof multer.MulterError) {
    error.statusCode = 400;
    error.message = error.message || "Invalid file upload.";
  }
  next(error);
});

app.use(errorMiddleware);

module.exports = app;
