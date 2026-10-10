import "package:dio/dio.dart";

/// On-device reverse geocoding via OpenStreetMap's Nominatim service — the
/// standard free companion to the OpenFreeMap/OSM tiles this app already
/// uses for the map itself, so no new backend service or API key is needed.
/// Nominatim's usage policy requires a descriptive User-Agent and caps
/// public-instance traffic at roughly 1 request/second, so lookups are
/// spaced out and cached. When Nominatim fails, Photon (the OSM geocoder
/// behind place search) is tried instead.
final Dio _geocodingClient = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
    headers: const {"User-Agent": kOsmUserAgent, "Accept-Language": "en"},
  ),
);

/// Nominatim and Photon both answer 403 to Dart's default User-Agent.
const String kOsmUserAgent = "FindMeTricycle/1.0 (passenger app)";

/// The town every rural barangay in the service area belongs to. OSM maps
/// Guiuan's barangays without their municipality, so lookups there name
/// only the barangay and province unless this is filled in.
const String kServiceAreaTown = "Guiuan";

const Duration _minNominatimGap = Duration(milliseconds: 1100);
const int _cacheLimit = 100;

Future<void> _nominatimQueue = Future.value();
DateTime _lastNominatimCall = DateTime.fromMillisecondsSinceEpoch(0);

final Map<String, PlaceParts> _cache = {};
final Map<String, Future<PlaceParts?>> _inFlight = {};

/// A place broken into the parts people use to describe where they are:
/// "Guimbaolibot Avenue, Brgy. Poblacion Ward 9-A, Guiuan, Eastern Samar".
class PlaceParts {
  const PlaceParts({
    this.landmark,
    this.street,
    this.purok,
    this.barangay,
    this.town,
    this.province,
  });

  /// A named building or spot (school, store, terminal).
  final String? landmark;
  final String? street;

  /// Purok / sitio, when OSM has one mapped.
  final String? purok;
  final String? barangay;
  final String? town;
  final String? province;

  /// The full address, most specific part first, without repeats.
  String format({String? landmark, String? fallbackTown}) {
    final parts = <String>[];
    final seen = <String>{};
    void add(String? value, {String prefix = ""}) {
      final text = value?.trim();
      if (text == null || text.isEmpty) return;
      final key = _normalize(text);
      if (!seen.add(key)) return;
      parts.add(_hasBarangayPrefix(text) ? text : "$prefix$text");
    }

    add(landmark ?? this.landmark);
    add(street);
    add(purok);
    add(barangay, prefix: "Brgy. ");
    add(town ?? fallbackTown);
    add(province);
    return parts.join(", ");
  }

  bool get isEmpty => [landmark, street, purok, barangay, town, province]
      .every((value) => value == null || value.trim().isEmpty);
}

String _normalize(String text) => text
    .toLowerCase()
    .replaceFirst(RegExp(r"^(brgy\.?|barangay)\s+"), "")
    .trim();

bool _hasBarangayPrefix(String text) =>
    RegExp(r"^(brgy\.?|barangay)\s", caseSensitive: false).hasMatch(text);

