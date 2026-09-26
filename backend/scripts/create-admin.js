const bcrypt = require("bcryptjs");
const db = require("../src/config/db");

async function run() {
  const [, , fullName, phone, email, password] = process.argv;

  if (!fullName || !phone || !password) {
    // eslint-disable-next-line no-console
    console.log("Usage: node scripts/create-admin.js \"Full Name\" \"09XXXXXXXXX\" \"email@domain\" \"Password123\"");
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

  await db.query("INSERT INTO admins (user_id) VALUES (?)", [result.insertId]);

  // eslint-disable-next-line no-console
  console.log(`Admin created with user_id=${result.insertId}`);
  process.exit(0);
}

run().catch((error) => {
  // eslint-disable-next-line no-console
  console.error("Failed to create admin:", error.message);
  process.exit(1);
});

