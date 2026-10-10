import "dart:async";

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

/// Local, per-device app preferences — theme, sound, vibration, language,
/// default passenger count, and notification-category toggles. These are
/// the passenger's own UI/UX choices, not Admin-controlled settings, so
/// they're persisted on-device rather than synced to the backend.
class AppPreferences extends ChangeNotifier {
  static const _keyThemeMode = "pref_theme_mode"; // "system" | "light" | "dark"
  static const _keySound = "pref_sound_enabled";
  static const _keyVibration = "pref_vibration_enabled";
  static const _keyLanguage = "pref_language";
  static const _keyDefaultPassengerCount = "pref_default_passenger_count";
  static const _keyNotificationPrefix = "pref_notif_";
  static const _keyDriverAutoOnline = "pref_driver_auto_online";
  static const _keyOnboardingSeen = "pref_onboarding_seen";
  static const _keyLocationPromptSeen = "pref_location_prompt_seen";

  static const int minPassengers = 1;
  static const int maxPassengers = 5;

  static const List<String> notificationKeys = [
    "rideUpdates",
    "driverAccepted",
    "driverArrived",
    "tripStarted",
    "tripCompleted",
    "applicationUpdates",
    "announcements",
  ];

  ThemeMode _themeMode = ThemeMode.system;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _language = "en";
  int _defaultPassengerCount = 1;
  final Map<String, bool> _notificationPrefs = {
    for (final key in notificationKeys) key: true,
  };

  /// Driver Mode: go Online automatically when Driver Mode opens. When off,
  /// the driver always starts Offline and taps GO ONLINE themselves.
  bool _driverAutoOnline = false;

  /// The first-launch intro slides have been shown (or skipped).
  bool _onboardingSeen = false;

  /// "Turn on your location" has been answered once (allowed or not now).
  bool _locationPromptSeen = false;

  bool _loaded = false;
  SharedPreferences? _prefs;
  final Completer<void> _ready = Completer<void>();

  /// Completes once the saved preferences have been read.
  Future<void> get ready => _ready.future;
  bool get driverAutoOnline => _driverAutoOnline;
  bool get onboardingSeen => _onboardingSeen;
  bool get locationPromptSeen => _locationPromptSeen;

  ThemeMode get themeMode => _themeMode;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  String get language => _language;
  int get defaultPassengerCount => _defaultPassengerCount;
  bool get isLoaded => _loaded;

  bool isNotificationEnabled(String key) => _notificationPrefs[key] ?? true;

  Future<void> init() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    final modeStr = prefs.getString(_keyThemeMode) ?? "system";
    _themeMode = switch (modeStr) {
      "light" => ThemeMode.light,
      "dark" => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _soundEnabled = prefs.getBool(_keySound) ?? true;
    _vibrationEnabled = prefs.getBool(_keyVibration) ?? true;
    _language = prefs.getString(_keyLanguage) ?? "en";
    _defaultPassengerCount = (prefs.getInt(_keyDefaultPassengerCount) ?? 1)
        .clamp(minPassengers, maxPassengers);

    for (final key in notificationKeys) {
      _notificationPrefs[key] =
          prefs.getBool("$_keyNotificationPrefix$key") ?? true;
    }

    _driverAutoOnline = prefs.getBool(_keyDriverAutoOnline) ?? false;
    _onboardingSeen = prefs.getBool(_keyOnboardingSeen) ?? false;
    _locationPromptSeen = prefs.getBool(_keyLocationPromptSeen) ?? false;

    _loaded = true;
    if (!_ready.isCompleted) _ready.complete();
    notifyListeners();
  }

  Future<void> setDriverAutoOnline(bool value) async {
    _driverAutoOnline = value;
    notifyListeners();
    await _prefs?.setBool(_keyDriverAutoOnline, value);
  }

  Future<void> setOnboardingSeen() async {
    _onboardingSeen = true;
    notifyListeners();
    await _prefs?.setBool(_keyOnboardingSeen, true);
  }

  Future<void> setLocationPromptSeen() async {
    _locationPromptSeen = true;
    notifyListeners();
    await _prefs?.setBool(_keyLocationPromptSeen, true);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs?.setString(
      _keyThemeMode,
      switch (mode) {
        ThemeMode.light => "light",
        ThemeMode.system => "system",
        ThemeMode.dark => "dark",
      },
    );
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    notifyListeners();
    await _prefs?.setBool(_keySound, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    notifyListeners();
    await _prefs?.setBool(_keyVibration, value);
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    notifyListeners();
    await _prefs?.setString(_keyLanguage, value);
  }

  Future<void> setDefaultPassengerCount(int value) async {
    _defaultPassengerCount = value.clamp(minPassengers, maxPassengers);
    notifyListeners();
    await _prefs?.setInt(_keyDefaultPassengerCount, _defaultPassengerCount);
  }

  Future<void> setNotificationEnabled(String key, bool value) async {
    _notificationPrefs[key] = value;
    notifyListeners();
    await _prefs?.setBool("$_keyNotificationPrefix$key", value);
  }
}
