const { MIN_PASSENGERS, MAX_PASSENGERS } = require("../constants/fare");

function calculateFare(distanceKm, fareSettings, passengerCount = 1) {
  return calculateFareBreakdown(distanceKm, fareSettings, passengerCount).total;
}

function calculateFareBreakdown(distanceKm, fareSettings, passengerCount = 1) {
  const distance = Number(distanceKm || 0);
  const baseFare = Number(fareSettings.base_fare || 0);
  const perKmRate = Number(fareSettings.per_km_rate || 0);
  const additionalPassengerFee = Number(fareSettings.additional_passenger_fee || 0);
  // Present in fare_settings but previously never applied anywhere — a
  // configured floor should actually floor the fare.
  const minimumFare = Number(fareSettings.minimum_fare || 0);

  const count = Math.min(
    Math.max(Number(passengerCount) || MIN_PASSENGERS, MIN_PASSENGERS),
    MAX_PASSENGERS
  );

  const singlePassengerFare = Number((baseFare + distance * perKmRate).toFixed(2));
  const additionalPassengersCharge = Number(
    ((count - 1) * additionalPassengerFee).toFixed(2)
  );
  const total = Number(
    Math.max(singlePassengerFare + additionalPassengersCharge, minimumFare).toFixed(2)
  );

  return {
    distanceKm: distance,
    passengerCount: count,
    baseFare,
    perKmRate,
    additionalPassengerFee,
    minimumFare,
    singlePassengerFare,
    additionalPassengersCharge,
    total,
  };
}

// The passenger app sends the length of the road route it showed (and
// priced) the trip by. Roads are never shorter than the straight line, and
// even Guiuan's coastal roads stay within ~1.6x of it, so anything outside
// these bounds is clamped rather than trusted.
const MAX_ROUTE_TO_STRAIGHT_RATIO = 2.5;
const MAX_ROUTE_EXTRA_KM = 1;

/** Trip distance for pricing: the app's road route, within sane bounds. */
function resolveTripDistanceKm(straightKm, routeKm) {
  const straight = Number(straightKm) || 0;
  const route = Number(routeKm);
  if (!Number.isFinite(route) || route <= 0) return straight;
  const max = straight * MAX_ROUTE_TO_STRAIGHT_RATIO + MAX_ROUTE_EXTRA_KM;
  return Number(Math.min(Math.max(route, straight), max).toFixed(3));
}

/**
 * The rates a booking was priced with (saved in its fare breakdown), so a
 * fare change in the admin never re-prices a ride already booked. Falls
 * back to [current] for bookings made before rates were saved.
 */
function ratesForBooking(booking, current) {
  let saved = booking?.fare_breakdown_json;
  if (typeof saved === "string") {
    try {
      saved = JSON.parse(saved);
    } catch {
      saved = null;
    }
  }
  if (!saved || typeof saved !== "object" || saved.baseFare == null) return current;
  return {
    base_fare: saved.baseFare,
    per_km_rate: saved.perKmRate,
    additional_passenger_fee: saved.additionalPassengerFee,
    minimum_fare: saved.minimumFare,
  };
}

module.exports = {
  calculateFare,
  calculateFareBreakdown,
  resolveTripDistanceKm,
  ratesForBooking,
};
