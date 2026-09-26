const db = require('../src/config/db');

async function run() {
  const results = await db.query(`SELECT id, full_name, phone, email, role, status, created_at FROM users WHERE role = 'admin' ORDER BY id DESC`);
  if (!results || results.length === 0) {
    console.log('No admin users found.');
    process.exit(0);
  }

  console.table(results.map(r => ({ id: r.id, full_name: r.full_name, phone: r.phone, email: r.email, status: r.status, created_at: r.created_at })));
  process.exit(0);
}

run().catch((err) => {
  console.error('Failed to list admins:', err && err.message ? err.message : err);
  process.exit(1);
});
