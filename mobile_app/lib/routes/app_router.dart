import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:provider/provider.dart";
import "../core/components/index.dart";
import "../core/state/app_preferences.dart";
import "../core/theme/design_tokens.dart";
import "../features/auth/presentation/auth_flow.dart";
import "../features/auth/presentation/location_permission_page.dart";
import "../features/auth/presentation/splash_page.dart";
import "../features/driver/presentation/driver_shell_page.dart";
import "../features/passenger/presentation/passenger_shell_page.dart";
import "../features/shared/state/session_store.dart";

/// What the app shows: the splash while the saved session is restored,
/// the sign-in flow when signed out, and the passenger or driver shell
/// (after the one-time location prompt) when signed in.
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  /// The splash stays up at least this long so its entrance can finish.
  bool _splashDone = false;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionStore = context.watch<SessionStore>();
    final prefs = context.watch<AppPreferences>();

    final Widget screen;
    if (!sessionStore.isInitialized || !prefs.isLoaded || !_splashDone) {
      screen = const SplashPage(key: ValueKey("splash"));
    } else if (sessionStore.session == null) {
      // A login attempt shows its spinner on the Log in button —
      // replacing the sign-in flow here would wipe what the user typed.
      screen = const AuthFlow(key: ValueKey("auth"));
    } else {
      screen = LocationGate(
        key: const ValueKey("app"),
        child: _shellFor(context, sessionStore),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: DesignTokens.easeOut,
      child: screen,
    );
  }

  Widget _shellFor(BuildContext context, SessionStore sessionStore) {
    final session = sessionStore.session!;
    final activeMode = session.effectiveRole;
    if (activeMode == "driver") {
      return const DriverShellPage(key: ValueKey("driver"));
    }

    if (activeMode == "passenger" || session.isAdmin) {
      return const PassengerShellPage(key: ValueKey("passenger"));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyState(
                  icon: Icons.admin_panel_settings_outlined,
                  message: "Admin accounts use the web dashboard.",
                ),
                SunButton(
                  label: "Log out",
                  tone: SunTone.outline,
                  height: 48,
                  onPressed: () =>
                      sessionStore.logout(context.read<FlutterSecureStorage>()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
