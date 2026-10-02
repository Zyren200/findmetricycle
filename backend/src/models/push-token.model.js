const db = require("../config/db");

// A device token belongs to whoever last logged in on that device.
async function saveToken(userId, token, platform) {
  await db.query(
    `INSERT INTO push_tokens (user_id, token, platform) VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), platform = VALUES(platform), updated_at = NOW()`,
    [userId, token, platform]
  );
}

async function removeTokens(tokens) {
  if (!tokens.length) return;
  await db.query(`DELETE FROM push_tokens WHERE token IN (${tokens.map(() => "?").join(", ")})`, tokens);
}

async function listTokensForUser(userId) {
  const rows = await db.query(
    `SELECT pt.token FROM push_tokens pt
     JOIN users u ON u.id = pt.user_id
     WHERE pt.user_id = ? AND u.deleted_at IS NULL AND u.status = 'active'`,
    [userId]
  );
  return rows.map((row) => row.token);
}

// Announcement audiences: everyone, passengers (every app user who books
// rides), or drivers (legacy driver accounts and approved dual-role ones).
async function listTokensForAudience(audience) {
  const audienceFilter = {
    everyone: "1 = 1",
    passenger: "u.role = 'passenger'",
    driver: "(u.role = 'driver' OR (u.is_driver_account = 1 AND u.driver_approval_status = 'approved'))",
  }[audience];
  if (!audienceFilter) return [];
  const rows = await db.query(
    `SELECT pt.token FROM push_tokens pt
     JOIN users u ON u.id = pt.user_id
     WHERE u.deleted_at IS NULL AND u.status = 'active' AND ${audienceFilter}`
  );
  return rows.map((row) => row.token);
}

module.exports = {
  saveToken,
  removeTokens,
  listTokensForUser,
  listTokensForAudience,
};