String? _text(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

String? _first(Map address, List<String> keys) {
  for (final key in keys) {
    final value = _text(address[key]);
    if (value != null) return value;
  }
  return null;
}

const List<String> _landmarkKeys = [
  "amenity",
  "shop",
  "tourism",
  "leisure",
  "office",
  "building",
  "industrial",
  "commercial",
  "retail",
  "aeroway",
  "man_made",
  "historic",
];

/// Reads a Nominatim `jsonv2` reverse result. In the Philippines OSM tags
/// barangays as villages (or quarters/suburbs in a poblacion), puroks and
/// sitios as hamlets or neighbourhoods, and the province as the state.
PlaceParts? parseNominatimPlace(dynamic data) {
  if (data is! Map) return null;
  final address = data["address"];
  if (address is! Map) return null;

  var street = _first(address, ["road", "pedestrian", "footway", "path"]);
  final houseNumber = _text(address["house_number"]);
  if (street != null && houseNumber != null) street = "$houseNumber $street";

  // The point itself is a named spot unless it's just a road or an area
  // (barangay, town), which the other parts already name; failing that,
  // the named grounds it's in (a wharf, a school campus).
  final category = data["category"];
  final landmark = (const ["place", "boundary", "highway"].contains(category)
          ? null
          : _text(data["name"]) ?? _text(address[data["addresstype"]])) ??
      _first(address, _landmarkKeys);

  // Inside a rural barangay a "quarter" is one of its sitios; in the
  // poblacion, with no village around it, the quarter is the barangay.
  final village = _text(address["village"]);
  final quarter = _text(address["quarter"]);

  final parts = PlaceParts(
    landmark: landmark,
    street: street,
    purok: _first(address,
            ["hamlet", "neighbourhood", "isolated_dwelling", "croft"]) ??
        (village != null ? quarter : null),
    barangay:
        village ?? quarter ?? _first(address, ["suburb", "city_district"]),
    town: _first(address, ["town", "city", "municipality"]),
    province: _first(address, ["province", "state"]),
  );
  return parts.isEmpty ? null : parts;
}

/// Reads a Photon reverse/search feature's properties. Photon's fields are
/// coarser: a place feature is named by its own kind, and around Guiuan its
/// "city" is often the barangay rather than the town.
PlaceParts? parsePhotonPlace(dynamic props, {String? fallbackTown}) {
  if (props is! Map) return null;
  final name = _text(props["name"]);
  final kind = props["osm_key"] == "place" ? _text(props["osm_value"]) : null;

  String? barangay = _text(props["locality"]);
  String? town = _text(props["city"]);
  if (fallbackTown != null &&
      town != null &&
      _normalize(town) != _normalize(fallbackTown)) {
    barangay ??= town;
    town = null;
  }

  var street = _text(props["street"]);
  final houseNumber = _text(props["housenumber"]);
  if (street != null && houseNumber != null) street = "$houseNumber $street";

  final parts = PlaceParts(
    landmark: kind == null ? name : null,
    street: street,
    purok: const ["hamlet", "neighbourhood", "isolated_dwelling"].contains(kind)
        ? name
        : null,
    barangay:
        const ["village", "quarter", "suburb"].contains(kind) ? name : barangay,
    town: const ["town", "city", "municipality"].contains(kind) ? name : town,
    province: _text(props["state"]),
  );
  return parts.isEmpty ? null : parts;
}

Future<PlaceParts?> _lookupNominatim(double lat, double lng) {
  final result = _nominatimQueue.then((_) async {
    final wait =
        _lastNominatimCall.add(_minNominatimGap).difference(DateTime.now());
    if (wait > Duration.zero) await Future.delayed(wait);
    _lastNominatimCall = DateTime.now();

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
    return parseNominatimPlace(response.data);
  });
  _nominatimQueue = result.then((_) {}, onError: (_) {});
  return result;
}

Future<PlaceParts?> _lookupPhoton(double lat, double lng) async {
  final response = await _geocodingClient.get(
    "https://photon.komoot.io/reverse",
    queryParameters: {"lat": lat, "lon": lng, "limit": 1},
  );
  final data = response.data;
  final features = data is Map ? data["features"] : null;
  if (features is! List || features.isEmpty) return null;
  final feature = features.first;
  return parsePhotonPlace(feature is Map ? feature["properties"] : null,
      fallbackTown: kServiceAreaTown);
}

Future<PlaceParts?> _lookup(double lat, double lng) async {
  try {
    final place = await _lookupNominatim(lat, lng);
    if (place != null) return place;
  } catch (_) {
    // Rate-limited, offline or timed out — try Photon.
  }
  try {
    return await _lookupPhoton(lat, lng);
  } catch (_) {
    return null;
  }
}

/// The address parts at a point (cached, ~1 m precision), or null when
/// neither geocoder answers.
Future<PlaceParts?> reverseGeocodeParts(double lat, double lng) {
  final key = "${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}";
  final cached = _cache[key];
  if (cached != null) return Future.value(cached);
  return _inFlight[key] ??= _lookup(lat, lng).then((place) {
    _inFlight.remove(key);
    if (place != null) {
      if (_cache.length >= _cacheLimit) _cache.remove(_cache.keys.first);
      _cache[key] = place;
    }
    return place;
  });
}

/// Resolves a lat/lng into a readable address — landmark or street, purok,
/// barangay, town and province — or null if the lookup fails, so callers
/// can retry or fall back. [landmark] replaces the place's own name (e.g. a
/// searched place); [fallbackTown] fills in the town when OSM has none.
Future<String?> reverseGeocode(double lat, double lng,
    {String? landmark, String? fallbackTown}) async {
  final place = await reverseGeocodeParts(lat, lng);
  if (place == null) return null;
  final text = place.format(landmark: landmark, fallbackTown: fallbackTown);
  return text.isEmpty ? null : text;
}
