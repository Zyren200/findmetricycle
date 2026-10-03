const db = require("../config/db");

const SELECT_FIELDS = `
  c.*,
  reporter.full_name AS reporter_name,
  reporter.phone AS reporter_phone,
  reported.full_name AS reported_user_name,
  resolver.full_name AS resolved_by_name
`;

async function createComplaint({
  reporterId,
  reportedUserId = null,
  bookingId = null,
  category,
  description,
}) {
  const result = await db.query(
    `
      INSERT INTO complaints (reporter_id, reported_user_id, booking_id, category, description, status)
      VALUES (?, ?, ?, ?, ?, 'open')
    `,
    [reporterId, reportedUserId, bookingId, category, description]
  );
  return findById(result.insertId);
}

async function findById(id, client = db) {
  const rows = await client.query(
    `
      SELECT ${SELECT_FIELDS}
      FROM complaints c
      JOIN users reporter ON reporter.id = c.reporter_id
      LEFT JOIN users reported ON reported.id = c.reported_user_id
      LEFT JOIN users resolver ON resolver.id = c.resolved_by
      WHERE c.id = ? AND c.deleted_at IS NULL
      LIMIT 1
    `,
    [id]
  );
  return rows[0] || null;
}

async function listForAdmin({ status, limit = 50, offset = 0 } = {}, client = db) {
  const conditions = ["c.deleted_at IS NULL"];
  const params = [];

  if (status) {
    conditions.push("c.status = ?");
    params.push(status);
  }

  params.push(Number(limit), Number(offset));

  return client.query(
    `
      SELECT ${SELECT_FIELDS}
      FROM complaints c
      JOIN users reporter ON reporter.id = c.reporter_id
      LEFT JOIN users reported ON reported.id = c.reported_user_id
      LEFT JOIN users resolver ON resolver.id = c.resolved_by
      WHERE ${conditions.join(" AND ")}
      ORDER BY (c.status = 'open') DESC, c.created_at DESC
      LIMIT ? OFFSET ?
    `,
    params
  );
}

async function resolveComplaint(id, adminUserId, { status = "resolved", resolutionNote = null } = {}, client = db) {
  await client.query(
    `
      UPDATE complaints
      SET status = ?, resolution_note = ?, resolved_by = ?, resolved_at = NOW()
      WHERE id = ? AND deleted_at IS NULL
    `,
    [status, resolutionNote, adminUserId, id]
  );
  return findById(id, client);
}

module.exports = {
  createComplaint,
  findById,
  listForAdmin,
  resolveComplaint,
};
