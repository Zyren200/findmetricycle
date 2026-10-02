import "package:flutter/foundation.dart";

import "../network/api_client.dart";

/// Admin-managed app settings from GET /app-config: support contacts,
/// service hours and disabled barangays. Public, so it loads before login.
class AppConfigStore extends ChangeNotifier {
  AppConfigStore(this._apiClient);

  final ApiClient _apiClient;

  static const Duration _maxAge = Duration(minutes: 1);

  String supportEmail = "";
  String contactNumber = "";
  String operatingHoursLabel = "";
  bool operatingHoursEnforced = false;
  bool isOpenNow = true;
  List<String> disabledBarangays = const [];

  DateTime? _loadedAt;
  Future<void>? _pending;

  bool get hasSupportContact =>
      supportEmail.isNotEmpty || contactNumber.isNotEmpty;

  /// True when the admin blocks bookings outside service hours and it's
  /// currently outside them. The server enforces this too.
  bool get bookingClosedNow => operatingHoursEnforced && !isOpenNow;

  /// Fetches the config unless it's fresh; never throws (keeps the last
  /// known values when offline).
  Future<void> refresh({bool force = false}) {
    final loadedAt = _loadedAt;
    if (!force &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < _maxAge) {
      return Future.value();
    }
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<void> _load() async {
    try {
      final response = await _apiClient.get("/app-config");
      if (response["success"] != true) return;
      final data = response["data"] as Map<String, dynamic>? ?? {};
      final hours = data["operatingHours"] as Map<String, dynamic>? ?? {};

      supportEmail = data["supportEmail"]?.toString().trim() ?? "";
      contactNumber = data["contactNumber"]?.toString().trim() ?? "";
      operatingHoursLabel = hours["label"]?.toString() ?? "";
      operatingHoursEnforced = hours["enforced"] == true;
      isOpenNow = hours["isOpenNow"] != false;
      disabledBarangays = (data["disabledBarangays"] as List? ?? const [])
          .map((name) => name.toString())
          .toList();
      _loadedAt = DateTime.now();
      notifyListeners();
    } catch (_) {
      // Offline — keep what we had.
    }
  }
}
