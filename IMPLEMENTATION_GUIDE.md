# FindMeTricycle Step-by-Step Implementation Guide

This guide covers backend, admin dashboard, and Flutter app setup.

## 1. Prepare Environment

1. Install:
   - Node.js 18+
   - MySQL 8+
   - Flutter SDK 3.22+
2. Enable Google Maps APIs in Google Cloud:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Maps JavaScript API
   - Directions API (optional, for advanced routing)

## 2. Backend Setup

1. Go to `backend`.
2. Copy `.env.example` to `.env`.
3. Import `sql/schema.sql` into MySQL.
4. Install dependencies:
   - `npm install`
5. Create admin:
   - `npm run create-admin -- "System Admin" "09990000000" "admin@findme.local" "Admin@123"`
6. Run server:
   - `npm run dev`
7. Verify:
   - `GET http://localhost:5000/api/health`
8. Run backend tests:
   - `npm test`

## 3. Admin Dashboard Setup

1. Go to `admin_dashboard`.
2. Copy `.env.example` to `.env`.
3. Set:
   - `VITE_API_BASE_URL=http://localhost:5000/api`
   - `VITE_SOCKET_URL=http://localhost:5000`
   - `VITE_GOOGLE_MAPS_API_KEY=<your_key>`
4. Install and run:
   - `npm install`
   - `npm run dev`
5. Login with the admin account created in Step 2.

## 4. Flutter App Setup

1. Go to `mobile_app`.
2. If native wrappers are missing, run:
   - `flutter create .`
3. Run:
   - `flutter pub get`
4. Update backend URL in:
   - `lib/core/config/app_config.dart`
   - For a physical device, prefer `flutter run --dart-define=API_HOST=<your_pc_ip>` or `flutter run --dart-define=API_BASE_URL=http://<your_pc_ip>:5000/api`
5. Configure Google Maps API keys in Android/iOS native files.
6. Run app:
   - `flutter run`

## 5. End-to-End Flow Test

1. Register a driver in Flutter app.
2. Login to admin dashboard and approve the driver.
3. Login driver account in Flutter, set Online.
4. Login passenger account in Flutter, pick pickup/drop-off and tap Find Ride.
5. Driver receives request, accepts, starts, and completes ride.
6. Passenger submits rating.
7. Check admin dashboard updates:
   - online drivers
   - active rides
   - ride history
   - daily earnings

## 6. Docker Deployment (Optional)

1. From project root:
   - `docker compose up --build`
2. Services:
   - Backend: `http://localhost:5000`
   - Admin Dashboard: `http://localhost:8080`
   - MySQL: `localhost:3306`

## 7. Next Hardening Steps

1. Add OTP/SMS verification for phone-based accounts.
2. Add HTTPS reverse proxy (Nginx/Traefik) for production.
3. Move uploaded files to S3-compatible storage.
4. Add metrics/monitoring and alerting.

## 8. CI Pipeline (Implemented)

1. Workflow file:
   - `.github/workflows/ci.yml`
2. Trigger:
   - on `push` and `pull_request`
3. Jobs:
   - backend tests (`backend`: `npm install && npm test`)
   - admin dashboard build (`admin_dashboard`: `npm install && npm run build`)
   - Flutter checks (`mobile_app`: `flutter pub get && flutter analyze && flutter test`)

## 9. File-By-File Plan

For a concrete per-file execution checklist, see:

- `IMPLEMENTATION_TASKS.md`
