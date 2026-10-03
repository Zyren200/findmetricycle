import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:geolocator/geolocator.dart";
import "package:provider/provider.dart";
import "core/network/api_client.dart";
import "core/network/socket_client.dart";
import "core/push/push_notifications.dart";
import "core/state/app_config_store.dart";
import "core/state/app_preferences.dart";
import "core/state/service_area_store.dart";
import "core/theme/app_theme.dart";
import "core/theme/design_tokens.dart";
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
        Provider(
          create: (context) => PushNotifications(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider(create: (_) => AppPreferences()..init()),
        ChangeNotifierProvider(
          create: (context) =>
              AppConfigStore(context.read<ApiClient>())..refresh(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ServiceAreaStore(context.read<ApiClient>())..init(),
        ),
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
  SessionStore? _sessionStore;
  bool _wasLoggedIn = false;
  Future<void> _locationPrompt = Future.value();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) return;

    _didInitialize = true;
    final sessionStore = context.read<SessionStore>();
    final storage = context.read<FlutterSecureStorage>();
    _sessionStore = sessionStore..addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sessionStore.initialize(storage);
      _locationPrompt = _requestLocationPermission();
    });
  }

  @override
  void dispose() {
    _sessionStore?.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// Registers the phone for push notifications on login (or a restored
  /// session) and unregisters it on logout.
  Future<void> _onSessionChanged() async {
    if (!mounted) return;
    final loggedIn = _sessionStore?.isLoggedIn ?? false;
    if (loggedIn == _wasLoggedIn) return;
    _wasLoggedIn = loggedIn;
    final push = context.read<PushNotifications>();
    if (loggedIn) {
      // Android shows one permission dialog at a time.
      await _locationPrompt;
      await push.registerDevice();
    } else {
      await push.unregisterDevice();
    }
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
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    // Screens read DesignTokens directly (many through const widgets), so a
    // palette switch has to rebuild every element — not just the ones that
    // depend on Theme.of. State (navigation, rides, online status) is kept.
    if (DesignTokens.isDark != isDark) {
      DesignTokens.isDark = isDark;
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "FindMeTricycle",
      theme: AppTheme.build(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      darkTheme: AppTheme.build(),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppRouter(),
    );
  }

  void _rebuildAll() {
    if (!mounted) return;
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }
}
