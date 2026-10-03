const db = require("../config/db");
const { SOS_STATUS } = require("../constants/sos");

const SELECT_FIELDS = `
  sa.*,
  p.full_name AS passenger_name,
  p.phone AS passenger_phone,
  du.full_name AS driver_name,
  du.phone AS driver_phone,
  ack.full_name AS acknowledged_by_name,
  res.full_name AS resolved_by_name
`;

const FROM_JOINS = `
  FROM sos_alerts sa
  JOIN users p ON p.id = sa.passenger_id
  LEFT JOIN drivers d ON d.id = sa.driver_id
  LEFT JOIN users du ON du.id = d.user_id
  LEFT JOIN users ack ON ack.id = sa.acknowledged_by
  LEFT JOIN users res ON res.id = sa.resolved_by
`;

async function createAlert({
  passengerId,
  driverId = null,
  bookingId = null,
  lat = null,
  lng = null,
  message = null,
  triggeredByUserId = null,
  triggeredByRole = null,
}) {
  const result = await db.query(
    `
      INSERT INTO sos_alerts
        (booking_id, passenger_id, driver_id, lat, lng, message, status, triggered_by_user_id, triggered_by_role)
      VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?)
    `,
    [bookingId, passengerId, driverId, lat, lng, message, triggeredByUserId, triggeredByRole]
  );
  return findById(result.insertId);
}

async function findById(id, client = db) {
  const rows = await client.query(
    `
      SELECT ${SELECT_FIELDS}
      ${FROM_JOINS}
      WHERE sa.id = ? AND sa.deleted_at IS NULL
      LIMIT 1
    `,
    [id]
  );
  return rows[0] || null;
}

// Open alerts first, then the ones being handled, then the rest, newest
// first within each.
async function listForAdmin(limit = 50) {
  return db.query(
    `
      SELECT ${SELECT_FIELDS}
      ${FROM_JOINS}
      WHERE sa.deleted_at IS NULL
      ORDER BY FIELD(sa.status, 'active', 'acknowledged') = 0, FIELD(sa.status, 'active', 'acknowledged'), sa.created_at DESC
      LIMIT ?
    `,
    [Number(limit)]
  );
}

// "I'm handling this". Changes the row only while it is still open, so when
// two admins press it at the same moment exactly one succeeds. Returns
// whether this admin got it.
async function acknowledge(id, adminUserId) {
  const result = await db.query(
    `
      UPDATE sos_alerts
      SET status = '${SOS_STATUS.ACKNOWLEDGED}', acknowledged_by = ?, acknowledged_at = NOW()
      WHERE id = ? AND status = '${SOS_STATUS.OPEN}' AND deleted_at IS NULL
    `,
    [adminUserId, id]
  );
  return Number(result.affectedRows) === 1;
}

// Resolving needs an acknowledged alert, and happens once.
async function resolve(id, adminUserId, note) {
  const result = await db.query(
    `
      UPDATE sos_alerts
      SET status = '${SOS_STATUS.RESOLVED}', resolved_by = ?, resolved_at = NOW(), resolution_note = ?
      WHERE id = ? AND status = '${SOS_STATUS.ACKNOWLEDGED}' AND deleted_at IS NULL
    `,
    [adminUserId, note, id]
  );
  return Number(result.affectedRows) === 1;
}

// Open alerts older than the escalation time that haven't been escalated.
async function listDueForEscalation(olderThanSeconds) {
  return db.query(
    `
      SELECT id FROM sos_alerts
      WHERE status = '${SOS_STATUS.OPEN}' AND escalated_at IS NULL AND deleted_at IS NULL
        AND created_at <= NOW() - INTERVAL ? SECOND
      ORDER BY created_at ASC
      LIMIT 50
    `,
    [Math.ceil(olderThanSeconds)]
  );
}

// Marks one alert escalated; false if it was acknowledged or escalated in
// the meantime, so each alert is escalated once.
async function claimEscalation(id) {
  const result = await db.query(
    `
      UPDATE sos_alerts SET escalated_at = NOW()
      WHERE id = ? AND status = '${SOS_STATUS.OPEN}' AND escalated_at IS NULL AND deleted_at IS NULL
    `,
    [id]
  );
  return Number(result.affectedRows) === 1;
}

module.exports = {
  createAlert,
  findById,
  listForAdmin,
  acknowledge,
  resolve,
  listDueForEscalation,
  claimEscalation,
};
