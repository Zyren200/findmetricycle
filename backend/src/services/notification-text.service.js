// Notifications copy the pickup address into their text at creation time.
// When that address was still raw coordinates ("from 11.10853, 125.38810")
// and the place name is found later, swap it into the stored text too.
const db = require("../config/db");

const COORDINATES_IN_TEXT = /(-?\d{1,3}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})/g;
const SAME_POINT = 0.0002; // ~20 m

function nearly(a, b) {
  return Math.abs(Number(a) - Number(b)) <= SAME_POINT;
}

/**
 * Replaces coordinate pairs in `text` that match one of `places`
 * ([{ lat, lng, name }]) with that place's name. Unknown pairs stay as-is.
 */
function replaceCoordinates(text, places) {
  return String(text).replace(COORDINATES_IN_TEXT, (match, lat, lng) => {
    const place = places.find((p) => p.name && nearly(p.lat, lat) && nearly(p.lng, lng));
    return place ? place.name : match;
  });
}

/** Rewrites the title/body of every notification about `bookingId`. */
async function refreshBookingNotificationText(bookingId, places) {
  const rows = await db.query(
    `SELECT id, title, body FROM notifications
      WHERE deleted_at IS NULL
        AND JSON_EXTRACT(metadata_json, '$.bookingId') = ?`,
    [Number(bookingId)]
  );
  let updated = 0;
  for (const row of rows) {
    const title = replaceCoordinates(row.title, places);
    const body = replaceCoordinates(row.body, places);
    if (title !== row.title || body !== row.body) {
      await db.query("UPDATE notifications SET title = ?, body = ? WHERE id = ?", [title, body, row.id]);
      updated += 1;
    }
  }
  return updated;
}

module.exports = { replaceCoordinates, refreshBookingNotificationText };
