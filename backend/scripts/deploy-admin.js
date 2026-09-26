const path = require('path');
const fs = require('fs/promises');

async function run() {
  const src = path.resolve(process.cwd(), '..', 'admin_dashboard', 'dist');
  const dest = path.resolve(process.cwd(), 'public', 'admin');

  // ensure src exists
  try {
    await fs.access(src);
  } catch (err) {
    console.error('Admin dashboard build not found. Run `npm run build` in admin_dashboard first.');
    process.exit(1);
  }

  // remove existing dest
  await fs.rm(dest, { recursive: true, force: true });
  // copy recursively
  await fs.cp(src, dest, { recursive: true });
  console.log('Admin UI deployed to backend/public/admin');
  console.log('Serve at: http://localhost:5000/admin/index.html');
}

run().catch((err) => {
  console.error('Failed to deploy admin UI:', err && err.message ? err.message : err);
  process.exit(1);
});
