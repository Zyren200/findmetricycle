import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../auth/repositories/auth_repository.dart";
import "../../../core/components/index.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/socket_client.dart";
import "../../../core/state/app_preferences.dart";
import "../../../core/state/service_area_store.dart";
import "../../../core/theme/design_tokens.dart";
import "../repositories/passenger_repository.dart";
import "../repositories/favorites_repository.dart";
import "passenger_ride_controller.dart";
import "passenger_profile_controller.dart";
import "pages/passenger_home_page.dart";
import "pages/ride_history_page.dart";
import "pages/profile_page.dart";
import "../../shared/presentation/notifications_screen.dart";
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
              serviceAreaStore: context.read<ServiceAreaStore>(),
            );
            controller.setPassengerCount(
              context.read<AppPreferences>().defaultPassengerCount,
            );
            controller.initialize();
            return controller;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationsController(apiClient, socketClient,
              role: "passenger")
            ..load(),
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
      child: Builder(
        builder: (context) {
          final notifications = context.read<NotificationsController>();
          return Scaffold(
            body: Container(
              color: DesignTokens.bg,
              child: ValueListenableBuilder<int>(
                valueListenable: _navIndex,
                builder: (context, index, _) => IndexedStack(
                  index: index,
                  children: [
                    const PassengerHomePage(),
                    const RideHistoryPage(),
                    NotificationsScreen(controller: notifications, tabIndex: 2),
                    const ProfilePage(),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: ListenableBuilder(
              listenable: Listenable.merge([_navIndex, notifications]),
              builder: (context, _) => AppBottomNav(
                selectedIndex: _navIndex.value,
                onIndexChanged: (value) => _navIndex.value = value,
                items: [
                  BottomNavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: "Home",
                  ),
                  BottomNavItem(
                    icon: Icons.list_alt_outlined,
                    activeIcon: Icons.list_alt_rounded,
                    label: "Rides",
                  ),
                  BottomNavItem(
                    icon: Icons.notifications_none_rounded,
                    activeIcon: Icons.notifications_rounded,
                    label: "Alerts",
                    badgeCount: notifications.unread,
                  ),
                  BottomNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: "Profile",
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
