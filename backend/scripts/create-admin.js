const bcrypt = require("bcryptjs");
const db = require("../src/config/db");
const { ADMIN_ROLES, isAdminRole } = require("../src/constants/admin-permissions");

async function run() {
  // Server-side recovery tool (e.g. locked out of every Super Admin), so
  // the role defaults to super_admin. Normally admins are added from the
  // dashboard's Admin Accounts page.
  const [, , fullName, phone, email, password, role = ADMIN_ROLES.SUPER_ADMIN] = process.argv;

  if (!fullName || !phone || !password) {
    console.log(
      "Usage: node scripts/create-admin.js \"Full Name\" \"09XXXXXXXXX\" \"email@domain\" \"Password123\" [super_admin|operations_admin|sos_responder]"
    );
    process.exit(1);
  }

  if (!isAdminRole(role)) {
    console.log(`Unknown role "${role}". Use one of: ${Object.values(ADMIN_ROLES).join(", ")}`);
    process.exit(1);
  }

  const passwordHash = await bcrypt.hash(password, 12);

  const result = await db.query(
    `
      INSERT INTO users (full_name, phone, email, password_hash, role, status)
      VALUES (?, ?, ?, ?, 'admin', 'active')
    `,
    [fullName, phone, email || null, passwordHash]
  );

  await db.query(
    "INSERT INTO admins (user_id, admin_role, status, password_set_at) VALUES (?, ?, 'active', NOW())",
    [result.insertId, role]
  );

  console.log(`Admin created with user_id=${result.insertId} (${role})`);
  process.exit(0);
}

run().catch((error) => {
  console.error("Failed to create admin:", error.message);
  process.exit(1);
});

