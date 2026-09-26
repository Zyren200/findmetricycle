# FindMeTricycle Backend

Node.js + Express API for Passenger, Driver, and Admin with:

- JWT access + refresh token flow
- Role-based authorization
- MySQL models and services (MVC style)
- Socket.io real-time booking/tracking
- Multer uploads for driver documents
- Zod request validation

## Folder Structure

```text
backend
|- .env.example
|- package.json
|- Dockerfile
|- sql/schema.sql
|- scripts/create-admin.js
|- tests
|  |- setup-env.js
|  |- health.test.js
|  `- auth-validation.test.js
`- src
   |- app.js
   |- server.js
   |- config
   |- constants
   |- controllers
   |- middlewares
   |- models
   |- routes
   |- services
   |- sockets
   |- utils
   `- validations
```

## Setup

1. Copy `.env.example` to `.env`.
2. Import `sql/schema.sql` in MySQL.
3. Install:
   - `npm install`
4. Start dev server:
   - `npm run dev`
5. Check:
   - `GET /api/health`

`CLIENT_ORIGIN` supports comma-separated origins.

## Seed Admin

Use helper script:

```bash
npm run create-admin -- "System Admin" "09990000000" "admin@findme.local" "Admin@123"
```

## API Endpoints

### Auth

- `POST /api/auth/passenger/register`
- `POST /api/auth/driver/register` (multipart: `licenseImage`, `businessPermitImage`)
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`
- `POST /api/auth/logout-all` (auth required)
- `GET /api/auth/me`

### Passenger

- `POST /api/passenger/bookings/find-ride`
- `GET /api/passenger/bookings/:bookingId`
- `POST /api/passenger/bookings/:bookingId/cancel`
- `POST /api/passenger/bookings/:bookingId/rate`

### Driver

- `PATCH /api/driver/status`
- `PATCH /api/driver/location`
- `POST /api/driver/bookings/:bookingId/respond`
- `POST /api/driver/bookings/:bookingId/start`
- `POST /api/driver/bookings/:bookingId/complete`
- `GET /api/driver/earnings`
- `GET /api/driver/ratings`

### Admin

- `GET /api/admin/drivers/pending`
- `POST /api/admin/drivers/:driverId/approve`
- `POST /api/admin/drivers/:driverId/reject`
- `GET /api/admin/fare`
- `PUT /api/admin/fare`
- `GET /api/admin/live-map`
- `GET /api/admin/dashboard`

## Socket Events

Clients connect with access token:

```js
io("http://localhost:5000", { auth: { token: accessToken } });
```

Driver events:

- emit `driver:set_online`
- emit `driver:location_update`
- on `driver:booking_request`
- emit `driver:booking_response`
- on `driver:approval_status`

Passenger events:

- emit `passenger:find_ride`
- on `passenger:booking_update`
- on `passenger:driver_location`
- on `passenger:ride_started`
- on `passenger:ride_completed`

Admin events:

- on `admin:driver_location`

## Security Defaults

- Access/refresh token rotation with token revocation table
- Password hashing (`bcryptjs`)
- Rate limiting for auth routes
- Input validation (`zod`)
- SQL parameterization (`mysql2`)
- `helmet`, CORS allowlist
- Upload MIME + size limits

## Tests

Run API tests:

```bash
npm test
```

## Docker

Build/run via root `docker-compose.yml`:

```bash
docker compose up --build
```

## Migrations

The backend includes an idempotent migration runner for Admin Dashboard V2 database changes.

Apply migrations (from project root):

```bash
# using the Node runner (preferred if you have the app env set in .env)
node backend/scripts/run-migrations.js

# or use the MySQL CLI directly for one migration at a time (replace with your DB creds)
mysql -u your_user -p your_database < backend/sql/migrations/003_admin_v2_operations_schema.sql
```

The migrations are designed to be safe to rerun. Legacy cashless tables are archived with `legacy_cashless_*` names instead of being dropped, so old records are preserved while the active app stays cash-only.

