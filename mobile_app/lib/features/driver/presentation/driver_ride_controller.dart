import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_map/flutter_map.dart";
import "package:geolocator/geolocator.dart";
import "package:image_picker/image_picker.dart";
import "package:latlong2/latlong.dart" as ll;
import "../../../core/network/socket_client.dart";
import "../repositories/driver_repository.dart";

class DriverRideController extends ChangeNotifier {
  DriverRideController(this._repository, this._socketClient);

  final DriverRepository _repository;
  final SocketClient _socketClient;

  bool isInitializing = false;
  bool isProfileLoading = false;
  bool isSavingProfile = false;
  bool isOnline = false;
  bool isBusy = false;
  String? error;
  String? approvalMessage;

  /// Status that came with [approvalMessage] ("approved", "rejected",
  /// "needs_correction") so the banner can be titled/coloured to match —
  /// it used to say "Pending Approval" even for an approval.
  String? approvalStatus;

  void dismissApprovalMessage() {
    approvalMessage = null;
    approvalStatus = null;
    notifyListeners();
  }

  // Device/network status shown as GPS / Internet / Location Sharing pills
  // on the driver home screen, and enforced before allowing Online.
  bool gpsEnabled = false;
  bool locationPermissionGranted = false;
  bool hasInternet = true;
  Timer? _statusTimer;
  StreamSubscription<bool>? _connectionStatusSub;

  ll.LatLng? currentPosition;
  Map<String, dynamic>? incomingBooking;
  Map<String, dynamic>? activeBooking;
  Map<String, dynamic>? earningsSummary;
  Map<String, dynamic>? performanceStats;
  Map<String, dynamic>? driverProfile;
  List<Map<String, dynamic>> ratings = [];
  List<Map<String, dynamic>> completedRides = [];

  // ── Ride history (Rides tab) ───────────────────────────────────────
  static const int _historyPageSize = 20;
  List<Map<String, dynamic>> rideHistory = [];

  /// completed, cancelled, totalEarned, hasMore — across all trips.
  Map<String, dynamic> rideHistoryStats = {};
  bool isLoadingRideHistory = false;
  bool isLoadingMoreRideHistory = false;
  bool rideHistoryHasMore = false;
  String? rideHistoryError;

