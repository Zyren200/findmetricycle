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

  ThemeMode _themeMode = ThemeMode.dark;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _language = "en";
  int _defaultPassengerCount = 1;
  final Map<String, bool> _notificationPrefs = {
    for (final key in notificationKeys) key: true,
  };

  bool _loaded = false;
  SharedPreferences? _prefs;

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

    final modeStr = prefs.getString(_keyThemeMode) ?? "dark";
    _themeMode = switch (modeStr) {
      "light" => ThemeMode.light,
      "system" => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    _soundEnabled = prefs.getBool(_keySound) ?? true;
    _vibrationEnabled = prefs.getBool(_keyVibration) ?? true;
    _language = prefs.getString(_keyLanguage) ?? "en";
    _defaultPassengerCount = (prefs.getInt(_keyDefaultPassengerCount) ?? 1)
        .clamp(minPassengers, maxPassengers);

    for (final key in notificationKeys) {
      _notificationPrefs[key] = prefs.getBool("$_keyNotificationPrefix$key") ?? true;
    }

    _loaded = true;
    notifyListeners();
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
