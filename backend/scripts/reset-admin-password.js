const bcrypt = require('bcryptjs');
const db = require('../src/config/db');

async function run() {
  const [, , email, password] = process.argv;
  if (!email || !password) {
    console.log('Usage: node scripts/reset-admin-password.js "email" "NewPassword123"');
    process.exit(1);
  }

  const hash = await bcrypt.hash(password, 12);
  const res = await db.query('UPDATE users SET password_hash = ? WHERE email = ? AND role = "admin"', [hash, email]);
  if (res.affectedRows && res.affectedRows > 0) {
    console.log(`Password updated for admin ${email}`);
    process.exit(0);
  }

  console.error('No admin user found with that email');
  process.exit(1);
}

run().catch(err => {
  console.error('Failed to reset admin password:', err && err.message ? err.message : err);
  process.exit(1);
});
