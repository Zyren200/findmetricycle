const db = require("../config/db");

async function createApplication(payload, client = db) {
  const result = await client.query(
    `
      INSERT INTO driver_applications (
        user_id,
        driver_id,
        full_name,
        email,
        phone,
        plate_number,
        license_image_url,
        business_permit_image_url,
        license_number,
        license_holder_name,
        license_birth_date,
        license_expires_at,
        ocr_status,
        ocr_failure_reason,
        status,
        submitted_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', NOW())
    `,
    [
      payload.userId,
      payload.driverId || null,
      payload.fullName,
      payload.email || null,
      payload.phone,
      payload.plateNumber,
      payload.licenseImageUrl,
      payload.businessPermitImageUrl,
      payload.licenseNumber || null,
      payload.licenseHolderName || null,
      payload.licenseBirthDate || null,
      payload.licenseExpiresAt || null,
      payload.ocrStatus || "pending",
      payload.ocrFailureReason || null,
    ]
  );

  return findById(result.insertId, client);
}

async function findById(applicationId, client = db) {
  const rows = await client.query(
    `
      SELECT a.*, u.status AS user_status, d.approval_status
      FROM driver_applications a
      JOIN users u ON u.id = a.user_id
      LEFT JOIN drivers d ON d.id = a.driver_id
      WHERE a.id = ?
        AND a.deleted_at IS NULL
        AND u.deleted_at IS NULL
      LIMIT 1
    `,
    [applicationId]
  );
  return rows[0] || null;
}

async function findByDriverId(driverId, client = db) {
  const rows = await client.query(
    `
      SELECT a.*, u.status AS user_status, d.approval_status
      FROM driver_applications a
      JOIN users u ON u.id = a.user_id
      LEFT JOIN drivers d ON d.id = a.driver_id
      WHERE a.driver_id = ?
        AND a.deleted_at IS NULL
        AND u.deleted_at IS NULL
      ORDER BY a.id DESC
      LIMIT 1
    `,
    [driverId]
  );
  return rows[0] || null;
}

const ADMIN_LIST_STATUSES = ["pending", "needs_correction", "rejected", "approved"];

// Applications for the admin list, by status ("all" = every non-archived
// one), with what the reviewer needs to triage them at a glance.
async function listApplicationsForAdmin(status = "pending", client = db) {
  const statuses = ADMIN_LIST_STATUSES.includes(status) ? [status] : ADMIN_LIST_STATUSES;
  return client.query(
    `
      SELECT
        a.id, a.driver_id, a.user_id, a.full_name, a.email, a.phone,
        a.plate_number, a.license_type,
        a.license_image_url, a.business_permit_image_url, a.selfie_image_url,
        a.license_number, a.license_expires_at,
        a.liveness_status,
        a.license_check_status, a.permit_check_status, a.documents_checked_at,
        a.rejection_reason, a.correction_note,
        a.status, a.submitted_at, a.reviewed_at,
        u.status AS user_status
      FROM driver_applications a
      JOIN users u ON u.id = a.user_id
      WHERE a.status IN (${statuses.map(() => "?").join(", ")})
        AND a.deleted_at IS NULL
        AND u.deleted_at IS NULL
      ORDER BY (a.status = 'pending') DESC, a.submitted_at ASC, a.id ASC
    `,
    statuses
  );
}

async function countApplicationsByStatus(client = db) {
  const rows = await client.query(
    `SELECT a.status, COUNT(*) AS n FROM driver_applications a
      JOIN users u ON u.id = a.user_id
      WHERE a.deleted_at IS NULL AND u.deleted_at IS NULL AND a.status <> 'archived'
      GROUP BY a.status`
  );
  const counts = { pending: 0, needs_correction: 0, rejected: 0, approved: 0 };
  for (const row of rows) counts[row.status] = Number(row.n);
  return counts;
}

async function listPendingApplications(client = db) {
  return client.query(
    `
      SELECT
        a.id,
        a.driver_id,
        a.user_id,
        a.full_name,
        a.email,
        a.phone,
        a.plate_number,
        a.license_image_url,
        a.business_permit_image_url,
        a.license_number,
        a.license_holder_name,
        a.license_birth_date,
        a.license_expires_at,
        a.ocr_status,
        a.ocr_failure_reason,
        a.status,
        a.submitted_at,
        u.status AS user_status
      FROM driver_applications a
      JOIN users u ON u.id = a.user_id
      WHERE a.status = 'pending'
        AND a.deleted_at IS NULL
        AND u.deleted_at IS NULL
      ORDER BY a.submitted_at ASC, a.id ASC
    `
  );
}

async function markApproved(applicationId, adminUserId, client = db) {
  await client.query(
    `
      UPDATE driver_applications
      SET status = 'approved',
          reviewed_by = ?,
          reviewed_at = NOW(),
          rejection_reason = NULL
      WHERE id = ?
        AND deleted_at IS NULL
    `,
    [adminUserId, applicationId]
  );

  return findById(applicationId, client);
}

async function markRejected(applicationId, adminUserId, reason, client = db) {
  await client.query(
    `
      UPDATE driver_applications
      SET status = 'rejected',
          reviewed_by = ?,
          reviewed_at = NOW(),
          rejection_reason = ?
      WHERE id = ?
        AND deleted_at IS NULL
    `,
    [adminUserId, reason || null, applicationId]
  );

  return findById(applicationId, client);
}

async function markNeedsCorrection(applicationId, adminUserId, note, client = db) {
  await client.query(
    `
      UPDATE driver_applications
      SET status = 'needs_correction',
          reviewed_by = ?,
          reviewed_at = NOW(),
          correction_note = ?
      WHERE id = ?
        AND deleted_at IS NULL
    `,
    [adminUserId, note || null, applicationId]
  );

  return findById(applicationId, client);
}

async function listRecent(limit = 5, client = db) {
  return client.query(
    `
      SELECT a.id, a.driver_id, a.full_name, a.status, a.submitted_at
      FROM driver_applications a
      WHERE a.deleted_at IS NULL
      ORDER BY a.submitted_at DESC, a.id DESC
      LIMIT ?
    `,
    [limit]
  );
}

module.exports = {
  createApplication,
  findById,
  findByDriverId,
  listPendingApplications,
  listApplicationsForAdmin,
  countApplicationsByStatus,
  markApproved,
  markRejected,
  markNeedsCorrection,
  listRecent,
};
