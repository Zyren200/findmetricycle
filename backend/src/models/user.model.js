const db = require("../config/db");

async function createUser(payload, client = db) {
  const result = await client.query(
    `
      INSERT INTO users (full_name, phone, email, password_hash, role, status)
      VALUES (?, ?, ?, ?, ?, ?)
    `,
    [
      payload.fullName,
      payload.phone,
      payload.email || null,
      payload.passwordHash,
      payload.role,
      payload.status || "active",
    ]
  );

  return findById(result.insertId, client);
}

async function createAdminProfile(userId, client = db) {
  await client.query("INSERT INTO admins (user_id) VALUES (?)", [userId]);
  return { user_id: userId };
}

async function findByPhone(phone, client = db) {
  const rows = await client.query("SELECT * FROM users WHERE phone = ? AND deleted_at IS NULL LIMIT 1", [phone]);
  return rows[0] || null;
}

async function findByEmail(email, client = db) {
  const rows = await client.query("SELECT * FROM users WHERE email = ? AND deleted_at IS NULL LIMIT 1", [email]);
  return rows[0] || null;
}

async function findById(id, client = db) {
  const rows = await client.query("SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1", [id]);
  return rows[0] || null;
}

async function updateStatus(userId, status) {
  await db.query("UPDATE users SET status = ? WHERE id = ?", [status, userId]);
}

async function updatePasswordHash(userId, passwordHash, client = db) {
  await client.query("UPDATE users SET password_hash = ? WHERE id = ?", [passwordHash, userId]);
}

async function archiveUser(userId) {
  await db.query("UPDATE users SET status = 'archived', deleted_at = NOW() WHERE id = ?", [userId]);
  return { id: userId, status: "archived" };
}

async function updateProfile(userId, payload) {
  const fields = [];
  const values = [];

  if (Object.prototype.hasOwnProperty.call(payload, "fullName")) {
    fields.push("full_name = ?");
    values.push(payload.fullName);
  }

  if (Object.prototype.hasOwnProperty.call(payload, "phone")) {
    fields.push("phone = ?");
    values.push(payload.phone);
  }

  if (Object.prototype.hasOwnProperty.call(payload, "email")) {
    fields.push("email = ?");
    values.push(payload.email);
  }

  if (Object.prototype.hasOwnProperty.call(payload, "profileImageUrl")) {
    fields.push("profile_image_url = ?");
    values.push(payload.profileImageUrl);
  }

  if (Object.prototype.hasOwnProperty.call(payload, "address")) {
    fields.push("address = ?");
    values.push(payload.address);
  }

  if (fields.length === 0) {
    return findById(userId);
  }

  values.push(userId);
  await db.query(`UPDATE users SET ${fields.join(", ")} WHERE id = ?`, values);
  return findById(userId);
}

async function listPassengersForAdmin() {
  return db.query(
    `
      SELECT
        u.id,
        u.full_name,
        u.phone,
        u.email,
        u.status,
        u.profile_image_url,
        u.created_at,
        u.is_driver_account,
        u.driver_approval_status,
        -- Counted in a subquery: joining bookings and ratings directly
        -- multiplied the rows, and "total rides" included cancellations.
        COALESCE(bs.completed_rides, 0) AS completed_rides,
        COALESCE(bs.cancelled_rides, 0) AS cancelled_rides,
        COALESCE(bs.total_bookings, 0) AS total_bookings,
        COALESCE(bs.total_spent, 0) AS total_spent,
        bs.last_booking_at
      FROM users u
      LEFT JOIN (
        SELECT passenger_id,
               SUM(status = 'completed') AS completed_rides,
               SUM(status = 'cancelled') AS cancelled_rides,
               COUNT(*) AS total_bookings,
               SUM(CASE WHEN status = 'completed' THEN final_fare ELSE 0 END) AS total_spent,
               MAX(requested_at) AS last_booking_at
          FROM bookings
         WHERE deleted_at IS NULL
         GROUP BY passenger_id
      ) bs ON bs.passenger_id = u.id
      WHERE u.role = 'passenger'
        AND u.deleted_at IS NULL
      ORDER BY u.created_at DESC
    `
  );
}

async function suspendUser(userId, client = db) {
  await client.query(
    "UPDATE users SET status = 'suspended' WHERE id = ? AND role = 'passenger'",
    [userId]
  );
  return findById(userId, client);
}

async function reinstateUser(userId, client = db) {
  await client.query(
    "UPDATE users SET status = 'active' WHERE id = ? AND role = 'passenger'",
    [userId]
  );
  return findById(userId, client);
}

module.exports = {
  createUser,
  createAdminProfile,
  findByPhone,
  findByEmail,
  findById,
  updateStatus,
  updatePasswordHash,
  archiveUser,
  updateProfile,
  listPassengersForAdmin,
  suspendUser,
  reinstateUser,
};
