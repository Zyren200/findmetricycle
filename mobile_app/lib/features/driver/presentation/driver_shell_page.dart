import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/network/api_client.dart";
import "../../../core/state/app_preferences.dart";
import "../../../core/network/socket_client.dart";
import "../../../core/theme/design_tokens.dart";
import "../repositories/driver_repository.dart";
import "../../shared/state/notifications_controller.dart";
import "driver_earnings_page.dart";
import "driver_home_page.dart";
import "driver_profile_page.dart";
import "driver_ride_controller.dart";
import "driver_rides_page.dart";
import "pages/ride_request_page.dart";
import "widgets/driver_ride_actions.dart";

/// Driver Mode's top-level shell: Home / Rides / Earnings / Profile,
/// mirroring PassengerShellPage's IndexedStack + AppBottomNav pattern. Owns
/// the single DriverRideController instance for the whole driver session —
/// tabs (and anything pushed on top of them) read it via ambient Provider
/// instead of each page creating its own.
class DriverShellPage extends StatefulWidget {
  const DriverShellPage({super.key});

  @override
  State<DriverShellPage> createState() => _DriverShellPageState();
}

class _DriverShellPageState extends State<DriverShellPage> {
  final ValueNotifier<int> _navIndex = ValueNotifier<int>(0);

  @override
  void dispose() {
    _navIndex.dispose();
    super.dispose();
  }

  /// The "Auto Online" setting, applied once when Driver Mode opens: on →
  /// go Online right away; off → start Offline, even if the server still
  /// had the rider online from a previous session.
  Future<void> _applyAutoOnline(
      DriverRideController controller, AppPreferences prefs) async {
    await prefs.ready;
    if (!mounted || controller.activeBooking != null) return;
    if (prefs.driverAutoOnline && !controller.isOnline) {
      await controller.setOnline(true);
    } else if (!prefs.driverAutoOnline && controller.isOnline) {
      await controller.setOnline(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = context.read<ApiClient>();
    final socketClient = context.read<SocketClient>();

    return MultiProvider(
      providers: [
        // Lets tabs (e.g. Rides) react when they're opened — the
        // IndexedStack keeps them alive, so initState only runs once.
        ChangeNotifierProvider.value(value: _navIndex),
        ChangeNotifierProvider(
          create: (_) =>
              NotificationsController(apiClient, socketClient, role: "driver")
                ..load(),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final controller = DriverRideController(
              DriverRepository(apiClient),
              socketClient,
            );
            final prefs = context.read<AppPreferences>();
            controller
                .initialize()
                .then((_) => _applyAutoOnline(controller, prefs));
            return controller;
          },
        ),
      ],
      child: _IncomingRequestWatcher(
        child: Scaffold(
          body: Container(
            color: DesignTokens.bg,
            child: ValueListenableBuilder<int>(
              valueListenable: _navIndex,
              builder: (context, index, _) => IndexedStack(
                index: index,
                children: const [
                  DriverHomePage(),
                  DriverRidesPage(),
                  DriverEarningsPage(),
                  DriverProfilePage(),
                ],
              ),
            ),
          ),
          bottomNavigationBar: ValueListenableBuilder<int>(
            valueListenable: _navIndex,
            builder: (context, index, _) => AppBottomNav(
              selectedIndex: index,
              onIndexChanged: (value) => _navIndex.value = value,
              items: [
                BottomNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: "Home",
                ),
                BottomNavItem(
                  icon: Icons.route_outlined,
                  activeIcon: Icons.route,
                  label: "Rides",
                ),
                BottomNavItem(
                  icon: Icons.payments_outlined,
                  activeIcon: Icons.payments,
                  label: "Earnings",
                ),
                BottomNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: "Profile",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the Ride Request screen as soon as a new offer arrives, whichever
/// tab (or pushed page) the rider is on.
class _IncomingRequestWatcher extends StatefulWidget {
  const _IncomingRequestWatcher({required this.child});

  final Widget child;

  @override
  State<_IncomingRequestWatcher> createState() =>
      _IncomingRequestWatcherState();
}

class _IncomingRequestWatcherState extends State<_IncomingRequestWatcher> {
  DriverRideController? _ctrl;
  String? _shownId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = context.read<DriverRideController>();
    if (_ctrl == ctrl) return;
    _ctrl?.removeListener(_onChanged);
    _ctrl = ctrl..addListener(_onChanged);
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final ctrl = _ctrl;
    final id = ctrl?.incomingBooking?["id"]?.toString();
    if (id == null || ctrl!.activeBooking != null || id == _shownId) return;
    _shownId = id; // each offer pops up once; the Home card stays for reopening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ctrl.incomingBooking?["id"]?.toString() != id) return;
      openRideRequestPage(context, const RideRequestPage());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