  /// Reloads the first page; the current list stays visible meanwhile.
  Future<void> loadRideHistory() async {
    if (isLoadingRideHistory) return;
    isLoadingRideHistory = true;
    rideHistoryError = null;
    notifyListeners();
    try {
      final response = await _repository.getRideHistory(limit: _historyPageSize);
      if (response["success"] != true) {
        throw Exception(response["message"]?.toString());
      }
      rideHistory = _toList(response["data"]);
      _applyRideHistoryMeta(response["meta"]);
    } catch (_) {
      rideHistoryError = "Hindi ma-load ang ride history. Subukan ulit.";
    } finally {
      isLoadingRideHistory = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreRideHistory() async {
    if (isLoadingMoreRideHistory || isLoadingRideHistory || !rideHistoryHasMore) return;
    isLoadingMoreRideHistory = true;
    notifyListeners();
    try {
      final response = await _repository.getRideHistory(
        limit: _historyPageSize,
        offset: rideHistory.length,
      );
      if (response["success"] == true) {
        final seen = rideHistory.map((r) => r["id"]).toSet();
        rideHistory = [
          ...rideHistory,
          ..._toList(response["data"]).where((r) => !seen.contains(r["id"])),
        ];
        _applyRideHistoryMeta(response["meta"]);
      }
    } catch (_) {
      // Keep what's loaded; the button stays for another try.
    } finally {
      isLoadingMoreRideHistory = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _toList(dynamic raw) =>
      (raw is List ? raw : const []).map((e) => _toMap(e)).toList();

  void _applyRideHistoryMeta(dynamic raw) {
    rideHistoryStats = _toMap(raw);
    rideHistoryHasMore = rideHistoryStats["hasMore"] == true;
  }

  Timer? _locationTimer;
  StreamSubscription? _bookingRequestSub;
  StreamSubscription? _bookingExpiredSub;
  StreamSubscription? _bookingCancelledSub;
  StreamSubscription? _approvalSub;
  StreamSubscription? _paymentReceivedSub;

  List<Polyline> get polylines {
    final pickup = pickupLocation;
    final dropoff = dropoffLocation;
    final driver = currentPosition;

    final lines = <Polyline>[];
    if (pickup != null && dropoff != null) {
      lines.add(
        Polyline(
          points: [pickup, dropoff],
          color: const Color(0xFF1C7D3D),
          strokeWidth: 5,
        ),
      );
    }
    if (driver != null && pickup != null) {
      lines.add(
        Polyline(
          points: [driver, pickup],
          color: const Color(0xFF205C37),
          strokeWidth: 4,
          isDotted: true,
        ),
      );
    }
    return lines;
  }

  ll.LatLng? get pickupLocation {
    final booking = activeBooking ?? incomingBooking;
    if (booking == null) return null;
    final lat = double.tryParse(booking["pickup_lat"]?.toString() ?? "");
    final lng = double.tryParse(booking["pickup_lng"]?.toString() ?? "");
    if (lat == null || lng == null) return null;
    return ll.LatLng(lat, lng);
  }

  ll.LatLng? get dropoffLocation {
    final booking = activeBooking ?? incomingBooking;
    if (booking == null) return null;
    final lat = double.tryParse(booking["dropoff_lat"]?.toString() ?? "");
    final lng = double.tryParse(booking["dropoff_lng"]?.toString() ?? "");
    if (lat == null || lng == null) return null;
    return ll.LatLng(lat, lng);
  }

  Future<void> initialize() async {
    if (isInitializing) return;
    isInitializing = true;
    error = null;
    notifyListeners();

    // Bind socket listeners before anything that can fail (GPS), or a
    // location error would leave the rider deaf to ride requests and
    // approval updates for the whole session.
    _bindSocketEvents();
    _startStatusPolling();
    // Profile (incl. approval status), earnings and stats come from the
    // server and must load even when GPS fails — otherwise an approved
    // rider was shown "Pending Approval" just because there was no fix.
    await Future.wait([
      refreshEarnings(notify: false),
      refreshProfile(notify: false),
      refreshPerformance(notify: false),
      _refreshDeviceStatus(),
      _resolveCurrentLocation().catchError((Object e) {
        error = e.toString().replaceFirst("Exception: ", "");
      }),
    ]);
    isInitializing = false;
    notifyListeners();
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshDeviceStatus(),
    );
  }

  Future<void> _refreshDeviceStatus() async {
    bool nextGpsEnabled;
    try {
      nextGpsEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      nextGpsEnabled = false;
    }

    bool nextPermissionGranted;
    try {
      final permission = await Geolocator.checkPermission();
      nextPermissionGranted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      nextPermissionGranted = false;
    }

    final nextHasInternet = await _checkInternet();

    final wasOnline = isOnline;
    final lostRequirement = wasOnline &&
        (!nextGpsEnabled || !nextPermissionGranted || !nextHasInternet);

    gpsEnabled = nextGpsEnabled;
    locationPermissionGranted = nextPermissionGranted;
    hasInternet = nextHasInternet;

    if (lostRequirement) {
      // A driver who goes Online and then loses GPS/permission/network
      // mid-shift shouldn't silently keep looking "online" to passengers
      // while unreachable — force them back offline and surface why.
      isOnline = false;
      _stopLocationUpdates();
      error = !nextGpsEnabled
          ? "GPS was turned off — you've been set to Offline."
          : !nextPermissionGranted
              ? "Location permission was revoked — you've been set to Offline."
              : "Lost internet connection — you've been set to Offline.";
      unawaited(_repository.setOnline(false));
    }

    notifyListeners();
  }

  Future<bool> _checkInternet() async {
    try {
      return await _repository.checkConnectivity().timeout(
            const Duration(seconds: 5),
            onTimeout: () => false,
          );
    } catch (_) {
      return false;
    }
  }

  /// Whether the driver currently meets every precondition to go Online.
  bool get canGoOnline => gpsEnabled && locationPermissionGranted && hasInternet;

  Future<void> _resolveCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Please enable GPS.");
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw Exception("Location permission denied.");
    }

    final pos = await _currentFix();
    if (pos == null) {
      throw Exception("Hindi makuha ang lokasyon. Siguraduhing naka-on ang GPS.");
    }
    currentPosition = ll.LatLng(pos.latitude, pos.longitude);
  }

  /// A GPS fix that can't hang forever: precise first, then a coarse
  /// (Wi-Fi/cell) fix, then the OS's last known position.
  Future<Position?> _currentFix() async {
    for (final accuracy in [LocationAccuracy.high, LocationAccuracy.low]) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: accuracy,
            timeLimit: const Duration(seconds: 8),
          ),
        );
      } catch (_) {
        // try the next, less precise option
      }
    }
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  bool _isPushingLocation = false;

  void _bindSocketEvents() {
    _bookingRequestSub ??=
        _socketClient.on("driver:booking_request").listen((event) {
      final payload = _toMap(event);
      final booking = _toMap(payload["booking"]);
      if (booking["id"] == null) return;
      final isNew = booking["id"]?.toString() != incomingBooking?["id"]?.toString();
      incomingBooking = booking;
      if (isNew) HapticFeedback.heavyImpact();
      notifyListeners();
    });

    _bookingExpiredSub ??=
        _socketClient.on("driver:booking_expired").listen((event) {
      final payload = _toMap(event);
      final expiredId = payload["bookingId"]?.toString();
      final currentId = incomingBooking?["id"]?.toString();
      if (expiredId != null && expiredId == currentId) {
        incomingBooking = null;
        notifyListeners();
      }
    });

    // The passenger can cancel a pending/accepted booking from their side
    // at any point — without this, the driver's "Active Ride" card would
    // stay stuck showing a ride that no longer exists.
    _bookingCancelledSub ??=
        _socketClient.on("driver:booking_cancelled").listen((event) {
      final payload = _toMap(event);
      final cancelledId = payload["bookingId"]?.toString();
      final currentId = activeBooking?["id"]?.toString();
      if (cancelledId != null && cancelledId == currentId) {
        activeBooking = null;
        error = "The passenger cancelled this ride.";
        notifyListeners();
      }
    });

    _approvalSub ??= _socketClient.on("driver:approval_status").listen((event) {
      final payload = _toMap(event);
      approvalStatus = payload["status"]?.toString();
      final detail = payload["reason"]?.toString() ?? payload["note"]?.toString();
      approvalMessage = [
        payload["message"]?.toString(),
        if (detail != null && detail.isNotEmpty) detail,
      ].whereType<String>().join(" ");
      notifyListeners();
      // Pull the new approval state into the profile right away.
      refreshProfile();
    });

    _paymentReceivedSub ??=
        _socketClient.on("driver:payment_received").listen((event) {
      refreshEarnings();
    });

    _connectionStatusSub ??= _socketClient.connectionStatus.listen((connected) {
      hasInternet = hasInternet || connected;
      notifyListeners();
      if (connected && isOnline) {
        // Reconnected mid-shift — push a fresh location fix immediately
        // instead of waiting for the next periodic tick.
        _pushLocation();
      }
    });
  }

  Future<void> setOnline(bool value) async {
    if (value) {
      await _refreshDeviceStatus();
      if (!gpsEnabled) {
        error = "Please enable GPS to go online.";
        notifyListeners();
        return;
      }
      if (!locationPermissionGranted) {
        error = "Location permission is required to go online.";
        notifyListeners();
        return;
      }
      if (!hasInternet) {
        error = "No internet connection. Please reconnect to go online.";
        notifyListeners();
        return;
      }
    }

    isBusy = true;
    error = null;
    notifyListeners();

    try {
      // Socket first; `emit` returns null when disconnected or unanswered,
      // in which case the HTTP endpoint does the same job.
      final response = await _socketClient.emit(
            "driver:set_online",
            {"isOnline": value},
          ) ??
          await _repository.setOnline(value);
      if (response is! Map || response["success"] != true) {
        throw Exception(
            (response is Map ? response["message"]?.toString() : null) ??
                "Failed to update status.");
      }

      isOnline = value;
      if (isOnline) {
        _startLocationUpdates();
      } else {
        _stopLocationUpdates();
      }
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _pushLocation() async {
    // The timer fires every 4s; don't stack GPS lookups if one is slow.
    if (_isPushingLocation) return;
    _isPushingLocation = true;
    try {
      final pos = await _currentFix();
      if (pos == null) return;
      currentPosition = ll.LatLng(pos.latitude, pos.longitude);

      if (_socketClient.isConnected) {
        final response = await _socketClient.emit("driver:location_update", {
          "lat": pos.latitude,
          "lng": pos.longitude,
        });
        if (response is! Map || response["success"] != true) {
          await _repository.updateLocation(
              lat: pos.latitude, lng: pos.longitude);
        }
      } else {
        await _repository.updateLocation(lat: pos.latitude, lng: pos.longitude);
      }

      notifyListeners();
    } catch (_) {
      // Best-effort; the next tick retries.
    } finally {
      _isPushingLocation = false;
    }
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _pushLocation();
    _checkIncomingBooking();
    _locationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pushLocation();
      _checkIncomingBooking();
    });
  }

  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> acceptIncomingBooking() async {
    final bookingId = int.tryParse(incomingBooking?["id"]?.toString() ?? "");
    if (bookingId == null) return;

    isBusy = true;
    error = null;
    notifyListeners();
    try {
      final response = await _respondToBooking(bookingId, "accept");
      final data = _toMap(response["data"]);
      activeBooking = _toMap(data["booking"]);
      incomingBooking = null;
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
      // The offer is gone (expired, or the passenger cancelled/re-chose).
      if (error!.contains("no longer available") ||
          error!.contains("no longer pending")) {
        incomingBooking = null;
      }
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Accept/decline over the socket, falling back to HTTP when the socket
  /// is down or doesn't acknowledge in time.
  Future<Map<String, dynamic>> _respondToBooking(
    int bookingId,
    String action,
  ) async {
    final payload = {
      "bookingId": bookingId,
      "action": action,
      if (action == "decline") "reason": "Driver unavailable",
    };
    final dynamic response =
        await _socketClient.emit("driver:booking_response", payload) ??
            await _repository.respondBooking(
              bookingId: bookingId,
              action: action,
              reason: action == "decline" ? "Driver unavailable" : null,
            );
    final map = _toMap(response);
    if (map["success"] != true) {
      throw Exception(map["message"]?.toString() ??
          (action == "accept"
              ? "Failed to accept booking."
              : "Failed to decline booking."));
    }
    return map;
  }

  bool _isCheckingIncoming = false;

  /// Fallback for a missed "driver:booking_request" socket event: asks the
  /// server which ride request (if any) is waiting on this rider. Also
  /// clears a request card whose offer expired or was cancelled.
  Future<void> _checkIncomingBooking() async {
    if (!isOnline || activeBooking != null || _isCheckingIncoming || isBusy) {
      return;
    }
    _isCheckingIncoming = true;
    try {
      final response = await _repository.getIncomingBooking();
      if (response["success"] != true) return;
      final booking =
          response["data"] == null ? null : _toMap(response["data"]);
      final currentId = incomingBooking?["id"]?.toString();
      final nextId = booking?["id"]?.toString();
      if (currentId != nextId) {
        incomingBooking = booking;
        notifyListeners();
      }
    } catch (_) {
      // Best-effort; the next tick tries again.
    } finally {
      _isCheckingIncoming = false;
    }
  }

  Future<void> declineIncomingBooking() async {
    final bookingId = int.tryParse(incomingBooking?["id"]?.toString() ?? "");
    if (bookingId == null) return;

    isBusy = true;
    error = null;
    notifyListeners();
    try {
      await _respondToBooking(bookingId, "decline");
      incomingBooking = null;
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
      incomingBooking = null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> markArrived() async {
    final bookingId = int.tryParse(activeBooking?["id"]?.toString() ?? "");
    if (bookingId == null) return;

    isBusy = true;
    notifyListeners();
    try {
      final response = await _repository.arriveAtPickup(bookingId);
      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Failed to mark arrival.");
      }
      activeBooking = response["data"] as Map<String, dynamic>?;
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> startRide(String pin) async {
    final bookingId = int.tryParse(activeBooking?["id"]?.toString() ?? "");
    if (bookingId == null) return false;

    isBusy = true;
    error = null;
    notifyListeners();
    try {
      final response = await _repository.startRide(bookingId, pin: pin);
      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Failed to start ride.");
      }
      activeBooking = response["data"] as Map<String, dynamic>?;
      return true;
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> markNoShow({String? note}) async {
    final bookingId = int.tryParse(activeBooking?["id"]?.toString() ?? "");
    if (bookingId == null) return false;

    isBusy = true;
    error = null;
    notifyListeners();
    try {
      final response = await _repository.markNoShow(bookingId, note: note);
      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Failed to report no-show.");
      }
      activeBooking = null;
      unawaited(loadRideHistory());
      return true;
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> completeRide() async {
    final bookingId = int.tryParse(activeBooking?["id"]?.toString() ?? "");
    if (bookingId == null) return;

    isBusy = true;
    notifyListeners();
    try {
      final response = await _repository.completeRide(bookingId: bookingId);
      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Failed to complete ride.");
      }
      activeBooking = null;
      await refreshEarnings(notify: false);
      await refreshProfile(notify: false);
      unawaited(loadRideHistory());
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> refreshEarnings({bool notify = true}) async {
    try {
      final response = await _repository.getEarnings();
      if (response["success"] == true) {
        earningsSummary = response["data"] as Map<String, dynamic>?;
        if (notify) {
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> refreshPerformance({bool notify = true}) async {
    try {
      final response = await _repository.getPerformance();
      if (response["success"] == true) {
        performanceStats = response["data"] as Map<String, dynamic>?;
        if (notify) notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> refreshProfile({bool notify = true}) async {
    if (notify) {
      isProfileLoading = true;
      error = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _repository.getProfile(),
        _repository.getRatings(),
        _repository.getCompletedRides(),
      ]);

      final profileResponse = results[0];
      if (profileResponse["success"] != true) {
        throw Exception(profileResponse["message"]?.toString() ??
            "Failed to load profile.");
      }
      driverProfile = _toMap(profileResponse["data"]);

      // Restore online/offline state from the backend so a relaunched app
      // doesn't silently show "Offline" while the server still has the
      // driver marked online (and still broadcasting their last location).
      final wasOnline = isOnline;
      final serverOnline = driverProfile?["is_online"];
      isOnline = serverOnline == true || serverOnline == 1 || serverOnline == "1";
      if (isOnline && !wasOnline) {
        _startLocationUpdates();
      } else if (!isOnline && wasOnline) {
        _stopLocationUpdates();
      }

      final ratingsResponse = results[1];
      final rawRatings = ratingsResponse["data"];
      if (ratingsResponse["success"] == true && rawRatings is List) {
        ratings = rawRatings.map(_toMap).toList();
      } else {
        ratings = [];
      }

      final ridesResponse = results[2];
      final rawRides = ridesResponse["data"];
      if (ridesResponse["success"] == true && rawRides is List) {
        completedRides = rawRides.map(_toMap).toList();
      } else {
        completedRides = [];
      }
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
    } finally {
      isProfileLoading = false;
      if (notify) {
        notifyListeners();
      }
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    required String phone,
    required String email,
    required String tricycleNumber,
    XFile? profileImage,
  }) async {
    isSavingProfile = true;
    error = null;
    notifyListeners();

    try {
      final response = await _repository.updateProfile(
        fullName: fullName,
        phone: phone,
        email: email,
        tricycleNumber: tricycleNumber,
        profileImage: profileImage,
      );

      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Failed to update profile.");
      }

      driverProfile = _toMap(response["data"]);
      await refreshEarnings(notify: false);
      await refreshProfile(notify: false);
      isSavingProfile = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
      isSavingProfile = false;
      notifyListeners();
      return false;
    }
  }

  bool isSendingSos = false;
  String? sosMessage;

  Future<bool> sendSos({String? message}) async {
    final bookingId = int.tryParse(activeBooking?["id"]?.toString() ?? "");
    if (bookingId == null) {
      error = "SOS is only available during an active ride.";
      notifyListeners();
      return false;
    }

    isSendingSos = true;
    error = null;
    sosMessage = null;
    notifyListeners();

    try {
      final response = await _repository.triggerSos(
        bookingId: bookingId,
        lat: currentPosition?.latitude,
        lng: currentPosition?.longitude,
        message: message,
      );
      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Failed to send SOS alert.");
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

  Future<Map<String, dynamic>> requestPasswordChangeOtp({
    required String currentPassword,
  }) async {
    try {
      final result =
          await _repository.requestPasswordChangeOtp(currentPassword: currentPassword);
      if (result["success"] != true) {
        error = result["message"] as String? ?? "Failed to send verification code.";
        notifyListeners();
      }
      return result;
    } catch (e) {
      error = "Error requesting verification code: $e";
      notifyListeners();
      return {"success": false, "message": error};
    }
  }

  Future<bool> confirmPasswordChange({
    required String currentPassword,
    required String newPassword,
    required String otp,
  }) async {
    try {
      final result = await _repository.confirmPasswordChange(
        currentPassword: currentPassword,
        newPassword: newPassword,
        otp: otp,
      );
      if (result["success"] == true) return true;
      error = result["message"] as String? ?? "Failed to change password";
      notifyListeners();
      return false;
    } catch (e) {
      error = "Error changing password: $e";
      notifyListeners();
      return false;
    }
  }

  Future<bool> reportIssue({
    required String category,
    required String description,
  }) async {
    final bookingId = int.tryParse(activeBooking?["id"]?.toString() ?? "");
    try {
      final response = await _repository.reportIssue(
        bookingId: bookingId,
        category: category,
        description: description,
      );
      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Failed to submit report.");
      }
      return true;
    } catch (e) {
      error = e.toString().replaceFirst("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    // Best-effort — this controller (and the shell that owns it) is torn
    // down when the driver switches to Passenger Mode or logs out from
    // somewhere that didn't already call setOnline(false) itself. Fire it
    // off without awaiting since dispose() can't be async; the server-side
    // staleness check in the matching query is the real safety net for
    // cases this can't reach in time (e.g. a killed app/closed tab).
    if (isOnline) {
      _repository.setOnline(false).catchError((_) => <String, dynamic>{});
    }
    _stopLocationUpdates();
    _statusTimer?.cancel();
    _bookingRequestSub?.cancel();
    _bookingExpiredSub?.cancel();
    _bookingCancelledSub?.cancel();
    _approvalSub?.cancel();
    _paymentReceivedSub?.cancel();
    _connectionStatusSub?.cancel();
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

