const db = require("../config/db");

async function getCurrentFareSettings() {
  const rows = await db.query("SELECT * FROM fare_settings WHERE id = 1 AND deleted_at IS NULL LIMIT 1");
  return rows[0] || null;
}

async function updateFareSettings(payload) {
  await db.query(
    `
      UPDATE fare_settings
      SET base_fare = ?,
          per_km_rate = ?,
          minimum_fare = ?,
          night_fee = COALESCE(?, night_fee),
          additional_passenger_fee = ?,
          updated_by = ?
      WHERE id = 1
    `,
    [
      payload.baseFare,
      payload.perKmRate,
      payload.minimumFare ?? 0,
      payload.nightFee ?? null,
      payload.additionalPassengerFee ?? 0,
      payload.updatedBy || null,
    ]
  );

  return getCurrentFareSettings();
}

module.exports = {
  getCurrentFareSettings,
  updateFareSettings,
};
