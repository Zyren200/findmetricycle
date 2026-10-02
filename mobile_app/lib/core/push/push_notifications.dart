import "dart:async";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";

import "../network/api_client.dart";

/// Registers this phone for push notifications (Firebase Cloud Messaging),
/// so ride requests and ride updates reach the user while the app is in the
/// background or closed. With the app open, the live socket events already
/// update the screen and Android doesn't show these pushes, so nothing
/// appears twice.
///
/// Push stays off — and nothing breaks — until the app is built with
/// android/app/google-services.json from the Firebase console.
class PushNotifications {
  PushNotifications(this._apiClient);

  final ApiClient _apiClient;

  Future<bool>? _initialized;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _registeredToken;

  Future<bool> _ensureInitialized() {
    return _initialized ??= () async {
      if (kIsWeb) return false;
      try {
        await Firebase.initializeApp();
        return true;
      } catch (_) {
        return false; // No Firebase config in this build.
      }
    }();
  }

  /// After login (or a restored session): ask for notification permission
  /// and send this device's token to the backend.
  Future<void> registerDevice() async {
    if (!await _ensureInitialized()) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);
      _tokenRefreshSub ??= messaging.onTokenRefresh.listen(_saveToken);
    } catch (_) {
      // Best-effort: the app works without push.
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      final response = await _apiClient.post(
        "/devices/push-token",
        data: {
          "token": token,
          "platform":
              defaultTargetPlatform == TargetPlatform.iOS ? "ios" : "android",
        },
      );
      if (response["success"] == true) _registeredToken = token;
    } catch (_) {}
  }

  /// On logout: stop pushes for the account that just left this phone.
  Future<void> unregisterDevice() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    final token = _registeredToken;
    _registeredToken = null;
    if (token == null) return;
    try {
      await _apiClient
          .post("/devices/push-token/unregister", data: {"token": token});
    } catch (_) {}
  }
}
