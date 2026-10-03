import "dart:math" as math;

import "package:latlong2/latlong.dart" as ll;

/// Guiuan's town proper — where maps open before anything else is known.
const ll.LatLng kGuiuanCenter = ll.LatLng(11.03162, 125.72364);

/// FindMeTricycle's service area: Guiuan's municipal boundary (mainland and
/// every island) plus the map limits, as served by GET /api/service-area
/// (backend/data/service-area is the source of truth). The server checks
/// bookings too; the app uses this so passengers learn early.
class ServiceArea {
  ServiceArea({
    required this.version,
    required this.enforced,
    required this.bufferMeters,
    required this.polygons,
    required this.bbox,
    required this.mapBounds,
    required this.center,
    required this.minZoom,
    required this.maxZoom,
    required this.defaultZoom,
    required this.raw,
  });

  final String version;

  /// Mirrors the backend's GEOFENCE_ENABLED: when false (testing from
  /// outside Guiuan) the app shows the boundary but doesn't block anything.
  final bool enforced;
  final double bufferMeters;

  /// Polygons → rings → [lng, lat] points; the first ring is the outline,
  /// any others are holes.
  final List<List<List<List<double>>>> polygons;

  /// [minLng, minLat, maxLng, maxLat] of the boundary.
  final List<double> bbox;

  /// [bbox] with some room around it: how far the camera may go.
  final List<double> mapBounds;
  final ll.LatLng center;
  final double minZoom;
  final double maxZoom;
  final double defaultZoom;

  /// The API payload, for caching.
  final Map<String, dynamic> raw;

  static const String outsideMessage =
      "This location is outside Guiuan. FindMeTricycle only operates within Guiuan.";

  static ServiceArea? tryParse(Map<String, dynamic>? json) {
    try {
      return json == null ? null : ServiceArea.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  factory ServiceArea.fromJson(Map<String, dynamic> json) {
    final geometry = (json["boundary"] as Map)["geometry"] as Map;
    if (geometry["type"] != "MultiPolygon") {
      throw const FormatException("Service area must be a MultiPolygon.");
    }
    final polygons = [
      for (final polygon in geometry["coordinates"] as List)
        [
          for (final ring in polygon as List)
            [
              for (final point in ring as List)
                [
                  ((point as List)[0] as num).toDouble(),
                  (point[1] as num).toDouble(),
                ],
            ],
        ],
    ];
    List<double> numbers(dynamic list) =>
        [for (final n in list as List) (n as num).toDouble()];
    final center = json["center"] as Map;
    return ServiceArea(
      version: json["version"]?.toString() ?? "",
      enforced: json["enforced"] == true,
      bufferMeters: (json["bufferMeters"] as num?)?.toDouble() ?? 300,
      polygons: polygons,
      bbox: numbers(json["bbox"]),
      mapBounds: numbers(json["mapBounds"]),
      center: ll.LatLng(
        (center["lat"] as num).toDouble(),
        (center["lng"] as num).toDouble(),
      ),
      minZoom: (json["minZoom"] as num?)?.toDouble() ?? 9.5,
      maxZoom: (json["maxZoom"] as num?)?.toDouble() ?? 19,
      defaultZoom: (json["defaultZoom"] as num?)?.toDouble() ?? 14,
      raw: json,
    );
  }

  /// Whether the point is inside Guiuan, counting points within
  /// [bufferMeters] of the boundary (GPS error near borders and coasts).
  bool contains(ll.LatLng point, {double? bufferMeters}) {
    final lat = point.latitude;
    final lng = point.longitude;
    if (!lat.isFinite || !lng.isFinite) return false;
    final buffer = bufferMeters ?? this.bufferMeters;
    final pad = buffer / 100000;
    if (lng < bbox[0] - pad ||
        lng > bbox[2] + pad ||
        lat < bbox[1] - pad ||
        lat > bbox[3] + pad) {
      return false;
    }
    for (final polygon in polygons) {
      if (_inRing(lng, lat, polygon.first) &&
          !polygon.skip(1).any((hole) => _inRing(lng, lat, hole))) {
        return true;
      }
    }
    return buffer > 0 && distanceToBoundaryMeters(point) <= buffer;
  }

  /// True when the app must refuse this point as a pickup or drop-off.
  bool blocks(ll.LatLng point) => enforced && !contains(point);

  /// Shortest distance (metres) from the point to the boundary.
  double distanceToBoundaryMeters(ll.LatLng point) {
    final kx = 111320 * math.cos(point.latitude * math.pi / 180);
    const ky = 110540.0;
    var best = double.infinity;
    for (final polygon in polygons) {
      for (final ring in polygon) {
        for (var i = 1; i < ring.length; i++) {
          final ax = (ring[i - 1][0] - point.longitude) * kx;
          final ay = (ring[i - 1][1] - point.latitude) * ky;
          final bx = (ring[i][0] - point.longitude) * kx;
          final by = (ring[i][1] - point.latitude) * ky;
          final dx = bx - ax;
          final dy = by - ay;
          final lengthSq = dx * dx + dy * dy;
          final t = lengthSq == 0
              ? 0.0
              : (-(ax * dx + ay * dy) / lengthSq).clamp(0.0, 1.0);
          final d = math.sqrt(math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2));
          if (d < best) best = d;
        }
      }
    }
    return best;
  }

  /// Photon's `bbox` parameter: "minLng,minLat,maxLng,maxLat", rounded
  /// outwards so no edge of Guiuan is cut off.
  String get photonBbox {
    String down(double n) => ((n * 10000).floor() / 10000).toStringAsFixed(4);
    String up(double n) => ((n * 10000).ceil() / 10000).toStringAsFixed(4);
    return [down(bbox[0]), down(bbox[1]), up(bbox[2]), up(bbox[3])].join(",");
  }

  /// Everything outside Guiuan as one polygon (the world with Guiuan's
  /// outlines cut out) — drawn dimmed so the service area stands out.
  Map<String, dynamic> get outsideMaskGeoJson => {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": <String, dynamic>{},
            "geometry": {
              "type": "Polygon",
              "coordinates": [
                [
                  [-179.9, -85.0],
                  [179.9, -85.0],
                  [179.9, 85.0],
                  [-179.9, 85.0],
                  [-179.9, -85.0],
                ],
                for (final polygon in polygons) polygon.first,
              ],
            },
          },
        ],
      };

  /// The boundary itself, for an outline.
  Map<String, dynamic> get outlineGeoJson => {
        "type": "FeatureCollection",
        "features": [raw["boundary"]],
      };

  static bool _inRing(double lng, double lat, List<List<double>> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i][0], yi = ring[i][1];
      final xj = ring[j][0], yj = ring[j][1];
      if ((yi > lat) != (yj > lat) &&
          lng < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }
}
