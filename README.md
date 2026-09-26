# FindMeTricycle Monorepo

This workspace now contains:

- `backend` -> Node.js + Express + MySQL + Socket.io API
- `mobile_app` -> Flutter passenger/driver application source
- `admin_dashboard` -> React + Vite web admin panel
- `IMPLEMENTATION_GUIDE.md` -> full step-by-step setup and testing flow
- `.github/workflows/ci.yml` -> CI checks for backend, admin dashboard, and Flutter app

## Recommended Start Order

1. Start backend first.
2. Start admin dashboard and log in as admin.
3. Run Flutter app for passenger/driver flows.

## Backend Quick Start

1. Import `backend/sql/schema.sql` in MySQL.
2. Configure `backend/.env` from `backend/.env.example`.
3. Run:
   - `cd backend`
   - `npm install`
   - `npm run dev`

## Admin Dashboard Quick Start

1. Configure `admin_dashboard/.env` from `admin_dashboard/.env.example`.
2. Run:
   - `cd admin_dashboard`
   - `npm install`
   - `npm run dev`

## Flutter App Quick Start

1. Open `mobile_app`.
2. If native folders are missing, run:
   - `flutter create .`
3. Run:
   - `flutter pub get`
   - `flutter run`

## CI

GitHub Actions runs on push/pull request and includes:

- Backend tests (`npm test`)
- Admin dashboard production build (`npm run build`)
- Flutter static analysis + tests (`flutter analyze`, `flutter test`)
