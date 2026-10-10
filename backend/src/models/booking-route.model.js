const db = require("../config/db");

async function findLatestForBooking(bookingId) {
  const rows = await db.query(
    `SELECT id, lat, lng, recorded_at
     FROM booking_route_points
     WHERE booking_id = ?
     ORDER BY recorded_at DESC, id DESC
     LIMIT 1`,
    [bookingId]
  );
  return rows[0] || null;
}

async function create({ bookingId, lat, lng }) {
  const result = await db.query(
    `INSERT INTO booking_route_points (booking_id, lat, lng)
     VALUES (?, ?, ?)`,
    [bookingId, lat, lng]
  );
  return result.insertId;
}

async function listForBooking(bookingId) {
  return db.query(
    `SELECT lat, lng, recorded_at
     FROM booking_route_points
     WHERE booking_id = ?
     ORDER BY recorded_at ASC, id ASC`,
    [bookingId]
  );
}

module.exports = {
  findLatestForBooking,
  create,
  listForBooking,
};
