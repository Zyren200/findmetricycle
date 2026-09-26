#!/usr/bin/env node
// Replaces raw coordinates in existing notification text with the place
// names now stored on their bookings (run fill-booking-addresses.js first).
//   node scripts/fix-notification-text.js
const db = require("../src/config/db");
const { isCoordinateAddress } = require("../src/services/geocoding.service");
const { refreshBookingNotificationText } = require("../src/services/notification-text.service");

async function main() {
  const bookings = await db.query(
    `SELECT DISTINCT b.id, b.pickup_address, b.pickup_lat, b.pickup_lng,
            b.dropoff_address, b.dropoff_lat, b.dropoff_lng
       FROM bookings b
       JOIN notifications n ON JSON_EXTRACT(n.metadata_json, '$.bookingId') = b.id
      WHERE n.deleted_at IS NULL`
  );
  let total = 0;
  for (const b of bookings) {
    const places = [
      { lat: b.pickup_lat, lng: b.pickup_lng, name: isCoordinateAddress(b.pickup_address) ? null : b.pickup_address },
      { lat: b.dropoff_lat, lng: b.dropoff_lng, name: isCoordinateAddress(b.dropoff_address) ? null : b.dropoff_address },
    ];
    const updated = await refreshBookingNotificationText(b.id, places);
    if (updated) console.log(`Booking #${b.id}: ${updated} notification(s) updated`);
    total += updated;
  }
  console.log(`Done: ${total} notification(s) updated.`);
  process.exit(0);
}

main().catch((error) => {
  console.error("Failed:", error.message);
  process.exit(1);
});
