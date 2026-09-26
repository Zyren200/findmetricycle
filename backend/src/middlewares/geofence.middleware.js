const { isInsideGeofence } = require("../utils/geofence");

function geofenceFields(...fieldPairs) {
  return (req, res, next) => {
    for (const [latKey, lngKey] of fieldPairs) {
      const lat = Number(req.body?.[latKey]);
      const lng = Number(req.body?.[lngKey]);

      if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
        continue;
      }

      if (!isInsideGeofence(lat, lng)) {
        return res.status(403).json({
          success: false,
          message: "Service is only available within Guiuan area.",
        });
      }
    }
    next();
  };
}

module.exports = {
  geofenceFields,
};
