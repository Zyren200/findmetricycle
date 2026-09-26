const db = require("../config/db");

async function logStatus(applicationId, status, note, changedBy, client = db) {
  await client.query(
    `INSERT INTO application_status_history (application_id, status, note, changed_by) VALUES (?, ?, ?, ?)`,
    [applicationId, status, note || null, changedBy || null]
  );
}

async function listForApplication(applicationId, client = db) {
  return client.query(
    `
      SELECT h.*, u.full_name AS changed_by_name
      FROM application_status_history h
      LEFT JOIN users u ON u.id = h.changed_by
      WHERE h.application_id = ?
      ORDER BY h.created_at ASC, h.id ASC
    `,
    [applicationId]
  );
}

module.exports = { logStatus, listForApplication };
