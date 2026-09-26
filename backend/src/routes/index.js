const express = require("express");
const authRoutes = require("./auth.routes");
const authV2Routes = require("./auth.v2.routes");
const passengerRoutes = require("./passenger.routes");
const driverRoutes = require("./driver.routes");
const adminRoutes = require("./admin.routes");
const favoritesRoutes = require("./favorites.routes");
const documentsRoutes = require("./documents.routes");

const router = express.Router();

const db = require("../config/db");

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
    res.status(503).json({ success: false, db: "down", error: err.message });
  }
});

router.use("/auth", authRoutes);
router.use("/auth/v2", authV2Routes);
router.use("/passenger", passengerRoutes);
router.use("/passenger/favorites", favoritesRoutes);
router.use("/driver", driverRoutes);
router.use("/admin", adminRoutes);
router.use("/documents", documentsRoutes);

module.exports = router;
