# FindMeTricycle Mobile App (Flutter)

Flutter app for Passenger and Driver workflows:

- Auth login + register (passenger/driver)
- Driver document upload during registration
- Passenger map: pickup/drop-off selection, fare estimate, find/cancel ride
- Driver map: online/offline, receive requests, accept/decline, start/complete ride
- Socket.io live updates for booking and tracking
- Wallet and payment flow:
  - wallet balance and recent transactions
  - full wallet ledger with recharge and payment entries
  - searchable and filterable wallet ledger details
  - searchable payment history with receipt handoff
  - Stellar Testnet recharge support
  - booking payment preview, QR payload, receipt, and payment history
- QR scanner for wallet/payment flows
- Post-ride rating screen

## Current Scope

This folder contains Flutter app source (`lib/` + `pubspec.yaml`) prepared for clean architecture-style modules.  
If this is a fresh folder, run `flutter create .` first to generate native Android/iOS wrapper files.

## Setup

1. Ensure Flutter SDK is installed.
2. In `mobile_app`:
   - `flutter pub get`
3. Configure backend URL in:
   - `lib/core/config/app_config.dart`
4. For Android emulator:
   - keep `apiBaseUrl` as `http://10.0.2.2:5000/api`
5. For a physical phone or tablet:
   - run with `--dart-define=API_HOST=<your_pc_ip>` or `--dart-define=API_BASE_URL=http://<your_pc_ip>:5000/api`
6. Add Google Maps API key in native config:
   - Android `AndroidManifest.xml`
   - iOS `AppDelegate` / `Info.plist`
7. Run:
   - `flutter run`
8. Run checks:
   - `flutter analyze`
   - `flutter test`

## Required Native Permissions

- Location permission (foreground)
- Camera permission for QR scanning
- Internet access

## Notes

- Driver can only go online after admin approval.
- Registration for driver requires two images:
  - license image
  - business permit image
- Socket auth token is attached during connect.
- CI also runs Flutter analyze and tests via `.github/workflows/ci.yml`.
