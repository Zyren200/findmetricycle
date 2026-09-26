import "dart:async";
import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart" as ll;
import "../../../core/config/app_config.dart";
import "../../../core/network/socket_client.dart";
import "../../../core/utils/geo_utils.dart";
import "../../../core/utils/geocoding.dart";
import "../../../core/utils/place_search.dart";
import "../../../core/utils/routing.dart" as routing;
import "../repositories/passenger_repository.dart";

/// Backend booking-status enum (backend/src/constants/booking-status.js),
/// grouped for the passenger UI: statuses before a trip is actually under
/// way (pickup still selectable / cancel still allowed) vs. in progress.
const List<String> kPreTripBookingStatuses = [
  "pending",
  "searching",
  "accepted",
  "assigned",
  "arriving",
];
const List<String> kInProgressBookingStatuses = ["ongoing", "on_ride"];
const List<String> kActiveBookingStatuses = [
  ...kPreTripBookingStatuses,
  ...kInProgressBookingStatuses,
];

const Map<String, String> kBookingStatusLabels = {
  "pending": "Requested",
  "searching": "Searching for a driver",
  "accepted": "Driver Assigned",
  "assigned": "Driver Assigned",
  "arriving": "Driver Arriving",
  "ongoing": "Trip Started",
  "on_ride": "Trip Started",
  "completed": "Completed",
  "cancelled": "Cancelled",
};

String bookingStatusLabel(String? status) {
  if (status == null) return "-";
  return kBookingStatusLabels[status] ?? status;
}

class PassengerRideController extends ChangeNotifier {
  PassengerRideController(
    this._repository,
    this._socketClient,
  );

  final PassengerRepository _repository;
  final SocketClient _socketClient;

  bool isInitializing = false;
  bool isSubmittingRide = false;
  bool isCompletingAction = false;

  bool isLoadingHistory = false;
  String? historyError;
  List<Map<String, dynamic>> bookingHistory = [];

