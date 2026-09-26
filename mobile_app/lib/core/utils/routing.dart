import "package:dio/dio.dart";
import "package:latlong2/latlong.dart" as ll;

/// On-device road-network routing via OSRM (Open Source Routing Machine) —
/// the same OSM road data this app already renders as map tiles and uses
/// for reverse geocoding, so no new API key or backend service is needed.
/// `router.project-osrm.org` is OSRM's shared public demo instance: fine
/// for building/testing, but has no uptime guarantee — a self-hosted OSRM
/// instance would be worth setting up for reliable production use.
///
/// OSRM's public demo only exposes generic `driving`/`walking`/`cycling`
/// profiles — there is no dedicated tricycle profile, so `driving` is used
/// as the closest approximation, not a guarantee of tricycle-legal access.
const String _osrmBaseUrl = "https://router.project-osrm.org";

/// Reject a tapped point if the nearest road is farther than this —
/// generous enough for sparser rural road spacing while still refusing
/// taps in open fields, water, or building interiors with no nearby road.
const double _maxSnapDistanceMeters = 120;

final Dio _routingClient = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ),
);

class RouteResult {
  const RouteResult({required this.points, required this.distanceKm});

  final List<ll.LatLng> points;
  final double distanceKm;
}

/// Snaps a tapped point to the nearest road, or returns null if the OSRM
/// service *confirmed* there's no road close enough — callers should treat
/// null as "reject this tap".
///
/// If the routing service itself couldn't be reached (network error,
/// timeout, unexpected response) this deliberately fails *open*: it returns
/// the original tapped point unchanged rather than null. The public OSRM
/// demo instance has no uptime guarantee, and rejecting every tap whenever
/// that one third-party service hiccups — even taps that are genuinely on a
/// road, as shown on the map itself — is worse than skipping the check for
/// that one request.
Future<ll.LatLng?> snapToRoad(ll.LatLng point) async {
  try {
    final response = await _routingClient.get(
      "$_osrmBaseUrl/nearest/v1/driving/${point.longitude},${point.latitude}",
      queryParameters: {"number": 1},
    );

    final data = response.data;
    if (data is! Map || data["code"] != "Ok") return point;

    final waypoints = data["waypoints"];
    if (waypoints is! List || waypoints.isEmpty) return point;

    final waypoint = waypoints.first;
    if (waypoint is! Map) return point;

    final distance = (waypoint["distance"] as num?)?.toDouble();
    if (distance == null) return point;
    if (distance > _maxSnapDistanceMeters) return null;

    final location = waypoint["location"];
    if (location is! List || location.length < 2) return point;

    final lng = (location[0] as num).toDouble();
    final lat = (location[1] as num).toDouble();
    return ll.LatLng(lat, lng);
  } catch (_) {
    return point;
  }
}

/// Fetches a real road-following route between two points, or null if the
/// request fails — callers should fall back to a straight line in that case.
Future<RouteResult?> fetchRoute(ll.LatLng from, ll.LatLng to) async {
  try {
    final response = await _routingClient.get(
      "$_osrmBaseUrl/route/v1/driving/"
      "${from.longitude},${from.latitude};${to.longitude},${to.latitude}",
      queryParameters: {"geometries": "geojson", "overview": "full"},
    );

    final data = response.data;
    if (data is! Map || data["code"] != "Ok") return null;

    final routes = data["routes"];
    if (routes is! List || routes.isEmpty) return null;

    final route = routes.first;
    if (route is! Map) return null;

    final geometry = route["geometry"];
    if (geometry is! Map) return null;

    final coordinates = geometry["coordinates"];
    if (coordinates is! List || coordinates.isEmpty) return null;

    final points = <ll.LatLng>[];
    for (final coordinate in coordinates) {
      if (coordinate is! List || coordinate.length < 2) continue;
      final lng = (coordinate[0] as num).toDouble();
      final lat = (coordinate[1] as num).toDouble();
      points.add(ll.LatLng(lat, lng));
    }
    if (points.isEmpty) return null;

    final distanceMeters = (route["distance"] as num?)?.toDouble() ?? 0;
    return RouteResult(points: points, distanceKm: distanceMeters / 1000);
  } catch (_) {
    return null;
  }
}
