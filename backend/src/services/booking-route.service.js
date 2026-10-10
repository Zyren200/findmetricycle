const routeModel = require("../models/booking-route.model");
const { haversineKm } = require("../utils/haversine");

// Keep a useful trip path without writing every 4-second GPS heartbeat.
const MIN_RECORD_INTERVAL_MS = 10 * 1000;
const MIN_RECORD_MOVEMENT_KM = 0.02;

function shouldRecordPoint(previous, lat, lng, now = new Date()) {
  if (!previous) return true;

  const previousAt = new Date(previous.recorded_at).getTime();
  const elapsedMs = Number.isFinite(previousAt) ? now.getTime() - previousAt : Infinity;
  const movedKm = haversineKm(Number(previous.lat), Number(previous.lng), lat, lng);

  return elapsedMs >= MIN_RECORD_INTERVAL_MS || movedKm >= MIN_RECORD_MOVEMENT_KM;
}

async function recordPoint({ bookingId, lat, lng }) {
  const previous = await routeModel.findLatestForBooking(bookingId);
  if (!shouldRecordPoint(previous, lat, lng)) return false;

  await routeModel.create({ bookingId, lat, lng });
  return true;
}

module.exports = {
  MIN_RECORD_INTERVAL_MS,
  MIN_RECORD_MOVEMENT_KM,
  shouldRecordPoint,
  recordPoint,
};
