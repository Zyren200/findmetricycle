import "dart:convert";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../geo/service_area.dart";
import "../network/api_client.dart";

/// The service area (Guiuan's boundary and map limits). Starts from the
/// copy bundled with the app — so maps and checks work on first launch and
/// offline — then the last copy from the server, then refreshes from
/// GET /service-area, downloading it again only when it changed.
class ServiceAreaStore extends ChangeNotifier {
  ServiceAreaStore(this._apiClient);

  /// For tests: a store that already holds [area].
  @visibleForTesting
  ServiceAreaStore.withArea(ServiceArea this.area) : _apiClient = null;

  final ApiClient? _apiClient;

  static const String bundledAsset = "assets/service_area/service_area.json";
  static const String _cacheKey = "service_area_cache_v1";
  static const String _etagKey = "service_area_etag_v1";

  ServiceArea? area;
  Future<void>? _loading;

  /// Loads the bundled and cached copies, then refreshes from the server.
  /// Never throws.
  Future<void> init() => _loading ??= _init();

  Future<void> _init() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        area = ServiceArea.tryParse(jsonDecode(cached) as Map<String, dynamic>);
      }
    } catch (_) {
      // Cache unreadable — fall back to the bundled copy.
    }
    if (area == null) {
      try {
        final bundled = await rootBundle.loadString(bundledAsset);
        area = ServiceArea.tryParse(jsonDecode(bundled) as Map<String, dynamic>);
      } catch (_) {
        // Without either copy maps still open on Guiuan (kGuiuanCenter).
      }
    }
    notifyListeners();
    await refresh(prefs: prefs);
  }

  Future<void> refresh({SharedPreferences? prefs}) async {
    final api = _apiClient;
    if (api == null) return;
    try {
      prefs ??= await SharedPreferences.getInstance();
      // Only send the ETag when the copy in hand came from the server.
      final etag = area?.raw["bundled"] == true ? null : prefs.getString(_etagKey);
      final result = await api.getCached("/service-area", etag: etag);
      if (result.status == 304 || result.data["success"] != true) return;
      final fresh = ServiceArea.tryParse(result.data["data"] as Map<String, dynamic>?);
      if (fresh == null) return;
      area = fresh;
      await prefs.setString(_cacheKey, jsonEncode(fresh.raw));
      if (result.etag != null) await prefs.setString(_etagKey, result.etag!);
      notifyListeners();
    } catch (_) {
      // Offline or server unreachable: keep the copy we have.
    }
  }
}