  Future<void> loadBookingHistory() async {
    isLoadingHistory = true;
    historyError = null;
    notifyListeners();

    try {
      final response = await _repository.getBookingHistory();
      final data = response["data"] as List?;
      bookingHistory =
          (data ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      historyError = "Failed to load ride history.";
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  ll.LatLng? currentPosition;
  ll.LatLng? pickup;
  ll.LatLng? dropoff;
  ll.LatLng? driverPosition;
  Map<String, dynamic>? driverInfo;

  String? pickupAddress;
  String? dropoffAddress;
  bool isResolvingPickupAddress = false;
  bool isResolvingDropoffAddress = false;
  int _pickupAddressToken = 0;
  int _dropoffAddressToken = 0;

  List<ll.LatLng>? routePolyline;
  double? routeDistanceKm;
  bool isValidatingTap = false;
  bool isLoadingRoute = false;
  int _routeRequestToken = 0;

  int? activeBookingId;
  String? bookingStatus;
  Map<String, dynamic>? bookingData;
  // Shown to the passenger to read out to the driver at pickup; the
  // backend only ever sends the plaintext PIN once, right when the
  // booking is created (it stores a hash after that).
  String? pickupPin;
  String? error;
  List<Map<String, dynamic>> nearbyDrivers = [];

  /// Short status line for the choose-a-rider flow ("waiting for rider",
  /// "rider declined", ...), shown in the ride panel.
  String? rideNotice;

  /// Bumped whenever the rider picker should (re)open on its own — e.g. the
  /// chosen rider declined or didn't answer. The map page listens for it.
  int driverPickerRequest = 0;

  bool isRefreshingDrivers = false;
  Timer? _nearbyRefreshTimer;

  /// Booking exists but no rider has been picked yet.
  bool get isChoosingDriver =>
      activeBookingId != null &&
      bookingStatus == "pending" &&
      (driverInfo == null || driverInfo!["id"] == null);

  /// A rider was picked and we're waiting for them to accept.
  bool get isWaitingForDriverResponse =>
      activeBookingId != null &&
      bookingStatus == "pending" &&
      driverInfo?["id"] != null;

  StreamSubscription? _bookingUpdateSub;
  StreamSubscription? _driverLocationSub;
  StreamSubscription? _driverArrivedSub;
  StreamSubscription? _rideStartedSub;
  StreamSubscription? _rideCompletedSub;

  double get estimatedDistanceKm {
    if (pickup == null || dropoff == null) return 0;
    if (routeDistanceKm != null) return routeDistanceKm!;
    return haversineKm(
      lat1: pickup!.latitude,
      lng1: pickup!.longitude,
      lat2: dropoff!.latitude,
      lng2: dropoff!.longitude,
    );
  }

  double _baseFare = AppConfig.defaultBaseFare;
  double _perKmRate = AppConfig.defaultPerKmRate;
  double _additionalPassengerFee = 0;

  static const int minPassengers = 1;
  static const int maxPassengers = 5;

  int _passengerCount = 1;
  int get passengerCount => _passengerCount;

  void setPassengerCount(int count) {
    final clamped = count.clamp(minPassengers, maxPassengers);
    if (clamped == _passengerCount) return;
    _passengerCount = clamped;
    notifyListeners();
  }

  double get estimatedFare {
    return calculateFare(
      distanceKm: estimatedDistanceKm,
      baseFare: _baseFare,
      perKmRate: _perKmRate,
      passengerCount: _passengerCount,
      additionalPassengerFee: _additionalPassengerFee,
    );
  }

  Future<void> _loadFareSettings() async {
    try {
      final response = await _repository.getFareSettings();
      final fare = response["data"] as Map<String, dynamic>?;
      if (fare == null) return;
      final base = double.tryParse(fare["base_fare"]?.toString() ?? "");
      final perKm = double.tryParse(fare["per_km_rate"]?.toString() ?? "");
      final additionalFee =
          double.tryParse(fare["additional_passenger_fee"]?.toString() ?? "");
      if (base != null) _baseFare = base;
      if (perKm != null) _perKmRate = perKm;
      if (additionalFee != null) _additionalPassengerFee = additionalFee;
    } catch (_) {
      // Keep the AppConfig defaults if the fare endpoint is unreachable.
    }
  }

  double? get driverDistanceToPickupKm {
    final distanceFromInfo = double.tryParse(
      driverInfo?["distanceToPickupKm"]?.toString() ?? "",
    );
    if (distanceFromInfo != null) return distanceFromInfo;

    if (driverPosition != null && pickup != null) {
      return haversineKm(
        lat1: driverPosition!.latitude,
        lng1: driverPosition!.longitude,
        lat2: pickup!.latitude,
        lng2: pickup!.longitude,
      );
    }
    return null;
  }

  String? get driverName =>
      driverInfo?["full_name"] ??
      driverInfo?["fullName"] ??
      driverInfo?["driver_name"];
  String? get driverTricycle =>
      driverInfo?["tricycle_number"] ?? driverInfo?["tricycleNumber"];
  double? get driverRating {
    final r = double.tryParse(
      driverInfo?["rating"]?.toString() ??
          driverInfo?["rating_avg"]?.toString() ??
          driverInfo?["driver_rating"]?.toString() ??
          "",
    );
    if (r == null) return null;
    return double.parse(r.toStringAsFixed(2));
  }

  bool get hasCompletedBooking => bookingStatus == "completed";
  bool get canRateRide => hasCompletedBooking;

  final Map<int, Map<String, dynamic>> liveDrivers = {};

  // Whether the OS permanently denied location access ("Deny" + "Don't ask
  // again" on Android, or repeated denial on iOS) — the OS won't show its
  // permission dialog again in this case, so the UI needs to send the user
  // to Settings instead of retrying `requestPermission()`.
  bool locationPermissionDeniedForever = false;
  bool isResolvingLocation = false;

  Future<void> initialize() async {
    if (isInitializing) return;

    isInitializing = true;
    error = null;
    notifyListeners();

    try {
      await _resolveCurrentLocation();
      _bindSocketEvents();
      await _loadFareSettings();
    } catch (e) {
      error = e.toString();
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  /// Re-checks/requests location permission and gets a fresh fix. Exposed
  /// separately from [initialize] so the map screen can retry after the
  /// user grants permission or enables GPS without re-running the rest of
  /// the passenger session bootstrap.
  Future<void> refreshCurrentLocation() async {
    error = null;
    notifyListeners();
    try {
      await _resolveCurrentLocation();
    } catch (e) {
      error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> _resolveCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Please enable GPS to show your current location.");
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    locationPermissionDeniedForever =
        permission == LocationPermission.deniedForever;
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw Exception(
          "Location permission denied. Enable it in Settings to see your location on the map.");
    }

    isResolvingLocation = true;
    notifyListeners();

    // Show an approximate fix instantly (cached by the OS) so the map
    // doesn't sit on the Manila fallback while we wait for a fresh GPS lock.
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && currentPosition == null) {
        currentPosition = ll.LatLng(lastKnown.latitude, lastKnown.longitude);
        pickup ??= currentPosition;
        notifyListeners();
      }
    } catch (_) {
      // Best-effort only; fall through to the accurate fix below.
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      currentPosition = ll.LatLng(pos.latitude, pos.longitude);
      pickup ??= currentPosition;
    } finally {
      isResolvingLocation = false;
      notifyListeners();
    }
    if (pickup != null) _resolveAddress(isPickup: true, point: pickup!);
  }

  /// Reverse-geocodes a pickup/drop-off point into a short address for
  /// display, replacing the raw-coordinates fallback once resolved. Guarded
  /// by a request token so an earlier, still-in-flight lookup can't clobber
  /// a newer selection if the user taps the map again before it returns.
  Future<void> _resolveAddress({
    required bool isPickup,
    required ll.LatLng point,
  }) async {
    final token = isPickup ? ++_pickupAddressToken : ++_dropoffAddressToken;
    if (isPickup) {
      isResolvingPickupAddress = true;
    } else {
      isResolvingDropoffAddress = true;
    }
    notifyListeners();

    final address = await reverseGeocode(point.latitude, point.longitude);
    final currentToken = isPickup ? _pickupAddressToken : _dropoffAddressToken;
    if (token != currentToken) return;

    if (isPickup) {
      pickupAddress = address;
      isResolvingPickupAddress = false;
    } else {
      dropoffAddress = address;
      isResolvingDropoffAddress = false;
    }
    notifyListeners();
  }

  /// Fetches a real road-following route once both pickup and drop-off are
  /// set, replacing the straight-line fallback used while it loads. Guarded
  /// by a request token so a stale response can't overwrite a newer trip.
  Future<void> _fetchRouteIfReady() async {
    final from = pickup;
    final to = dropoff;
    if (from == null || to == null) return;

    final token = ++_routeRequestToken;
    isLoadingRoute = true;
    notifyListeners();

    final result = await routing.fetchRoute(from, to);
    if (token != _routeRequestToken) return;

    routePolyline = result?.points;
    routeDistanceKm = result?.distanceKm;
    isLoadingRoute = false;
    notifyListeners();
  }

  /// Prefill pickup/destination from a saved favorite place, resetting any
  /// stale active-booking state so the map is ready for a fresh request.
  void setDestinationFromFavorite(ll.LatLng destination, {String? address}) {
    pickup ??= currentPosition;
    dropoff = destination;
    dropoffAddress = address;
    routePolyline = null;
    routeDistanceKm = null;
    driverPosition = null;
    activeBookingId = null;
    bookingStatus = null;
    bookingData = null;
    pickupPin = null;
    nearbyDrivers = [];
    driverInfo = null;
    notifyListeners();
    if (address == null) {
      _resolveAddress(isPickup: false, point: destination);
    }
    if (pickup != null) _resolveAddress(isPickup: true, point: pickup!);
    _fetchRouteIfReady();
  }

  /// Resolves a searched place to a usable point: snap it to the nearest
  /// road for route accuracy when possible, but — unlike a raw map tap —
  /// never reject it outright. A search result is a real named place from
  /// OSM the user explicitly picked, not an arbitrary point in open space,
  /// so a poor/failed snap just falls back to the geocoded coordinate.
  Future<ll.LatLng> _resolveSearchPoint(PlaceSuggestion place) async {
    final raw = ll.LatLng(place.lat, place.lng);
    final snapped = await routing.snapToRoad(raw);
    return snapped ?? raw;
  }

  /// Set pickup from a typed/selected search result instead of a map tap.
  Future<void> setPickupFromSearch(PlaceSuggestion place) async {
    if (activeBookingId != null &&
        bookingStatus != null &&
        kActiveBookingStatuses.contains(bookingStatus)) {
      return;
    }

    final point = await _resolveSearchPoint(place);
    pickup = point;
    pickupAddress = place.name;
    dropoff = null;
    dropoffAddress = null;
    routePolyline = null;
    routeDistanceKm = null;
    driverPosition = null;
    activeBookingId = null;
    bookingStatus = null;
    bookingData = null;
    pickupPin = null;
    nearbyDrivers = [];
    driverInfo = null;
    notifyListeners();
  }

  /// Set drop-off from a typed/selected search result instead of a map tap.
  Future<void> setDropoffFromSearch(PlaceSuggestion place) async {
    if (activeBookingId != null &&
        bookingStatus != null &&
        kActiveBookingStatuses.contains(bookingStatus)) {
      return;
    }

    final point = await _resolveSearchPoint(place);
    pickup ??= currentPosition;
    dropoff = point;
    dropoffAddress = place.name;
    notifyListeners();
    _fetchRouteIfReady();
  }

  /// Validates a tapped point against the real road network before
  /// accepting it as pickup/drop-off — rejects taps that land nowhere near
  /// a road (open fields, water, building interiors) instead of silently
  /// allowing an unreachable point.
  Future<void> selectOnMap(ll.LatLng rawLocation) async {
    if (activeBookingId != null &&
        bookingStatus != null &&
        kActiveBookingStatuses.contains(bookingStatus)) {
      return;
    }

    isValidatingTap = true;
    error = null;
    notifyListeners();

    final snapped = await routing.snapToRoad(rawLocation);
    isValidatingTap = false;

    if (snapped == null) {
      error = "Please select a spot near a road.";
      notifyListeners();
      return;
    }

    if (pickup == null || (pickup != null && dropoff != null)) {
      pickup = snapped;
      pickupAddress = null;
      dropoff = null;
      dropoffAddress = null;
      routePolyline = null;
      routeDistanceKm = null;
      driverPosition = null;
      activeBookingId = null;
      bookingStatus = null;
      bookingData = null;
      pickupPin = null;
      nearbyDrivers = [];
      driverInfo = null;
      notifyListeners();
      _resolveAddress(isPickup: true, point: snapped);
    } else {
      dropoff = snapped;
      dropoffAddress = null;
      notifyListeners();
      _resolveAddress(isPickup: false, point: snapped);
      _fetchRouteIfReady();
    }
  }

  Future<void> findRide() async {
    if (pickup == null || dropoff == null) return;

    isSubmittingRide = true;
    error = null;
    notifyListeners();

    try {
      final pickupLabel =
          "${pickup!.latitude.toStringAsFixed(5)}, ${pickup!.longitude.toStringAsFixed(5)}";
      final dropoffLabel =
          "${dropoff!.latitude.toStringAsFixed(5)}, ${dropoff!.longitude.toStringAsFixed(5)}";
      final response = await _repository.findRide(
        pickupAddress: pickupLabel,
        pickupLat: pickup!.latitude,
        pickupLng: pickup!.longitude,
        dropoffAddress: dropoffLabel,
        dropoffLat: dropoff!.latitude,
        dropoffLng: dropoff!.longitude,
        passengerCount: _passengerCount,
        autoAssign: false,
      );

      final success = response["success"] == true;
      if (!success) {
        throw Exception(
            response["message"]?.toString() ?? "Failed to find ride.");
      }

      final data = _toMap(response["data"]);
      final booking = _toMap(data["booking"]);
      activeBookingId = int.tryParse(booking["id"]?.toString() ?? "");
      bookingStatus = booking["status"]?.toString() ?? "pending";
      bookingData = booking;
      pickupPin = data["pickupPin"]?.toString() ?? pickupPin;
      nearbyDrivers = _toDriverList(data["nearbyDrivers"]);

      // An existing booking may already have a rider attached.
      final matched = _toMap(data["matchedDriver"]);
      driverInfo = matched["id"] != null ? matched : null;
      driverPosition = _pointOf(driverInfo);

      if (isChoosingDriver) {
        rideNotice = nearbyDrivers.isEmpty
            ? "Walang online na rider sa malapit ngayon. Patuloy kaming naghahanap…"
            : "Pumili ng rider mula sa listahan.";
        _startNearbyRefresh();
      } else if (isWaitingForDriverResponse) {
        rideNotice = "Hinihintay ang sagot ng rider…";
      }
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
    } finally {
      isSubmittingRide = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _toDriverList(dynamic raw) {
    return (raw is List ? raw : const [])
        .map((e) => _toMap(e))
        .where((d) => d["id"] != null)
        .toList();
  }

  ll.LatLng? _pointOf(Map<String, dynamic>? driver) {
    final lat = double.tryParse(driver?["current_lat"]?.toString() ?? "");
    final lng = double.tryParse(driver?["current_lng"]?.toString() ?? "");
    if (lat == null || lng == null) return null;
    return ll.LatLng(lat, lng);
  }

  /// Keeps the rider list current while the passenger is choosing: riders
  /// come online, move, or get taken by someone else.
  void _startNearbyRefresh() {
    _nearbyRefreshTimer?.cancel();
    _nearbyRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => refreshNearbyDrivers(),
    );
  }

  void _stopNearbyRefresh() {
    _nearbyRefreshTimer?.cancel();
    _nearbyRefreshTimer = null;
  }

  Future<void> refreshNearbyDrivers() async {
    final bookingId = activeBookingId;
    if (bookingId == null || !isChoosingDriver) {
      _stopNearbyRefresh();
      return;
    }
    if (isRefreshingDrivers) return;

    isRefreshingDrivers = true;
    notifyListeners();
    try {
      final response = await _repository.getNearbyDrivers(bookingId);
      if (response["success"] != true || bookingId != activeBookingId) return;
      final data = _toMap(response["data"]);
      final booking = _toMap(data["booking"]);
      final status = booking["status"]?.toString();
      if (status != null && status != "pending") {
        // Accepted/cancelled elsewhere — stop offering riders.
        bookingStatus = status;
        bookingData = booking;
        nearbyDrivers = [];
        _stopNearbyRefresh();
        return;
      }
      if (!isChoosingDriver) return;
      nearbyDrivers = _toDriverList(data["nearbyDrivers"]);
      rideNotice = nearbyDrivers.isEmpty
          ? "Walang online na rider sa malapit ngayon. Patuloy kaming naghahanap…"
          : "Pumili ng rider mula sa listahan.";
    } catch (_) {
      // Best-effort; the next tick retries.
    } finally {
      isRefreshingDrivers = false;
      notifyListeners();
    }
  }

  bool isSendingSos = false;
  String? sosMessage;

  Future<bool> sendSos({String? message}) async {
    isSendingSos = true;
    error = null;
    sosMessage = null;
    notifyListeners();

    try {
      final response = await _repository.triggerSos(
        bookingId: activeBookingId,
        lat: pickup?.latitude ?? currentPosition?.latitude,
        lng: pickup?.longitude ?? currentPosition?.longitude,
        message: message,
      );

      final success = response["success"] == true;
      if (!success) {
        throw Exception(response["message"]?.toString() ?? "Failed to send SOS alert.");
      }

      sosMessage = "SOS alert sent. Admin has been notified.";
      return true;
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      isSendingSos = false;
      notifyListeners();
    }
  }

  Future<void> chooseDriver(int driverId) async {
    if (activeBookingId == null) return;
    isSubmittingRide = true;
    error = null;
    notifyListeners();
    try {
      final response = await _repository.chooseDriver(
        bookingId: activeBookingId!,
        driverId: driverId,
      );
      if (response["success"] != true) {
        // Usually "rider no longer available" — refresh so they can pick again.
        error = response["message"]?.toString() ?? "Failed to choose rider.";
        unawaited(refreshNearbyDrivers());
        return;
      }

      final data = _toMap(response["data"]);
      final booking = _toMap(data["booking"]);
      bookingStatus = booking["status"]?.toString() ?? bookingStatus;
      bookingData = booking;
      driverInfo = _toMap(data["driver"]);
      driverPosition = _pointOf(driverInfo);
      nearbyDrivers = [];
      _stopNearbyRefresh();
      rideNotice =
          "Naipadala ang request kay ${driverName ?? "rider"}. Hinihintay ang sagot…";
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
    } finally {
      isSubmittingRide = false;
      notifyListeners();
    }
  }

  Future<void> cancelRide() async {
    if (activeBookingId == null) return;
    isCompletingAction = true;
    error = null;
    notifyListeners();

    try {
      final response = await _repository.cancelBooking(activeBookingId!);
      final success = response["success"] == true;
      if (!success) {
        throw Exception(
            response["message"]?.toString() ?? "Failed to cancel ride.");
      }

      bookingStatus = "cancelled";
      bookingData = response["data"] as Map<String, dynamic>?;
      driverPosition = null;
      driverInfo = null;
      nearbyDrivers = [];
      rideNotice = null;
      _stopNearbyRefresh();
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
    } finally {
      isCompletingAction = false;
      notifyListeners();
    }
  }

  void resetTripSelection() {
    if (bookingStatus != null &&
        kActiveBookingStatuses.contains(bookingStatus)) {
      return;
    }
    pickup = currentPosition;
    pickupAddress = null;
    dropoff = null;
    dropoffAddress = null;
    routePolyline = null;
    routeDistanceKm = null;
    driverPosition = null;
    activeBookingId = null;
    bookingStatus = null;
    bookingData = null;
    pickupPin = null;
    driverInfo = null;
    nearbyDrivers = [];
    rideNotice = null;
    _stopNearbyRefresh();
    _passengerCount = 1;
    notifyListeners();
    if (pickup != null) _resolveAddress(isPickup: true, point: pickup!);
  }

  StreamSubscription? _fareUpdateSub;

  void _bindSocketEvents() {
    _fareUpdateSub ??= _socketClient.on("passenger:fare_updated").listen((event) {
      final fare = _toMap(event);
      final base = double.tryParse(fare["base_fare"]?.toString() ?? "");
      final perKm = double.tryParse(fare["per_km_rate"]?.toString() ?? "");
      final additionalFee =
          double.tryParse(fare["additional_passenger_fee"]?.toString() ?? "");
      if (base != null) _baseFare = base;
      if (perKm != null) _perKmRate = perKm;
      if (additionalFee != null) _additionalPassengerFee = additionalFee;
      notifyListeners();
    });

    _bookingUpdateSub ??=
        _socketClient.on("passenger:booking_update").listen((event) {
      final payload = _toMap(event);
      final booking = _toMap(payload["booking"]);
      if (activeBookingId == null) return;

      final bookingId = int.tryParse(booking["id"]?.toString() ?? "");
      if (bookingId != activeBookingId) return;

      final status = booking["status"]?.toString() ?? bookingStatus;
      final reason = payload["reason"]?.toString();
      bookingStatus = status;
      bookingData = booking;

      if (status == "pending" && booking["driver_id"] == null) {
        // The rider we picked declined or let the request time out — the
        // server hands back a fresh list so the passenger can choose again.
        final previous = driverName;
        driverInfo = null;
        driverPosition = null;
        nearbyDrivers = _toDriverList(payload["nearbyDrivers"]);
        rideNotice = reason == "expired"
            ? "Hindi sumagot si ${previous ?? "ang rider"}. Pumili ng ibang rider."
            : "Hindi tinanggap ni ${previous ?? "ang rider"} ang request. Pumili ng ibang rider.";
        driverPickerRequest++;
        _startNearbyRefresh();
      } else {
        if (status == "accepted") {
          rideNotice = "Tinanggap ni ${driverName ?? "ang rider"} ang ride mo! Papunta na siya.";
        }
        // Rider details from the booking row, layered over what we already
        // know about the chosen rider. Only rider fields are copied — the
        // booking's own "id" must not overwrite the rider's id.
        final known = driverInfo ?? const <String, dynamic>{};
        driverInfo = {
          ...known,
          "id": booking["driver_id"] ?? known["id"],
          "full_name": booking["driver_name"] ?? known["full_name"],
          "tricycle_number":
              booking["tricycle_number"] ?? known["tricycle_number"],
          "rating": booking["driver_rating"] ?? known["rating"],
          "current_lat": booking["current_lat"] ?? known["current_lat"],
          "current_lng": booking["current_lng"] ?? known["current_lng"],
        };
        nearbyDrivers = [];
        _stopNearbyRefresh();
      }
      notifyListeners();
    });

    _driverLocationSub ??=
        _socketClient.on("passenger:driver_location").listen((event) {
      final payload = _toMap(event);
      final bookingId = int.tryParse(payload["bookingId"]?.toString() ?? "");
      if (activeBookingId == null || bookingId != activeBookingId) return;

      final lat = double.tryParse(payload["lat"]?.toString() ?? "");
      final lng = double.tryParse(payload["lng"]?.toString() ?? "");
      if (lat != null && lng != null) {
        driverPosition = ll.LatLng(lat, lng);
        notifyListeners();
      }
    });

    _socketClient.on("passenger:driver_ping").listen((event) {
      final payload = _toMap(event);
      final id = int.tryParse(payload["driverId"]?.toString() ?? "");
      final lat = double.tryParse(payload["lat"]?.toString() ?? "");
      final lng = double.tryParse(payload["lng"]?.toString() ?? "");
      if (id == null || lat == null || lng == null) return;
      liveDrivers[id] = {
        "id": id,
        "lat": lat,
        "lng": lng,
        "full_name": payload["fullName"],
        "tricycle_number": payload["tricycleNumber"],
        "rating": payload["rating"],
        "updatedAt": payload["updatedAt"],
      };
      notifyListeners();
    });

    _driverArrivedSub ??=
        _socketClient.on("passenger:driver_arrived").listen((event) {
      final payload = _toMap(event);
      final bookingId = int.tryParse(payload["bookingId"]?.toString() ?? "");
      if (activeBookingId == null || bookingId != activeBookingId) return;
      bookingStatus = "arriving";
      notifyListeners();
    });

    _rideStartedSub ??=
        _socketClient.on("passenger:ride_started").listen((event) {
      final payload = _toMap(event);
      final bookingId = int.tryParse(payload["bookingId"]?.toString() ?? "");
      if (activeBookingId == null || bookingId != activeBookingId) return;
      bookingStatus = "ongoing";
      notifyListeners();
    });

    _rideCompletedSub ??=
        _socketClient.on("passenger:ride_completed").listen((event) {
      final payload = _toMap(event);
      final bookingId = int.tryParse(payload["bookingId"]?.toString() ?? "");
      if (activeBookingId == null || bookingId != activeBookingId) return;
      bookingStatus = "completed";
      bookingData = {
        ...?bookingData,
        "final_fare": payload["finalFare"],
      };
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _stopNearbyRefresh();
    _fareUpdateSub?.cancel();
    _bookingUpdateSub?.cancel();
    _driverLocationSub?.cancel();
    _driverArrivedSub?.cancel();
    _rideStartedSub?.cancel();
    _rideCompletedSub?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _toMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }
}

