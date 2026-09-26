import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:geolocator/geolocator.dart";
import "package:provider/provider.dart";
import "core/network/api_client.dart";
import "core/network/socket_client.dart";
import "core/state/app_preferences.dart";
import "core/theme/app_theme.dart";
import "features/shared/state/session_store.dart";
import "routes/app_router.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FindMeTricycleApp());
}

class FindMeTricycleApp extends StatelessWidget {
  const FindMeTricycleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => const FlutterSecureStorage()),
        Provider(create: (_) => ApiClient()),
        Provider(create: (_) => SocketClient()),
        ChangeNotifierProvider(create: (_) => AppPreferences()..init()),
        ChangeNotifierProxyProvider2<ApiClient, SocketClient, SessionStore>(
          create: (_) => SessionStore(),
          update: (_, apiClient, socketClient, store) {
            final sessionStore = store ?? SessionStore();
            sessionStore.bind(apiClient, socketClient);
            return sessionStore;
          },
        ),
      ],
      child: const _AppBootstrap(),
    );
  }
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  bool _didInitialize = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) return;

    _didInitialize = true;
    final sessionStore = context.read<SessionStore>();
    final storage = context.read<FlutterSecureStorage>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sessionStore.initialize(storage);
      _requestLocationPermission();
    });
  }

  /// Prompt for location permission as soon as the app opens, rather than
  /// waiting until the passenger map screen first needs a GPS fix — so the
  /// user sees the OS permission dialog right away instead of a silent
  /// "location unavailable" state later.
  Future<void> _requestLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {
      // Best-effort prompt only — the map/booking flow will re-request
      // permission itself when it actually needs a location fix.
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<AppPreferences>().themeMode;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "FindMeTricycle",
      theme: AppTheme.buildLight(),
      darkTheme: AppTheme.build(),
      themeMode: themeMode,
      home: const AppRouter(),
    );
  }
}
