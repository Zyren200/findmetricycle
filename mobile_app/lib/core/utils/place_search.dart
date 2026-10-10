import "package:dio/dio.dart";
import "package:latlong2/latlong.dart" as ll;

import "../geo/service_area.dart";
import "geocoding.dart";

/// Search-as-you-type place lookup via Photon (Komoot's free OSM-based
/// geocoder). Nominatim — already used elsewhere for reverse-geocoding —
/// only reliably matches complete or near-complete words, so it can't
/// power live per-letter suggestions; Photon is built for exactly this and
/// needs no API key either.
const String _photonBaseUrl = "https://photon.komoot.io/api/";

/// Used only until the service area has loaded: Guiuan's boundary box,
/// islands included (the service area's own bbox replaces it).
const String _guiuanBbox = "125.6158,10.6877,125.9692,11.0859";

/// How many results to ask Photon for; some are dropped when they fall
/// outside Guiuan, and at most [_maxResults] are shown.
const int _fetchLimit = 15;
const int _maxResults = 8;

final Dio _searchClient = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: const {"User-Agent": kOsmUserAgent},
  ),
);

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.name,
    required this.secondaryLabel,
    required this.lat,
    required this.lng,
    String? fullLabel,
    this.isArea = false,
  }) : fullLabel = fullLabel ?? name;

  final String name;
  final String secondaryLabel;
  final double lat;
  final double lng;

  /// The whole address, e.g. "Guiuan Church, Brgy. Poblacion Ward 10,
  /// Guiuan, Eastern Samar" — what a pickup/drop-off is saved as.
  final String fullLabel;

  /// A barangay, sitio or town rather than a specific spot in one.
  final bool isArea;
}

/// Only the suggestions inside Guiuan (with the service area's buffer).
List<PlaceSuggestion> keepInsideServiceArea(
    List<PlaceSuggestion> suggestions, ServiceArea area) {
  return suggestions
      .where((s) => area.contains(ll.LatLng(s.lat, s.lng)))
      .toList();
}

/// Returns place suggestions inside Guiuan matching [query], or an empty
/// list if the query is blank, nothing in Guiuan matches, or the request
/// fails — callers should treat all of these the same way.
Future<List<PlaceSuggestion>> searchPlaces(String query,
    {ServiceArea? area}) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return [];

  final center = area?.center ?? kGuiuanCenter;
  try {
    final response = await _searchClient.get(
      _photonBaseUrl,
      queryParameters: {
        "q": trimmed,
        "bbox": area?.photonBbox ?? _guiuanBbox,
        // Rank places near the town proper first.
        "lat": center.latitude,
        "lon": center.longitude,
        "limit": _fetchLimit,
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

      final place = parsePhotonPlace(props, fallbackTown: kServiceAreaTown);
      final fullLabel = place?.format(fallbackTown: kServiceAreaTown) ?? name;
      // Under the name, the rest of the address ("Brgy. Salug, Guiuan,
      // Eastern Samar"); a barangay keeps its own "Brgy." line.
      final secondaryLabel = fullLabel.startsWith("$name, ")
          ? fullLabel.substring(name.length + 2)
          : fullLabel == name
              ? ""
              : fullLabel;

      suggestions.add(PlaceSuggestion(
        name: name,
        secondaryLabel: secondaryLabel,
        lat: lat,
        lng: lng,
        fullLabel: fullLabel,
        isArea: props["osm_key"] == "place" || props["osm_key"] == "boundary",
      ));
    }
    // The bbox is a rectangle; the boundary is what counts.
    final inside =
        area == null ? suggestions : keepInsideServiceArea(suggestions, area);
    return inside.take(_maxResults).toList();
  } catch (_) {
    return [];
  }
}
