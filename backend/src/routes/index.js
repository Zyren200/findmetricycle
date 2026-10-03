const express = require("express");
const authRoutes = require("./auth.routes");
const authV2Routes = require("./auth.v2.routes");
const passengerRoutes = require("./passenger.routes");
const driverRoutes = require("./driver.routes");
const adminRoutes = require("./admin.routes");
const favoritesRoutes = require("./favorites.routes");
const documentsRoutes = require("./documents.routes");
const devicesRoutes = require("./devices.routes");
const serviceAreaRoutes = require("./service-area.routes");

const router = express.Router();

const db = require("../config/db");
const systemSettingsService = require("../services/system-settings.service");
const barangayService = require("../services/barangay.service");

router.get("/health", (_req, res) => {
  res.json({
    success: true,
    message: "FindMeTricycle backend is running.",
  });
});

router.get("/health/db", async (_req, res) => {
  try {
    await db.query("SELECT 1");
    res.json({ success: true, db: "ok" });
  } catch (err) {
    console.error("DB health check failed:", err.message);
    res.status(503).json({ success: false, db: "down" });
  }
});

// Public: support contacts, service hours and disabled barangays, which the
// apps show before (and without) a login.
router.get("/app-config", async (_req, res, next) => {
  try {
    const config = await systemSettingsService.getPublicConfig();
    config.disabledBarangays = await barangayService.listDisabledBarangayNames();
    res.json({ success: true, data: config });
  } catch (error) {
    next(error);
  }
});

router.use("/auth", authRoutes);
router.use("/auth/v2", authV2Routes);
router.use("/passenger", passengerRoutes);
router.use("/passenger/favorites", favoritesRoutes);
router.use("/driver", driverRoutes);
router.use("/admin", adminRoutes);
router.use("/documents", documentsRoutes);
router.use("/devices", devicesRoutes);
router.use("/service-area", serviceAreaRoutes);

module.exports = router;
