const env = require("../config/env");
const { haversineKm } = require("./haversine");

function isInsideGeofence(lat, lng) {
  const distance = haversineKm(lat, lng, env.geofence.centerLat, env.geofence.centerLng);
  return distance <= env.geofence.radiusKm;
}

module.exports = {
  isInsideGeofence,
};
