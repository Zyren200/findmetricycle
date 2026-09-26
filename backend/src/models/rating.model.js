const db = require("../config/db");

async function createRating(payload) {
  const result = await db.query(
    `
      INSERT INTO ratings (booking_id, passenger_id, driver_id, stars, feedback)
      VALUES (?, ?, ?, ?, ?)
    `,
    [
      payload.bookingId,
      payload.passengerId,
      payload.driverId,
      payload.stars,
      payload.feedback || null,
    ]
  );

  const rows = await db.query("SELECT * FROM ratings WHERE id = ? AND deleted_at IS NULL LIMIT 1", [result.insertId]);
  return rows[0] || null;
}

async function listRatingsByDriver(driverId, limit = 100) {
  return db.query(
    `
      SELECT r.*, u.full_name AS passenger_name
      FROM ratings r
      JOIN users u ON u.id = r.passenger_id
      WHERE r.driver_id = ?
        AND r.deleted_at IS NULL
        AND u.deleted_at IS NULL
      ORDER BY r.id DESC
      LIMIT ?
    `,
    [driverId, limit]
  );
}

module.exports = {
  createRating,
  listRatingsByDriver,
};
