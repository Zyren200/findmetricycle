const express = require("express");
const crypto = require("crypto");
const serviceAreaService = require("../services/service-area.service");

const router = express.Router();

// Public and read-only: Guiuan's boundary plus the map limits the app and
// the admin dashboard use. Clients cache it and send If-None-Match; the
// ETag changes when the boundary file or the geofence settings change.
router.get("/", (req, res) => {
  const data = serviceAreaService.describeServiceArea();
  const etag = `"${crypto
    .createHash("sha1")
    .update(`${data.version}:${data.enforced}:${data.mode}:${data.bufferMeters}`)
    .digest("hex")
    .slice(0, 16)}"`;

  res.set("ETag", etag);
  res.set("Cache-Control", "public, max-age=3600");
  if (req.headers["if-none-match"] === etag) {
    return res.status(304).end();
  }
  return res.json({ success: true, data });
});

module.exports = router;
