const db = require("../config/db");

const SELECT_FIELDS = `
  sa.*,
  p.full_name AS passenger_name,
  p.phone AS passenger_phone,
  du.full_name AS driver_name,
  du.phone AS driver_phone
`;

async function createAlert({ passengerId, driverId = null, bookingId = null, lat = null, lng = null, message = null }) {
  const result = await db.query(
    `
      INSERT INTO sos_alerts (booking_id, passenger_id, driver_id, lat, lng, message, status)
      VALUES (?, ?, ?, ?, ?, ?, 'active')
    `,
    [bookingId, passengerId, driverId, lat, lng, message]
  );
  return findById(result.insertId);
}

async function findById(id, client = db) {
  const rows = await client.query(
    `
      SELECT ${SELECT_FIELDS}
      FROM sos_alerts sa
      JOIN users p ON p.id = sa.passenger_id
      LEFT JOIN drivers d ON d.id = sa.driver_id
      LEFT JOIN users du ON du.id = d.user_id
      WHERE sa.id = ? AND sa.deleted_at IS NULL
      LIMIT 1
    `,
    [id]
  );
  return rows[0] || null;
}

async function listForAdmin(limit = 25) {
  return db.query(
    `
      SELECT ${SELECT_FIELDS}
      FROM sos_alerts sa
      JOIN users p ON p.id = sa.passenger_id
      LEFT JOIN drivers d ON d.id = sa.driver_id
      LEFT JOIN users du ON du.id = d.user_id
      WHERE sa.deleted_at IS NULL
      ORDER BY (sa.status = 'active') DESC, sa.created_at DESC
      LIMIT ?
    `,
    [Number(limit)]
  );
}

async function resolveAlert(id, adminUserId) {
  await db.query(
    `
      UPDATE sos_alerts
      SET status = 'resolved', resolved_by = ?, resolved_at = NOW()
      WHERE id = ? AND deleted_at IS NULL
    `,
    [adminUserId || null, id]
  );
  return findById(id);
}

module.exports = {
  createAlert,
  findById,
  listForAdmin,
  resolveAlert,
};
