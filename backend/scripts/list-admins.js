const db = require('../src/config/db');

async function run() {
  const results = await db.query(`
    SELECT u.id, u.full_name, u.phone, u.email, u.status, a.admin_role, a.status AS admin_status, a.last_login_at, u.created_at
    FROM users u
    LEFT JOIN admins a ON a.user_id = u.id
    WHERE u.role = 'admin'
    ORDER BY u.id DESC
  `);
  if (!results || results.length === 0) {
    console.log('No admin users found.');
    process.exit(0);
  }

  console.table(results.map(r => ({
    id: r.id,
    full_name: r.full_name,
    phone: r.phone,
    email: r.email,
    role: r.admin_role,
    admin_status: r.admin_status,
    user_status: r.status,
    last_login_at: r.last_login_at,
    created_at: r.created_at,
  })));
  process.exit(0);
}

run().catch((err) => {
  console.error('Failed to list admins:', err && err.message ? err.message : err);
  process.exit(1);
});
