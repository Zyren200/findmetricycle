# Admin Seed (Development)

This file documents a development admin user seeded in the local database for convenience.

Credentials (development only):

- Email: `admin@findme.local`
- Password: `Admin1234!`

Notes:
- These credentials are intended for local development only. Do NOT use them in production.
- To change the password or create additional admin users, use the scripts in `backend/scripts/`:
  - Create a new admin: `node scripts/create-admin.js "Full Name" "09XXXXXXXXX" "email@domain" "Password123"`
  - Reset an admin password: `node scripts/reset-admin-password.js "email" "NewPassword123"`
  - List admins: `node scripts/list-admins.js`

Deployment:
- To serve the admin UI from the backend, build the frontend and deploy into the backend public folder:
  - `cd admin_dashboard && npm run build`
  - `cd backend && node scripts/deploy-admin.js`
  - Admin UI will be available at: `http://localhost:5000/admin/index.html`
