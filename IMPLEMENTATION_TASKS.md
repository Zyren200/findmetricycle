# FindMeTricycle Per-File Task List

Status note:
- The backend already has wallets, payments, and the base ride flow in place.
- The remaining work is mostly deeper Stellar Testnet wiring, richer booking states, MapLibre/OpenFreeMap UI, QR payment UX, and admin finance pages.
- Keep existing auth, booking, driver approval, and Socket.IO behavior intact while expanding the system.

## Backend
- [ ] `backend/src/constants/booking-status.js`: expand the booking state machine to support the richer ride flow while keeping the current states compatible where possible.
- [ ] `backend/sql/schema.sql`: update the `bookings.status` enum, verify wallet/payment indexes, and add any missing receipt or analytics fields.
- [ ] `backend/src/models/booking.model.js`: add helpers for the new ride transitions and keep active-ride queries aligned with the expanded states.
- [ ] `backend/src/services/booking.service.js`: split the ride lifecycle into the full state ladder for searching, arriving, picked up, in progress, completed, and payment pending/successful.
- [ ] `backend/src/controllers/driver.controller.js`: expose any new driver transition endpoints and emit matching Socket.IO events.
- [ ] `backend/src/routes/driver.routes.js`: wire any new arriving or pickup-confirmation routes needed by the mobile driver UI.
- [ ] `backend/src/validations/driver.schema.js`: add schemas for the new driver transition payloads.
- [ ] `backend/src/sockets/index.js`: broadcast smoother driver locations, route and ETA updates, ride state transitions, and payment completion events.
- [ ] `backend/src/config/env.js`: add Stellar Horizon and friendbot config plus any payment or map feature flags.
- [ ] `backend/src/utils/stellar-wallet.js`: add testnet funding, balance lookup, and signed transaction helpers.
- [ ] `backend/src/services/wallet.service.js`: ensure wallets are created on auth, support test recharge, and expose QR/history-friendly payloads.
- [ ] `backend/src/controllers/wallet.controller.js`: add wallet detail, QR, recharge, and history endpoints.
- [ ] `backend/src/routes/wallet.routes.js`: wire the expanded wallet API.
- [ ] `backend/src/validations/wallet.schema.js`: validate wallet recharge, history pagination, and QR-related requests.
- [ ] `backend/src/models/wallet.model.js`: add any query helpers needed for wallet admin views and transaction lookups.
- [ ] `backend/src/services/payment.service.js`: handle preview, QR confirmation, Stellar payment execution, receipt generation, and payment history.
- [ ] `backend/src/controllers/payment.controller.js`: expose preview, pay, history, and receipt endpoints and emit payment socket events.
- [ ] `backend/src/routes/payment.routes.js`: wire payment preview, QR, history, and receipt routes.
- [ ] `backend/src/validations/payment.schema.js`: validate payment preview, QR payment, and receipt params.
- [ ] `backend/src/models/payment.model.js`: extend filters and lookup queries if the new admin screens need more payment fields.
- [ ] `backend/src/services/admin.service.js`: aggregate payment, wallet, and blockchain analytics for the admin dashboard.
- [ ] `backend/src/controllers/admin.controller.js`: expose payments, wallets, transactions, and financial analytics endpoints.
- [ ] `backend/src/routes/admin.routes.js`: wire the new admin finance routes.
- [ ] `backend/tests/wallet-payment.test.js`: expand coverage for recharge, payment, receipt, and failure cases.
- [ ] `backend/tests/booking-flow.test.js`: add coverage for the expanded ride status transitions.
- [ ] `backend/tests/socket-events.test.js`: add coverage for live tracking and payment-related socket payloads.

