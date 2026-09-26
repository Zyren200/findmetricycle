const db = require("../config/db");

async function createToken(payload, client = db) {
  await client.query(
    `
      INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
      VALUES (?, ?, ?)
    `,
    [payload.userId, payload.tokenHash, payload.expiresAt]
  );
}

async function findActiveTokenByHash(tokenHash, client = db) {
  const rows = await client.query(
    `
      SELECT *
      FROM refresh_tokens
      WHERE token_hash = ?
        AND revoked_at IS NULL
        AND expires_at > NOW()
      LIMIT 1
    `,
    [tokenHash]
  );
  return rows[0] || null;
}

async function revokeTokenByHash(tokenHash, client = db) {
  await client.query(
    `
      UPDATE refresh_tokens
      SET revoked_at = NOW()
      WHERE token_hash = ?
        AND revoked_at IS NULL
    `,
    [tokenHash]
  );
}

async function revokeAllByUserId(userId, client = db) {
  await client.query(
    `
      UPDATE refresh_tokens
      SET revoked_at = NOW()
      WHERE user_id = ?
        AND revoked_at IS NULL
    `,
    [userId]
  );
}

module.exports = {
  createToken,
  findActiveTokenByHash,
  revokeTokenByHash,
  revokeAllByUserId,
};
