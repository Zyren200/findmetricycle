import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:provider/provider.dart";
import "../features/auth/presentation/login_page.dart";
import "../features/driver/presentation/driver_shell_page.dart";
import "../features/passenger/presentation/passenger_shell_page.dart";
import "../features/shared/state/session_store.dart";

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionStore = context.watch<SessionStore>();
    final storage = context.read<FlutterSecureStorage>();

    // Only the startup session restore gets a full-screen spinner. A login
    // attempt shows its spinner on the Login button instead — replacing
    // LoginPage here would dispose it and wipe what the user typed.
    if (!sessionStore.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = sessionStore.session;
    if (session == null) {
      return const LoginPage();
    }

    final activeMode = session.effectiveRole;
    if (activeMode == "driver") {
      return const DriverShellPage();
    }

    if (activeMode == "passenger" || session.isAdmin) {
      return const PassengerShellPage();
    }

    return Scaffold(
      appBar: AppBar(title: const Text("FindMeTricycle")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Admin accounts use the web dashboard."),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => sessionStore.logout(storage),
              child: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }
}