## Mobile App
- [x] `mobile_app/pubspec.yaml`: add MapLibre, QR scanning, receipt/share, and any PDF or chart dependencies.
- [x] `mobile_app/lib/core/config/app_config.dart`: add OpenFreeMap style URLs, wallet/payment API constants, and any Stellar/Testnet config.
- [ ] `mobile_app/lib/core/theme/app_theme.dart`: add light and dark themes, glassmorphism surfaces, and map overlay colors.
- [ ] `mobile_app/lib/main.dart`: keep provider setup stable while supporting theme mode and any new repositories.
- [ ] `mobile_app/lib/core/network/socket_client.dart`: listen for smooth driver movement, ride state updates, and payment events.
- [x] `mobile_app/lib/features/passenger/presentation/passenger_shell_page.dart`: add wallet and payment history entry points to the passenger navigation.
- [x] `mobile_app/lib/features/passenger/presentation/passenger_map_page.dart`: replace `flutter_map`/OSM with MapLibre/OpenFreeMap, add controls, nearby drivers, route lines, and animated markers.
- [ ] `mobile_app/lib/features/passenger/presentation/passenger_ride_controller.dart`: manage interpolation, ETA, ride status flow, and payment readiness.
- [ ] `mobile_app/lib/features/passenger/repositories/passenger_repository.dart`: call the new wallet and payment endpoints.
- [x] `mobile_app/lib/features/driver/presentation/driver_home_page.dart`: surface driver wallet, QR, and payment status alongside the live ride map.
- [ ] `mobile_app/lib/features/driver/presentation/driver_ride_controller.dart`: add richer ride state handling, heading-aware movement, and wallet/payment sync.
- [ ] `mobile_app/lib/features/driver/presentation/driver_profile_page.dart`: show wallet address, QR code, earnings, and payment history entry points.
- [ ] `mobile_app/lib/features/driver/repositories/driver_repository.dart`: add driver wallet and history API calls.
- [ ] `mobile_app/lib/features/shared/state/session_store.dart`: persist any extra wallet metadata returned by auth if the UI needs it.
- [ ] `mobile_app/lib/features/shared/models/user_session.dart`: expand session data only if auth starts returning wallet fields.
- [ ] `mobile_app/lib/features/booking/presentation/rating_page.dart`: make sure the post-payment flow still lands here cleanly after the new status ladder.
- [x] `mobile_app/lib/features/wallet/repositories/wallet_repository.dart`: create a dedicated wallet API layer.
- [x] `mobile_app/lib/features/wallet/repositories/payment_repository.dart`: create a dedicated payment API layer.
- [x] `mobile_app/lib/features/wallet/presentation/passenger_wallet_page.dart`: build the passenger wallet dashboard.
- [x] `mobile_app/lib/features/wallet/presentation/driver_wallet_page.dart`: build the driver wallet dashboard.
- [x] `mobile_app/lib/features/wallet/presentation/payment_history_page.dart`: show passenger and driver payment histories.
- [x] `mobile_app/lib/features/wallet/presentation/qr_payment_page.dart`: handle QR scan, preview, and confirm.
- [x] `mobile_app/lib/features/wallet/presentation/payment_receipt_page.dart`: show and share or download receipts.
- [x] `mobile_app/lib/features/wallet/presentation/qr_scanner_page.dart`: wrap the scanner flow.
- [x] `mobile_app/lib/features/wallet/presentation/widgets/wallet_summary_card.dart`: add a reusable wallet summary card.
- [x] `mobile_app/lib/features/wallet/presentation/widgets/transaction_row.dart`: add a reusable transaction row.
- [x] `mobile_app/android/app/src/main/AndroidManifest.xml`: add camera and location permissions needed by the new flows.
- [x] `mobile_app/ios/Runner/Info.plist`: add camera and location usage strings and any map permissions.
- [x] `mobile_app/web/index.html`: only update if the Flutter web target needs a fallback or map key config.

## Admin Dashboard
- [ ] `admin_dashboard/package.json`: add MapLibre, charts, and any receipt/export helpers.
- [ ] `admin_dashboard/src/App.jsx`: turn the binary auth gate into a dashboard shell with navigation.
- [ ] `admin_dashboard/src/main.jsx`: wrap the app with any new theme or layout providers.
- [ ] `admin_dashboard/src/context/AuthContext.jsx`: keep auth stable; extend only if route or theme state needs to be shared.
- [ ] `admin_dashboard/src/styles.css`: rebuild the layout for dark/light mode, responsive cards, and polished finance pages.
- [ ] `admin_dashboard/src/pages/DashboardPage.jsx`: convert the current overview into a shell or extract the overview into its own page.
- [ ] `admin_dashboard/src/pages/PaymentsPage.jsx`: build the payments dashboard.
- [ ] `admin_dashboard/src/pages/WalletsPage.jsx`: build the wallet management page.
- [ ] `admin_dashboard/src/pages/TransactionsPage.jsx`: build the blockchain transaction ledger.
- [ ] `admin_dashboard/src/pages/AnalyticsPage.jsx`: build the financial analytics page.
- [ ] `admin_dashboard/src/components/LiveMapCard.jsx`: replace Leaflet with MapLibre/OpenFreeMap and add live movement and route rendering.
- [ ] `admin_dashboard/src/components/SummaryCards.jsx`: add payment and wallet metrics.
- [ ] `admin_dashboard/src/components/PendingDriversTable.jsx`: keep approvals intact and align the new shell styling.
- [ ] `admin_dashboard/src/components/FareSettingsCard.jsx`: keep fare settings, but match the updated design system.
- [ ] `admin_dashboard/src/components/PaymentsTable.jsx`: create a searchable payment list.
- [ ] `admin_dashboard/src/components/WalletsTable.jsx`: create a searchable wallet list.
- [ ] `admin_dashboard/src/components/TransactionsTable.jsx`: create a blockchain transaction list.
- [ ] `admin_dashboard/src/components/AnalyticsCharts.jsx`: create charts for totals, success rates, and revenue.
- [ ] `admin_dashboard/src/components/FiltersBar.jsx`: create shared filters for payments, wallets, and transactions.
- [ ] `admin_dashboard/src/hooks/useSocket.js`: extend live events for payment completion and richer driver updates.
- [ ] `admin_dashboard/vite.config.js`: only touch if the new map or asset flow needs a dev-server proxy tweak.
