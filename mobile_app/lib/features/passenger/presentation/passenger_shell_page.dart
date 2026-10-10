import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../auth/repositories/auth_repository.dart";
import "../../../core/components/index.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/socket_client.dart";
import "../../../core/state/app_preferences.dart";
import "../../../core/state/service_area_store.dart";
import "../repositories/passenger_repository.dart";
import "../repositories/favorites_repository.dart";
import "passenger_ride_controller.dart";
import "passenger_profile_controller.dart";
import "pages/passenger_home_page.dart";
import "pages/ride_history_page.dart";
import "pages/profile_page.dart";
import "../../shared/presentation/notifications_screen.dart";
import "../../shared/state/notifications_controller.dart";

/// Passenger Mode: Home / Rides / Alerts / Profile under the floating
/// glass tab bar. Owns the passenger's controllers for the whole session.
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
            controller.loadUserProfile();
            return controller;
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          final notifications = context.read<NotificationsController>();
          return ValueListenableBuilder<int>(
            valueListenable: _navIndex,
            builder: (context, index, child) => PopScope(
              // Back on another tab returns Home first.
              canPop: index == 0,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _navIndex.value = 0;
              },
              child: child!,
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _navIndex,
                      builder: (context, index, _) => IndexedStack(
                        index: index,
                        children: [
                          const PassengerHomePage(),
                          const RideHistoryPage(),
                          NotificationsScreen(
                              controller: notifications, tabIndex: 2),
                          const ProfilePage(),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ListenableBuilder(
                      listenable: Listenable.merge([_navIndex, notifications]),
                      builder: (context, _) => FloatingTabBar(
                        index: _navIndex.value,
                        onChanged: (value) => _navIndex.value = value,
                        tabs: [
                          const SunTab(icon: Icons.home_rounded, label: "Home"),
                          const SunTab(
                              icon: Icons.schedule_rounded, label: "Rides"),
                          SunTab(
                            icon: Icons.notifications_none_rounded,
                            label: "Alerts",
                            badge: notifications.unread,
                          ),
                          const SunTab(
                              icon: Icons.person_outline_rounded,
                              label: "Profile"),
                        ],
                      ),
                    ),
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
