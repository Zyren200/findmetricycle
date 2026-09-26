import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/socket_client.dart";
import "../../../core/theme/design_tokens.dart";
import "../repositories/driver_repository.dart";
import "driver_earnings_page.dart";
import "driver_home_page.dart";
import "driver_profile_page.dart";
import "driver_ride_controller.dart";
import "driver_rides_page.dart";

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

  @override
  Widget build(BuildContext context) {
    final apiClient = context.read<ApiClient>();
    final socketClient = context.read<SocketClient>();

    return ChangeNotifierProvider(
      create: (_) {
        final controller = DriverRideController(
          DriverRepository(apiClient),
          socketClient,
        );
        controller.initialize();
        return controller;
      },
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
    );
  }
}
