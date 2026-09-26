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

module.exports = {
  calculateFare,
  calculateFareBreakdown,
};
