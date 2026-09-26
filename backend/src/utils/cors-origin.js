const env = require("../config/env");

// Any localhost port is convenient for Vite / Flutter web / the
// backend-served /admin page during development, but must not be trusted
// once deployed.
const localhostOriginPattern = /^https?:\/\/(?:localhost|127\.0\.0\.1)(?::\d+)?$/i;
const allowAll = env.clientOrigins.includes("*");
const allowLocalhost = env.nodeEnv !== "production";

// Shared by the Express CORS middleware and the Socket.IO server so HTTP and
// realtime connections accept exactly the same origins.
function isAllowedOrigin(origin) {
  if (allowAll || !origin) return true;
  if (env.clientOrigins.includes(origin)) return true;
  return allowLocalhost && localhostOriginPattern.test(origin);
}

module.exports = { isAllowedOrigin, allowAll };
