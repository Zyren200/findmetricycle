import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../auth/repositories/auth_repository.dart";
import "../../../core/components/index.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/socket_client.dart";
import "../../../core/state/app_preferences.dart";
import "../../../core/theme/design_tokens.dart";
import "../repositories/passenger_repository.dart";
import "../repositories/favorites_repository.dart";
import "passenger_map_page.dart";
import "passenger_ride_controller.dart";
import "passenger_profile_controller.dart";
import "pages/ride_history_page.dart";
import "pages/favorites_page.dart";
import "pages/profile_page.dart";
import "../../shared/state/notifications_controller.dart";

class PassengerShellPage extends StatefulWidget {
  const PassengerShellPage({super.key});

  @override
  State<PassengerShellPage> createState() => _PassengerShellPageState();
}

class _PassengerShellPageState extends State<PassengerShellPage> {
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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _navIndex),
        ChangeNotifierProvider(
          create: (_) {
            final controller = PassengerRideController(
              PassengerRepository(apiClient),
              socketClient,
            );
            controller.setPassengerCount(
              context.read<AppPreferences>().defaultPassengerCount,
            );
            controller.initialize();
            return controller;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationsController(apiClient, socketClient, role: "passenger")..load(),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final controller = PassengerProfileController(
              AuthRepository(apiClient),
              FavoritesRepository(apiClient),
            );
            controller.loadDriverStatus();
            controller.loadFavorites();
            return controller;
          },
        ),
      ],
      child: Scaffold(
        body: Container(
          color: DesignTokens.bg,
          child: ValueListenableBuilder<int>(
            valueListenable: _navIndex,
            builder: (context, index, _) => IndexedStack(
              index: index,
              children: const [
                PassengerMapPage(),
                RideHistoryPage(),
                FavoritesPage(),
                ProfilePage(),
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
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: "Home",
              ),
              BottomNavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: "History",
              ),
              BottomNavItem(
                icon: Icons.star_border_rounded,
                activeIcon: Icons.star,
                label: "Favorites",
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
