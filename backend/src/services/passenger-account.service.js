const bcrypt = require("bcryptjs");
const db = require("../config/db");
const userModel = require("../models/user.model");
const refreshTokenModel = require("../models/refresh-token.model");
const ApiError = require("../utils/api-error");

// A ride in any of these still needs both people, so the account can't go.
const ACTIVE_RIDE_STATUSES = ["pending", "searching", "accepted", "assigned", "arriving", "ongoing", "on_ride"];

// Email and phone are unique per account. Checked up front so the user gets
// a clear message instead of the database's duplicate-key error ("Internal
// server error"). A cleared email is stored as NULL — an empty string is a
// value too, so a second user clearing theirs used to collide with the first.
async function updateProfile(userId, payload) {
  const changes = { ...payload };

  if (Object.prototype.hasOwnProperty.call(changes, "email")) {
    const email = String(changes.email || "").trim();
    changes.email = email || null;
    if (email) {
      const owner = await userModel.findByEmail(email);
      if (owner && Number(owner.id) !== Number(userId)) {
        throw new ApiError(409, "This email is already used by another account.", { field: "email" });
      }
    }
  }

  if (Object.prototype.hasOwnProperty.call(changes, "phone")) {
    changes.phone = String(changes.phone).trim();
    const owner = await userModel.findByPhone(changes.phone);
    if (owner && Number(owner.id) !== Number(userId)) {
      throw new ApiError(409, "This mobile number is already used by another account.", { field: "phone" });
    }
  }

  return userModel.updateProfile(userId, changes);
}

async function findActiveRide(userId) {
  const statuses = ACTIVE_RIDE_STATUSES.map(() => "?").join(", ");
  const [ride] = await db.query(
    `SELECT b.id FROM bookings b
     LEFT JOIN drivers d ON d.id = b.driver_id
     WHERE (b.passenger_id = ? OR d.user_id = ?)
       AND b.status IN (${statuses})
       AND b.deleted_at IS NULL
     LIMIT 1`,
    [userId, userId, ...ACTIVE_RIDE_STATUSES]
  );
  return ride || null;
}

// Refused mid-ride (as a passenger or as a driver) — the other side would be
// left waiting on an account that no longer exists. Signs every device out.
async function deleteAccount(userId, password) {
  const user = await userModel.findById(userId);
  if (!user) {
    throw new ApiError(404, "Account not found.");
  }

  const valid = await bcrypt.compare(password, user.password_hash);
  if (!valid) {
    throw new ApiError(400, "Password is incorrect.");
  }

  const activeRide = await findActiveRide(userId);
  if (activeRide) {
    throw new ApiError(
      409,
      `You have a ride in progress (#${activeRide.id}). Finish or cancel it before deleting your account.`
    );
  }

  await db.withTransaction(async (client) => {
    await userModel.archiveUser(userId, client);
    await client.query("UPDATE drivers SET is_online = 0 WHERE user_id = ?", [userId]);
    await client.query("DELETE FROM push_tokens WHERE user_id = ?", [userId]);
    await refreshTokenModel.revokeAllByUserId(userId, client);
  });
}

module.exports = {
  updateProfile,
  deleteAccount,
};
