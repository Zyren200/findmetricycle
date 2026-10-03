const db = require("../config/db");

const ADMIN_FIELDS = `
  a.user_id,
  a.admin_role,
  a.status,
  a.created_by,
  a.last_login_at,
  a.password_set_at,
  a.created_at,
  u.full_name,
  u.email,
  u.phone
`;

// `forUpdate` locks the row until the surrounding transaction ends.
async function findByUserId(userId, client = db, { forUpdate = false } = {}) {
  const rows = await client.query(
    `SELECT ${ADMIN_FIELDS}
     FROM admins a
     JOIN users u ON u.id = a.user_id
     WHERE a.user_id = ? AND a.deleted_at IS NULL AND u.deleted_at IS NULL
     LIMIT 1${forUpdate ? " FOR UPDATE" : ""}`,
    [userId]
  );
  return rows[0] || null;
}

async function listAll(client = db) {
  return client.query(
    `SELECT ${ADMIN_FIELDS}, creator.full_name AS created_by_name
     FROM admins a
     JOIN users u ON u.id = a.user_id
     LEFT JOIN users creator ON creator.id = a.created_by
     WHERE a.deleted_at IS NULL AND u.deleted_at IS NULL
     ORDER BY a.created_at ASC, a.user_id ASC`
  );
}

// The active Super Admins, locked for the rest of the transaction: two
// Super Admins demoting or disabling each other at the same moment are
// handled one after the other, so the last one can never be removed.
async function lockActiveSuperAdmins(client) {
  return client.query(
    `SELECT a.user_id
     FROM admins a
     JOIN users u ON u.id = a.user_id
     WHERE a.admin_role = 'super_admin' AND a.status = 'active'
       AND a.deleted_at IS NULL AND u.deleted_at IS NULL
     FOR UPDATE`
  );
}

async function updateRole(userId, role, client = db) {
  await client.query("UPDATE admins SET admin_role = ? WHERE user_id = ?", [role, userId]);
}

async function updateStatus(userId, status, client = db) {
  await client.query("UPDATE admins SET status = ? WHERE user_id = ?", [status, userId]);
}

async function findByEmail(email, client = db) {
  const rows = await client.query(
    `SELECT ${ADMIN_FIELDS}
     FROM admins a
     JOIN users u ON u.id = a.user_id
     WHERE u.email = ? AND u.role = 'admin' AND a.deleted_at IS NULL AND u.deleted_at IS NULL
     LIMIT 1`,
    [email]
  );
  return rows[0] || null;
}

async function createProfile(userId, { role, createdBy = null, passwordSet = false }, client = db) {
  await client.query(
    `INSERT INTO admins (user_id, admin_role, status, created_by, password_set_at)
     VALUES (?, ?, 'active', ?, ${passwordSet ? "NOW()" : "NULL"})`,
    [userId, role, createdBy]
  );
  return findByUserId(userId, client);
}

async function touchLastLogin(userId) {
  await db.query("UPDATE admins SET last_login_at = NOW() WHERE user_id = ?", [userId]);
}

async function markPasswordSet(userId, client = db) {
  await client.query("UPDATE admins SET password_set_at = NOW() WHERE user_id = ?", [userId]);
}

module.exports = {
  findByUserId,
  findByEmail,
  listAll,
  lockActiveSuperAdmins,
  createProfile,
  updateRole,
  updateStatus,
  touchLastLogin,
  markPasswordSet,
};
