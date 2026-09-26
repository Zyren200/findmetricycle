import "package:dio/dio.dart";

/// On-device reverse geocoding via OpenStreetMap's Nominatim service — the
/// standard free companion to the OpenFreeMap/OSM tiles this app already
/// uses for the map itself, so no new backend service or API key is needed.
/// Nominatim's usage policy requires a descriptive User-Agent and caps
/// public-instance traffic at roughly 1 request/second, which is well
/// within what a single user tapping the map produces.
final Dio _geocodingClient = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: const {"User-Agent": "FindMeTricycle/1.0 (passenger app)"},
  ),
);

/// Resolves a lat/lng into a short human-readable address, or null if the
/// lookup fails or times out — callers should fall back to showing raw
/// coordinates rather than blocking on this.
Future<String?> reverseGeocode(double lat, double lng) async {
  try {
    final response = await _geocodingClient.get(
      "https://nominatim.openstreetmap.org/reverse",
      queryParameters: {
        "format": "jsonv2",
        "lat": lat,
        "lon": lng,
        "zoom": 18,
        "addressdetails": 1,
      },
    );

    final data = response.data;
    if (data is! Map) return null;

    final address = data["address"];
    if (address is Map) {
      final parts = <String>[];
      for (final key in [
        "road",
        "neighbourhood",
        "suburb",
        "village",
        "town",
        "city",
      ]) {
        final value = address[key];
        if (value is String && value.isNotEmpty && !parts.contains(value)) {
          parts.add(value);
        }
        if (parts.length >= 2) break;
      }
      if (parts.isNotEmpty) return parts.join(", ");
    }

    final displayName = data["display_name"];
    if (displayName is String && displayName.isNotEmpty) {
      final segments = displayName.split(",").map((s) => s.trim()).toList();
      return segments.take(2).join(", ");
    }

    return null;
  } catch (_) {
    return null;
  }
}
