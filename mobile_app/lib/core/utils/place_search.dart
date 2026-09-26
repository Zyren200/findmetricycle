import "package:dio/dio.dart";

/// Search-as-you-type place lookup via Photon (Komoot's free OSM-based
/// geocoder). Nominatim — already used elsewhere for reverse-geocoding —
/// only reliably matches complete or near-complete words, so it can't
/// power live per-letter suggestions; Photon is built for exactly this and
/// needs no API key either.
const String _photonBaseUrl = "https://photon.komoot.io/api/";

/// Roughly covers Guiuan and its surrounding barangays/municipalities so
/// suggestions stay relevant to the service area instead of surfacing
/// places from anywhere in the world.
const String _guiuanBbox = "125.55,10.85,125.85,11.15";

final Dio _searchClient = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ),
);

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.name,
    required this.secondaryLabel,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String secondaryLabel;
  final double lat;
  final double lng;
}

/// Returns place suggestions matching [query], or an empty list if the
/// query is blank or the request fails — callers should treat both the
/// same way (nothing to show yet).
Future<List<PlaceSuggestion>> searchPlaces(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return [];

  try {
    final response = await _searchClient.get(
      _photonBaseUrl,
      queryParameters: {
        "q": trimmed,
        "bbox": _guiuanBbox,
        "limit": 8,
      },
    );

    final data = response.data;
    if (data is! Map) return [];

    final features = data["features"];
    if (features is! List) return [];

    final suggestions = <PlaceSuggestion>[];
    for (final feature in features) {
      if (feature is! Map) continue;

      final geometry = feature["geometry"];
      final coordinates = geometry is Map ? geometry["coordinates"] : null;
      if (coordinates is! List || coordinates.length < 2) continue;

      final lng = (coordinates[0] as num?)?.toDouble();
      final lat = (coordinates[1] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final props = feature["properties"];
      if (props is! Map) continue;

      final name = props["name"] as String?;
      if (name == null || name.isEmpty) continue;

      final secondaryParts = <String>[
        for (final key in ["street", "locality", "city", "state"])
          if (props[key] is String && (props[key] as String).isNotEmpty)
            props[key] as String,
      ];
      // Drop the street/locality if it duplicates the name itself.
      secondaryParts.removeWhere((part) => part == name);

      suggestions.add(PlaceSuggestion(
        name: name,
        secondaryLabel: secondaryParts.take(2).join(", "),
        lat: lat,
        lng: lng,
      ));
    }
    return suggestions;
  } catch (_) {
    return [];
  }
}
