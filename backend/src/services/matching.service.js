const bookingModel = require("../models/booking.model");
const driverModel = require("../models/driver.model");
const { haversineKm } = require("../utils/haversine");

// Riders farther than this from the pickup aren't offered — a tricycle
// across town (or on another island) isn't a real option for the passenger.
const MAX_PICKUP_DISTANCE_KM = 5;

async function listNearestAvailableDrivers(pickupLat, pickupLng, limit = 5, excludeDriverIds = []) {
  const onlineDrivers = await driverModel.getApprovedOnlineDriversWithLocation();
  const busyDriverIds = await bookingModel.listDriverIdsWithActiveRide();
  const busySet = new Set(busyDriverIds);
  const excludeSet = new Set(excludeDriverIds);

  const candidates = onlineDrivers
    .filter((driver) => !busySet.has(driver.id))
    .filter((driver) => !excludeSet.has(driver.id))
    .map((driver) => ({
      ...driver,
      distanceToPickupKm: haversineKm(
        Number(driver.current_lat),
        Number(driver.current_lng),
        Number(pickupLat),
        Number(pickupLng)
      ),
    }))
    .filter((driver) => driver.distanceToPickupKm <= MAX_PICKUP_DISTANCE_KM)
    .sort((a, b) => a.distanceToPickupKm - b.distanceToPickupKm);

  return candidates.slice(0, limit);
}

async function findNearestAvailableDriver(pickupLat, pickupLng, excludeDriverIds = []) {
  const list = await listNearestAvailableDrivers(pickupLat, pickupLng, 1, excludeDriverIds);
  return list[0] || null;
}

module.exports = {
  MAX_PICKUP_DISTANCE_KM,
  listNearestAvailableDrivers,
  findNearestAvailableDriver,
};
