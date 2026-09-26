#!/usr/bin/env node
// Replaces raw-coordinate pickup / drop-off addresses ("11.10853, 125.38810")
// on existing bookings with place names from OpenStreetMap. Safe to re-run;
// ~1 lookup per second (Nominatim's usage policy).
//   node scripts/fill-booking-addresses.js
const db = require("../src/config/db");
const { reverseGeocode, isCoordinateAddress } = require("../src/services/geocoding.service");

async function main() {
  const rows = await db.query(
    "SELECT id, pickup_address, pickup_lat, pickup_lng, dropoff_address, dropoff_lat, dropoff_lng FROM bookings ORDER BY id"
  );
  let updated = 0;
  let missed = 0;
  for (const row of rows) {
    for (const [column, address, lat, lng] of [
      ["pickup_address", row.pickup_address, row.pickup_lat, row.pickup_lng],
      ["dropoff_address", row.dropoff_address, row.dropoff_lat, row.dropoff_lng],
    ]) {
      if (!isCoordinateAddress(address)) continue;
      const name = await reverseGeocode(lat, lng);
      if (!name) {
        missed += 1;
        console.log(`#${row.id} ${column}: no place name found`);
        continue;
      }
      await db.query(`UPDATE bookings SET ${column} = ? WHERE id = ?`, [name.slice(0, 255), row.id]);
      updated += 1;
      console.log(`#${row.id} ${column}: ${address} -> ${name}`);
    }
  }
  console.log(`Done: ${updated} updated, ${missed} not found.`);
  process.exit(0);
}

main().catch((error) => {
  console.error("Failed:", error.message);
  process.exit(1);
});
