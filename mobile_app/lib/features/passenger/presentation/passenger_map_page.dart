import "dart:async";
import "dart:math";

import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart" as ll;
import "package:maplibre_gl/maplibre_gl.dart" as ml;
import "../../../core/widgets/app_map.dart";
import "package:provider/provider.dart";
import "../../../core/components/index.dart";
import "../../../core/network/api_client.dart";
import "../../../core/theme/design_tokens.dart";
import "../../../core/config/app_config.dart";
import "../../../core/utils/geo_utils.dart";
import "../../../core/utils/place_search.dart";
import "../../shared/state/session_store.dart";
import "../repositories/passenger_repository.dart";
import "passenger_ride_controller.dart";
import "pages/place_search_page.dart";
import "pages/notifications_page.dart";
import "../../booking/presentation/rating_page.dart";
import "../../booking/repositories/booking_repository.dart";

const Color _pickupColor = Color(0xFF0E8C46);
const Color _currentColor = Color(0xFF1471C5);

// Module-level helper functions
String? asText(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  return value.toString();
}

String formatMoney(dynamic amount) {
  double value;
  if (amount is int || amount is double) {
    value = (amount as num).toDouble();
  } else {
    value = double.tryParse(amount.toString()) ?? 0;
  }
  return "PHP ${value.toStringAsFixed(2)}";
}

class PassengerMapPage extends StatefulWidget {
  const PassengerMapPage({super.key});

  @override
  State<PassengerMapPage> createState() => _PassengerMapPageState();
}

class _PassengerMapPageState extends State<PassengerMapPage>
    with WidgetsBindingObserver {
  static const ll.LatLng _fallbackCenter = ll.LatLng(14.5995, 120.9842);

  PassengerRideController? _rideController;
  AppMapController? _mapController;

  Timer? _pulseTimer;
  bool _mapReady = false;
  bool _syncQueued = false;
  bool _syncInProgress = false;
  bool _syncPending = false;
  bool _hasCenteredOnUser = false;
  double _pulsePhase = 0;
  String? _lastFitKey;

  final List<ml.Circle> _staticCircles = [];
  ml.Circle? _currentLocationCircle;
  ml.Circle? _assignedDriverCircle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      _pulsePhase = (_pulsePhase + 0.18) % 1.0;
      _requestSync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<PassengerRideController>();
    if (_rideController == controller) return;

    _rideController?.removeListener(_handleRideControllerChanged);
    _rideController = controller;
    _seenPickerRequest = controller.driverPickerRequest;
    _seenPinPrompt = controller.pinPromptRequest;
    _rideController?.addListener(_handleRideControllerChanged);
    _requestSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rideController?.removeListener(_handleRideControllerChanged);
    _pulseTimer?.cancel();
    super.dispose();
  }

  // Coming back from Settings (after turning on GPS or granting
  // permission): try again right away instead of waiting for a tap.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _rideController;
    if (state == AppLifecycleState.resumed &&
        controller != null &&
        controller.currentPosition == null &&
        !controller.isResolvingLocation) {
      controller.refreshCurrentLocation();
    }
  }

  int _seenPickerRequest = 0;
  int _seenPinPrompt = 0;
  bool _pinDialogOpen = false;

  /// Big, readable PIN for the passenger to show/read to the rider.
  Future<void> _showPinDialog(PassengerRideController controller) async {
    final pin = controller.pickupPin;
    if (!mounted || pin == null || _pinDialogOpen) return;
    _pinDialogOpen = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: DesignTokens.bg2,
        title: const Text(
          "Ang iyong Pickup PIN",
          style:
              TextStyle(color: DesignTokens.text, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Ibigay ang PIN na ito sa rider para masimulan ang biyahe.",
              textAlign: TextAlign.center,
              style: TextStyle(color: DesignTokens.muted),
            ),
            const SizedBox(height: 16),
            Text(
              pin,
              style: const TextStyle(
                color: DesignTokens.accent,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                const Text("OK", style: TextStyle(color: DesignTokens.accent)),
          ),
        ],
      ),
    );
    _pinDialogOpen = false;
  }

  bool _pickerOpen = false;

  void _handleRideControllerChanged() {
    _requestSync();

    // The chosen rider declined / timed out: reopen the picker so the
    // passenger can choose someone else right away.
    final controller = _rideController;

    // The rider just arrived and will ask for the PIN — put it front and
    // centre instead of leaving it somewhere in the panel.
    if (controller != null && controller.pinPromptRequest != _seenPinPrompt) {
      _seenPinPrompt = controller.pinPromptRequest;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPinDialog(controller);
      });
    }

    if (controller != null &&
        controller.driverPickerRequest != _seenPickerRequest) {
      _seenPickerRequest = controller.driverPickerRequest;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final message = controller.rideNotice;
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
        _showDriverPicker(controller);
      });
    }
  }

  void _handleMapCreated(AppMapController controller) {
    _mapController = controller;
    _requestSync();
  }

  void _handleStyleLoaded() {
    if (!mounted) return;

    setState(() {
      _mapReady = true;
    });
    _requestSync();
  }

  void _requestSync() {
    if (_syncQueued) return;
    _syncQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncQueued = false;
      if (!mounted || !_mapReady) return;
      _syncMapAnnotations();
    });
  }

  Future<void> _syncMapAnnotations() async {
    final map = _mapController;
    final controller = _rideController;
    if (map == null || controller == null || !mounted || !_mapReady) return;

    if (_syncInProgress) {
      _syncPending = true;
      return;
    }

    _syncInProgress = true;
    try {
      do {
        _syncPending = false;
        final batch = _buildAnnotationBatch(controller);

        if (_staticCircles.isNotEmpty) {
          await map.removeCircles(_staticCircles);
          _staticCircles.clear();
        }
        await map.clearLines();

        if (batch.lines.isNotEmpty) {
          await map.addLines(batch.lines);
        }
        for (final option in batch.circles) {
          final circle = await map.addCircle(option);
          _staticCircles.add(circle);
        }

        await _updateDynamicCircles(controller);

        if (!_hasCenteredOnUser && controller.currentPosition != null) {
          // First real GPS fix: snap the camera straight to it at a close
          // zoom instead of the generic multi-point bounds fit, so the
          // user immediately sees "you are here" rather than a wide,
          // zoomed-out view (or the Manila fallback center).
          _hasCenteredOnUser = true;
          _lastFitKey = batch.fitKey;
          await map.animateCamera(
            _toMapLibre(controller.currentPosition)!,
            zoom: 16.2,
          );
        } else if (batch.bounds != null && batch.fitKey != _lastFitKey) {
          _lastFitKey = batch.fitKey;
          await map.animateCameraBounds(
            batch.bounds!,
            left: 44,
            top: 88,
            right: 44,
            bottom: 260,
          );
        }
      } while (_syncPending && mounted);
    } finally {
      _syncInProgress = false;
    }
  }

  _AnnotationBatch _buildAnnotationBatch(PassengerRideController controller) {
    final circles = <ml.CircleOptions>[];
    final lines = <ml.LineOptions>[];
    final fitPoints = <ml.LatLng>[];

    void addFitPoint(ml.LatLng? point) {
      if (point == null) return;
      fitPoints.add(point);
    }

    final currentLocation = _toMapLibre(controller.currentPosition);
    final pickup = _toMapLibre(controller.pickup);
    final dropoff = _toMapLibre(controller.dropoff);
    final assignedDriver = _toMapLibre(controller.driverPosition);
    final driverMarkers = _buildDriverMarkers(controller);

    addFitPoint(currentLocation);
    addFitPoint(pickup);
    addFitPoint(dropoff);
    addFitPoint(assignedDriver);

    for (final driver in driverMarkers.where((item) => item.tone != "live")) {
      addFitPoint(driver.point);
    }

    if (controller.pickup != null && controller.dropoff != null) {
      // Prefer the real road-following route once it's loaded; fall back to
      // a straight line only while the route request is still in flight.
      final routeGeometry = controller.routePolyline
          ?.map((point) => ml.LatLng(point.latitude, point.longitude))
          .toList();
      lines.add(
        ml.LineOptions(
          geometry: routeGeometry ??
              [
                _toMapLibre(controller.pickup)!,
                _toMapLibre(controller.dropoff)!,
              ],
          lineColor: _routeColorToHex(),
          lineWidth: 4.5,
          lineOpacity: 0.82,
        ),
      );
    }

    if (controller.driverPosition != null && controller.pickup != null) {
      lines.add(
        ml.LineOptions(
          geometry: [
            _toMapLibre(controller.driverPosition)!,
            _toMapLibre(controller.pickup)!,
          ],
          lineColor: _driverRouteColorToHex(),
          lineWidth: 3.4,
          lineOpacity: 0.7,
        ),
      );
    }

    if (pickup != null) {
      circles.add(
        ml.CircleOptions(
          geometry: pickup,
          circleRadius: 10,
          circleColor: _pickupColorToHex(),
          circleOpacity: 0.96,
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: 2,
        ),
      );
    }

    if (dropoff != null) {
      circles.add(
        ml.CircleOptions(
          geometry: dropoff,
          circleRadius: 10,
          circleColor: _dropoffColorToHex(),
          circleOpacity: 0.96,
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: 2,
        ),
      );
    }

    if (assignedDriver != null) {
      // dynamic assigned driver marker updated separately.
      addFitPoint(assignedDriver);
    }

    if (currentLocation != null) {
      // current location marker is updated separately.
      addFitPoint(currentLocation);
    }

    for (final driver in driverMarkers) {
      if (driver.tone == "assigned") {
        continue;
      }

      circles.add(
        ml.CircleOptions(
          geometry: driver.point,
          circleRadius: driver.tone == "nearby" ? 8.5 : 7.5,
          circleColor: driver.tone == "nearby"
              ? _nearbyDriverColorToHex()
              : _liveDriverColorToHex(),
          circleOpacity: 0.92,
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: 2,
        ),
      );
    }

    if (pickup != null) {
      circles.add(
        ml.CircleOptions(
          geometry: pickup,
          circleRadius: 10,
          circleColor: _pickupColorToHex(),
          circleOpacity: 0.96,
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: 2,
        ),
      );
    }

    if (dropoff != null) {
      circles.add(
        ml.CircleOptions(
          geometry: dropoff,
          circleRadius: 10,
          circleColor: _dropoffColorToHex(),
          circleOpacity: 0.96,
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: 2,
        ),
      );
    }

    if (assignedDriver != null) {
      _addPulsingMarker(
        circles,
        assignedDriver,
        pulseColor: _assignedDriverColorToHex(),
        dotColor: _assignedDriverColorToHex(),
        baseRadius: 9,
        pulseRadius: 18 + (_pulsePhase * 6),
        pulseOpacity: 0.16,
        pulseWidth: 2,
      );
    }

    for (final driver in driverMarkers) {
      if (driver.tone == "assigned") {
        continue;
      }

      circles.add(
        ml.CircleOptions(
          geometry: driver.point,
          circleRadius: driver.tone == "nearby" ? 8.5 : 7.5,
          circleColor: driver.tone == "nearby"
              ? _nearbyDriverColorToHex()
              : _liveDriverColorToHex(),
          circleOpacity: 0.92,
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: 2,
        ),
      );
    }

    final bounds = _buildBounds(fitPoints);
    final fitKey = _buildFitKey(controller, driverMarkers);

    return _AnnotationBatch(
      circles: circles,
      lines: lines,
      bounds: bounds,
      fitKey: fitKey,
    );
  }

  List<_DriverMarker> _buildDriverMarkers(PassengerRideController controller) {
    final markers = <_DriverMarker>[];
    final liveIds = <int>{};
    final nearbyIds = <int>{};
    final assignedId =
        int.tryParse(controller.driverInfo?["id"]?.toString() ?? "");

    for (final entry in controller.liveDrivers.entries) {
      final data = entry.value;
      final point = _extractPoint(data);
      if (point == null) continue;

      liveIds.add(entry.key);
      markers.add(
        _DriverMarker(
          id: entry.key,
          point: point,
          label: _driverLabel(data, fallback: "Live Driver"),
          distanceKm: _distanceFromPickup(point, controller.pickup),
          tone: "live",
        ),
      );
    }

    for (final rawDriver in controller.nearbyDrivers) {
      final driver = _toMap(rawDriver);
      final id = int.tryParse(driver["id"]?.toString() ?? "");
      final point = _extractPoint(driver);
      if (point == null || id == null) continue;
      if (liveIds.contains(id) || nearbyIds.contains(id)) {
        continue;
      }

      nearbyIds.add(id);
      markers.add(
        _DriverMarker(
          id: id,
          point: point,
          label: _driverLabel(driver, fallback: "Nearby Driver"),
          distanceKm:
              double.tryParse(driver["distanceToPickupKm"]?.toString() ?? ""),
          tone: "nearby",
        ),
      );
    }

    if (assignedId != null) {
      final assignedPoint = _extractPoint(controller.driverInfo) ??
          _toMapLibre(controller.driverPosition);
      if (assignedPoint != null) {
        markers.removeWhere((marker) => marker.id == assignedId);
        markers.add(
          _DriverMarker(
            id: assignedId,
            point: assignedPoint,
            label: _driverLabel(controller.driverInfo,
                fallback: "Assigned Driver"),
            distanceKm: controller.driverDistanceToPickupKm,
            tone: "assigned",
          ),
        );
      }
    }

    markers.sort((a, b) {
      final aDistance = a.distanceKm ?? double.infinity;
      final bDistance = b.distanceKm ?? double.infinity;
      return aDistance.compareTo(bDistance);
    });

    return markers;
  }

  Future<void> _updateDynamicCircles(PassengerRideController controller) async {
    final map = _mapController;
    if (map == null) return;

    final currentLocation = _toMapLibre(controller.currentPosition);
    final assignedDriver = _toMapLibre(controller.driverPosition);

    if (currentLocation != null) {
      if (_currentLocationCircle != null) {
        await map.moveCircleSmooth(_currentLocationCircle!, currentLocation,
            durationMs: 500, steps: 12);
      } else {
        _currentLocationCircle = await map.addCircle(_pulsingCircleOption(
          currentLocation,
          pulseColor: _currentColorToHex(),
          dotColor: _currentColorToHex(),
          baseRadius: 8,
          pulseRadius: 16 + (_pulsePhase * 5),
          pulseOpacity: 0.18,
          pulseWidth: 2,
        ));
      }
    } else if (_currentLocationCircle != null) {
      await map.removeCircle(_currentLocationCircle!);
      _currentLocationCircle = null;
    }

    if (assignedDriver != null) {
      if (_assignedDriverCircle != null) {
        await map.moveCircleSmooth(_assignedDriverCircle!, assignedDriver,
            durationMs: 500, steps: 12);
      } else {
        _assignedDriverCircle = await map.addCircle(_pulsingCircleOption(
          assignedDriver,
          pulseColor: _assignedDriverColorToHex(),
          dotColor: _assignedDriverColorToHex(),
          baseRadius: 9,
          pulseRadius: 18 + (_pulsePhase * 6),
          pulseOpacity: 0.16,
          pulseWidth: 2,
        ));
      }
    } else if (_assignedDriverCircle != null) {
      await map.removeCircle(_assignedDriverCircle!);
      _assignedDriverCircle = null;
    }
  }

  ml.CircleOptions _pulsingCircleOption(
    ml.LatLng point, {
    required String pulseColor,
    required String dotColor,
    required double baseRadius,
    required double pulseRadius,
    required double pulseOpacity,
    required double pulseWidth,
  }) {
    return ml.CircleOptions(
      geometry: point,
      circleRadius: pulseRadius,
      circleColor: pulseColor,
      circleOpacity: pulseOpacity,
      circleStrokeColor: "#FFFFFF",
      circleStrokeWidth: pulseWidth,
    );
  }

  ml.LatLngBounds? _buildBounds(List<ml.LatLng> points) {
    if (points.isEmpty) return null;

    var minLat = double.infinity;
    var minLng = double.infinity;
    var maxLat = -double.infinity;
    var maxLng = -double.infinity;

    for (final point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    if (minLat == maxLat) {
      minLat -= 0.002;
      maxLat += 0.002;
    }
    if (minLng == maxLng) {
      minLng -= 0.002;
      maxLng += 0.002;
    }

    return ml.LatLngBounds(
      southwest: ml.LatLng(minLat, minLng),
      northeast: ml.LatLng(maxLat, maxLng),
    );
  }

  String _buildFitKey(
      PassengerRideController controller, List<_DriverMarker> driverMarkers) {
    final buffer = StringBuffer()
      ..write(_pointKey(controller.currentPosition))
      ..write("|")
      ..write(_pointKey(controller.pickup))
      ..write("|")
      ..write(_pointKey(controller.dropoff))
      ..write("|")
      ..write(_pointKey(controller.driverPosition))
      ..write("|");

    final driverIds = driverMarkers
        .where((driver) => driver.tone != "live")
        .map((driver) => driver.id)
        .toList()
      ..sort();

    buffer.write(driverIds.join(","));
    return buffer.toString();
  }

  void _addPulsingMarker(
    List<ml.CircleOptions> circles,
    ml.LatLng point, {
    required String pulseColor,
    required String dotColor,
    required double baseRadius,
    required double pulseRadius,
    required double pulseOpacity,
    required double pulseWidth,
  }) {
    circles.add(
      ml.CircleOptions(
        geometry: point,
        circleRadius: pulseRadius,
        circleColor: pulseColor,
        circleOpacity: pulseOpacity,
        circleStrokeColor: "#FFFFFF",
        circleStrokeWidth: pulseWidth,
      ),
    );
    circles.add(
      ml.CircleOptions(
        geometry: point,
        circleRadius: baseRadius,
        circleColor: dotColor,
        circleOpacity: 0.98,
        circleStrokeColor: "#FFFFFF",
        circleStrokeWidth: 2,
      ),
    );
  }

  String _driverLabel(Map<String, dynamic>? driver,
      {required String fallback}) {
    final name = asText(driver?["full_name"]) ?? asText(driver?["fullName"]);
    final tricycle =
        asText(driver?["tricycle_number"]) ?? asText(driver?["tricycleNumber"]);
    final segments = <String>[];

    if (name != null) {
      segments.add(name);
    }
    if (tricycle != null) {
      segments.add(tricycle);
    }

    if (segments.isEmpty) return fallback;
    return segments.join(" - ");
  }

  ml.LatLng? _extractPoint(Map<String, dynamic>? raw) {
    if (raw == null) return null;

    final lat = _readDouble(raw, ["lat", "latitude", "current_lat"]);
    final lng = _readDouble(raw, ["lng", "longitude", "current_lng"]);
    if (lat == null || lng == null) return null;
    return ml.LatLng(lat, lng);
  }

  double? _readDouble(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value == null) continue;
      final parsed = double.tryParse(value.toString());
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return null;
  }

  String _pointKey(ll.LatLng? point) {
    if (point == null) return "-";
    return "${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}";
  }

  String _mapPointLabel(ll.LatLng? point, {required String placeholder}) {
    if (point == null) return placeholder;
    return "${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}";
  }

  double? _distanceFromPickup(ml.LatLng point, ll.LatLng? pickup) {
    if (pickup == null) return null;
    return haversineKm(
      lat1: point.latitude,
      lng1: point.longitude,
      lat2: pickup.latitude,
      lng2: pickup.longitude,
    );
  }

  ml.LatLng? _toMapLibre(ll.LatLng? point) {
    if (point == null) return null;
    return ml.LatLng(point.latitude, point.longitude);
  }

  ll.LatLng? _toLatLng(ml.LatLng? point) {
    if (point == null) return null;
    return ll.LatLng(point.latitude, point.longitude);
  }

  Map<String, dynamic> _toMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  String _pickupText(PassengerRideController ctrl) {
    if (ctrl.pickup == null) return "Tap map";
    if (ctrl.pickupAddress != null) return ctrl.pickupAddress!;
    if (ctrl.isResolvingPickupAddress) return "Locating address…";
    return _mapPointLabel(ctrl.pickup, placeholder: "Tap map");
  }

  String _dropoffText(PassengerRideController ctrl) {
    if (ctrl.dropoff == null) return "Tap map again";
    if (ctrl.dropoffAddress != null) return ctrl.dropoffAddress!;
    if (ctrl.isResolvingDropoffAddress) return "Locating address…";
    return _mapPointLabel(ctrl.dropoff, placeholder: "Tap map again");
  }

  Future<void> _moveToCurrentLocation() async {
    final map = _mapController;
    final controller = _rideController;
    if (map == null || controller == null) return;

    final point = controller.currentPosition ?? _fallbackCenter;
    await map.animateCamera(ml.LatLng(point.latitude, point.longitude),
        zoom: 16.2);
  }

  Future<void> _fitToSelection() async {
    final map = _mapController;
    final controller = _rideController;
    if (map == null || controller == null) return;

    final batch = _buildAnnotationBatch(controller);
    if (batch.bounds == null) return;

    _lastFitKey = batch.fitKey;
    await map.animateCameraBounds(batch.bounds!,
        left: 44, top: 88, right: 44, bottom: 260);
  }

  void _handleMapClick(Point<double> tapPoint, ml.LatLng coordinates) {
    final controller = _rideController;
    if (controller == null) return;
    controller.selectOnMap(_toLatLng(coordinates)!);
  }

  Future<void> _confirmAndSendSos(PassengerRideController controller) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Send SOS Alert?"),
        content: const Text(
          "This will immediately notify the admin team with your current location. "
          "Only use this in a real emergency.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Send SOS"),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await controller.sendSos();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (controller.sosMessage ?? "SOS alert sent.")
              : (controller.error ?? "Failed to send SOS alert."),
        ),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  /// Bottom sheet listing the nearest online riders. It rebuilds from the
  /// controller, so the list keeps refreshing (every few seconds) while
  /// open, and shows a "still searching" state when nobody is online yet.
  Future<void> _showDriverPicker(PassengerRideController controller) async {
    if (!mounted || _pickerOpen || !controller.isChoosingDriver) return;
    _pickerOpen = true;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: DesignTokens.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            // Chosen elsewhere / accepted / cancelled — nothing left to pick.
            if (!controller.isChoosingDriver) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.of(sheetContext).canPop()) {
                  Navigator.pop(sheetContext);
                }
              });
            }
            final drivers = controller.nearbyDrivers;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Pumili ng rider",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: DesignTokens.text,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: "I-refresh",
                          onPressed: controller.isRefreshingDrivers
                              ? null
                              : controller.refreshNearbyDrivers,
                          icon: controller.isRefreshingDrivers
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded,
                                  color: DesignTokens.accent),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text(
                            "Isara",
                            style: TextStyle(color: DesignTokens.accent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      drivers.isEmpty
                          ? "Mga online na rider na malapit sa pickup mo."
                          : "${drivers.length} online na rider • pinakamalapit ang nasa itaas.",
                      style: const TextStyle(color: DesignTokens.muted),
                    ),
                    if (controller.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        controller.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (drivers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              "Wala pang online na rider sa malapit.\nAwtomatiko naming ia-update ang listahan.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: DesignTokens.muted),
                            ),
                          ],
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: drivers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) => _DriverOptionTile(
                            driver: drivers[index],
                            isNearest: index == 0,
                            enabled: !controller.isSubmittingRide,
                            onTap: (id) async {
                              Navigator.pop(sheetContext);
                              await controller.chooseDriver(id);
                              if (!mounted) return;
                              final message =
                                  controller.error ?? controller.rideNotice;
                              if (message != null) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              }
                              // Rider was taken in the meantime — pick again.
                              if (controller.isChoosingDriver) {
                                await _showDriverPicker(controller);
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    _pickerOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PassengerRideController>();
    final session = context.watch<SessionStore>().session;
    final currentLocation = ctrl.currentPosition;
    final nearbyDrivers = ctrl.nearbyDrivers;

    return Stack(
      children: [
        Positioned.fill(
          child: AppMap(
            initialStyleUrl: AppConfig.openFreeMapStyleUrl,
            initialPosition: ml.LatLng(
                (currentLocation ?? _fallbackCenter).latitude,
                (currentLocation ?? _fallbackCenter).longitude),
            onMapCreated: _handleMapCreated,
            onStyleLoaded: _handleStyleLoaded,
            onMapClick: _handleMapClick,
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 16,
          // The status card and the map control buttons used to be two
          // independently-positioned Stack children pinned to the same
          // top-right corner, so the buttons painted directly on top of
          // the card's status chip. Laying them out in one Row instead
          // makes the card shrink to leave room for the buttons, so they
          // can never overlap regardless of card/button size.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _MapStatusCard(
                      mapReady: _mapReady,
                      passengerName: session?.fullName ?? "Passenger",
                      onNotificationsTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const NotificationsPage()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      _MapControlButton(
                        icon: Icons.my_location_rounded,
                        label: "Center",
                        color: _currentColor,
                        onPressed: _moveToCurrentLocation,
                      ),
                      const SizedBox(height: 8),
                      _MapControlButton(
                        icon: Icons.zoom_out_map_rounded,
                        label: "Fit",
                        color: _pickupColor,
                        onPressed: _fitToSelection,
                      ),
                    ],
                  ),
                ],
              ),
              // Pinned over the map (not inside the draggable panel) so the
              // PIN stays visible however far the panel is collapsed.
              if (ctrl.shouldShowPickupPin) ...[
                const SizedBox(height: 8),
                _PickupPinBanner(
                  pin: ctrl.pickupPin!,
                  highlight: ctrl.bookingStatus == "arriving",
                  onTap: () => _showPinDialog(ctrl),
                ),
              ],
            ],
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.3,
          minChildSize: 0.14,
          maxChildSize: 0.85,
          snap: true,
          snapSizes: const [0.14, 0.3, 0.85],
          builder: (context, scrollController) {
            return _RidePanel(
              controller: ctrl,
              nearbyDrivers: nearbyDrivers,
              scrollController: scrollController,
              pickupText: _pickupText(ctrl),
              dropoffText: _dropoffText(ctrl),
              onFindRide: ctrl.isSubmittingRide
                  ? null
                  : () async {
                      // While choosing, the button just reopens the picker.
                      if (!ctrl.isChoosingDriver) await ctrl.findRide();
                      if (!mounted) return;
                      if (ctrl.isChoosingDriver) {
                        await _showDriverPicker(ctrl);
                      } else if (ctrl.error != null) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text(ctrl.error!)),
                        );
                      }
                    },
              onReset: ctrl.isCompletingAction ? null : ctrl.resetTripSelection,
              onSos: () => _confirmAndSendSos(ctrl),
              onCancel: (ctrl.activeBookingId == null ||
                      !["pending", "accepted"].contains(ctrl.bookingStatus))
                  ? null
                  : ctrl.cancelRide,
            );
          },
        ),
        if (!_mapReady)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: const AppCard(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DesignTokens.accent,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Loading OpenFreeMap...",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: DesignTokens.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_mapReady && currentLocation == null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            // A spinner only while a lookup is actually running; otherwise
            // always offer a way forward (settings or retry).
            child: ctrl.locationPermissionDeniedForever
                ? const _LocationNotice(
                    message:
                        "Naka-block ang location access. Payagan ito sa Settings para makita ka sa mapa.",
                    actionLabel: "Settings",
                    onAction: Geolocator.openAppSettings,
                  )
                : ctrl.isResolvingLocation
                    ? const _LocationNotice(
                        message: "Kinukuha ang lokasyon mo…",
                        showSpinner: true,
                      )
                    : ctrl.locationServiceDisabled
                        ? _LocationNotice(
                            message: ctrl.locationError ??
                                "Naka-off ang GPS/Location.",
                            actionLabel: "I-on",
                            onAction: () async {
                              await Geolocator.openLocationSettings();
                              await ctrl.refreshCurrentLocation();
                            },
                          )
                        : _LocationNotice(
                            message: ctrl.locationError ??
                                "Hindi pa makuha ang lokasyon mo.",
                            actionLabel: "Subukan ulit",
                            onAction: ctrl.refreshCurrentLocation,
                          ),
          ),
      ],
    );
  }
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.showSpinner = false,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          if (showSpinner) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DesignTokens.accent,
              ),
            ),
            const SizedBox(width: 12),
          ] else
            const Icon(Icons.location_off_rounded,
                color: DesignTokens.warning, size: 20),
          if (!showSpinner) const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: DesignTokens.text, fontSize: 13),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(color: DesignTokens.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RidePanel extends StatelessWidget {
  const _RidePanel({
    required this.controller,
    required this.nearbyDrivers,
    required this.scrollController,
    required this.pickupText,
    required this.dropoffText,
    required this.onFindRide,
    required this.onReset,
    required this.onSos,
    required this.onCancel,
  });

  final PassengerRideController controller;
  final List<Map<String, dynamic>> nearbyDrivers;
  final ScrollController scrollController;
  final String pickupText;
  final String dropoffText;
  final Future<void> Function()? onFindRide;
  final VoidCallback? onReset;
  final VoidCallback onSos;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    final driverName = controller.driverName;
    final driverTricycle = controller.driverTricycle;

    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: DesignTokens.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.16),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: DesignTokens.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Trip Builder",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (controller.bookingStatus != null) ...[
                _StatusChip(
                    label: controller.bookingStatus!.toUpperCase(),
                    tone: "info"),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: controller.isSendingSos ? null : onSos,
                icon:
                    const Icon(Icons.sos_rounded, color: Colors.red, size: 18),
                label: const Text("SOS", style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _openPlaceSearch(context, isPickup: true),
            child: _RouteRow(
                label: "My Location", value: pickupText, accent: _pickupColor),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _openPlaceSearch(context, isPickup: false),
            child: _RouteRow(
                label: "Where to?",
                value: dropoffText,
                accent: DesignTokens.muted),
          ),
          const SizedBox(height: 4),
          Text(
            "Tap the map once for pickup, then again for drop-off.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (controller.isValidatingTap)
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text("Checking nearest road…",
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          if (controller.isLoadingRoute)
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text("Calculating route…",
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          Text(
            "Distance: ${controller.estimatedDistanceKm.toStringAsFixed(2)} km",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Number of Passengers",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: controller.passengerCount <=
                            PassengerRideController.minPassengers
                        ? null
                        : () => controller
                            .setPassengerCount(controller.passengerCount - 1),
                  ),
                  Text(
                    "${controller.passengerCount}",
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: controller.passengerCount >=
                            PassengerRideController.maxPassengers
                        ? null
                        : () => controller
                            .setPassengerCount(controller.passengerCount + 1),
                  ),
                ],
              ),
            ],
          ),
          Text(
            "Estimated Fare: ${formatMoney(controller.estimatedFare)}",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Text("Payment Method: 💵 Cash", style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          ElevatedButton(
            // Disabled while a chosen rider is deciding, or a trip is
            // already under way.
            onPressed: onFindRide == null ||
                    controller.isWaitingForDriverResponse ||
                    (controller.bookingStatus != null &&
                        controller.bookingStatus != "pending" &&
                        kActiveBookingStatuses
                            .contains(controller.bookingStatus))
                ? null
                : () async {
                    await onFindRide!();
                  },
            child: controller.isSubmittingRide
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    controller.isChoosingDriver
                        ? "Pumili ng Rider (${nearbyDrivers.length} online)"
                        : controller.isWaitingForDriverResponse
                            ? "Hinihintay ang sagot ng rider…"
                            : "Find Ride",
                  ),
          ),
          if (controller.rideNotice != null &&
              controller.activeBookingId != null &&
              !controller.hasCompletedBooking &&
              controller.bookingStatus != "cancelled") ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DesignTokens.bg3,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DesignTokens.border),
              ),
              child: Row(
                children: [
                  if (controller.isWaitingForDriverResponse ||
                      (controller.isChoosingDriver && nearbyDrivers.isEmpty))
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(Icons.info_outline_rounded,
                          color: DesignTokens.accent, size: 18),
                    ),
                  Expanded(
                    child: Text(
                      controller.rideNotice!,
                      style: const TextStyle(color: DesignTokens.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (controller.shouldShowPickupPin) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DesignTokens.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DesignTokens.accent.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pin_rounded, color: DesignTokens.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Share this PIN with your driver at pickup",
                          style: TextStyle(
                            color: DesignTokens.muted,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          controller.pickupPin!,
                          style: const TextStyle(
                            color: DesignTokens.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (controller.driverInfo != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DesignTokens.bg3,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DesignTokens.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pedal_bike_rounded,
                          color: DesignTokens.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          driverName == null
                              ? "Assigned driver"
                              : "$driverName${driverTricycle == null ? "" : " - $driverTricycle"}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: DesignTokens.text,
                          ),
                        ),
                      ),
                      if (controller.driverRating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 18),
                            Text(
                              controller.driverRating!.toStringAsFixed(1),
                              style: const TextStyle(color: DesignTokens.text),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (controller.driverDistanceToPickupKm != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "Driver distance: ${controller.driverDistanceToPickupKm!.toStringAsFixed(2)} km",
                        style: const TextStyle(color: DesignTokens.muted),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (controller.bookingStatus != null) ...[
            const SizedBox(height: 10),
            Text(
              "Booking Status: ${controller.isWaitingForDriverResponse ? "Hinihintay ang rider" : bookingStatusLabel(controller.bookingStatus)}",
              style: const TextStyle(
                  color: _pickupColor, fontWeight: FontWeight.w600),
            ),
          ],
          if (controller.hasCompletedBooking) ...[
            const SizedBox(height: 8),
            Text(
              "Total Fare: ${formatMoney(double.tryParse(controller.bookingData?["final_fare"]?.toString() ?? "") ?? controller.estimatedFare)}",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Text("Payment Method: 💵 Cash",
                style: TextStyle(fontSize: 13)),
            if (controller.activeBookingId != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    _rateRide(context, controller.activeBookingId!),
                icon: const Icon(Icons.star_outline_rounded),
                label: const Text("Rate Your Ride"),
              ),
            ],
          ],
          if (controller.error != null) ...[
            const SizedBox(height: 8),
            Text(
              controller.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          if (nearbyDrivers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              "Nearby Drivers (${nearbyDrivers.length})",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: nearbyDrivers.take(4).length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final driver = nearbyDrivers[index];
                  final label = _driverChipLabel(driver);
                  final distance = double.tryParse(
                      driver["distanceToPickupKm"]?.toString() ?? "");
                  return _DriverChip(
                    label: label,
                    subtitle: distance == null
                        ? null
                        : "${distance.toStringAsFixed(2)} km",
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReset,
                  child: const Text("Reset"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel == null
                      ? null
                      : () async {
                          await onCancel!();
                        },
                  child: controller.isCompletingAction
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Cancel Ride"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _rateRide(BuildContext context, int bookingId) async {
    final apiClient = context.read<ApiClient>();
    final rated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => Provider<BookingRepository>(
          create: (_) => BookingRepository(PassengerRepository(apiClient)),
          child: RatingPage(bookingId: bookingId),
        ),
      ),
    );
    if (rated == true) {
      onReset?.call();
    }
  }

  String _driverChipLabel(Map<String, dynamic> driver) {
    final name =
        asText(driver["full_name"]) ?? asText(driver["fullName"]) ?? "Driver";
    final tricycle =
        asText(driver["tricycle_number"]) ?? asText(driver["tricycleNumber"]);
    if (tricycle == null) return name;
    return "$name - $tricycle";
  }

  Future<void> _openPlaceSearch(
    BuildContext context, {
    required bool isPickup,
  }) async {
    final place = await Navigator.push<PlaceSuggestion?>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceSearchPage(
          title: isPickup ? "Search pickup location" : "Search destination",
        ),
      ),
    );
    if (place == null) return;

    if (isPickup) {
      await controller.setPickupFromSearch(place);
    } else {
      await controller.setDropoffFromSearch(place);
    }
  }
}

class _MapStatusCard extends StatelessWidget {
  const _MapStatusCard({
    required this.mapReady,
    required this.passengerName,
    required this.onNotificationsTap,
  });

  final bool mapReady;
  final String passengerName;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: DesignTokens.bg3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DesignTokens.border),
              ),
              alignment: Alignment.center,
              child: Text(
                passengerName
                    .split(' ')
                    .where((segment) => segment.isNotEmpty)
                    .map((segment) => segment[0])
                    .take(2)
                    .join()
                    .toUpperCase(),
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                passengerName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: DesignTokens.text,
                      fontWeight: FontWeight.w700,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _StatusChip(
              label: mapReady ? "LIVE" : "LOADING",
              tone: mapReady ? "success" : "warning",
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onNotificationsTap,
              icon: const Icon(Icons.notifications_outlined, size: 20),
              color: DesignTokens.text,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: "Notifications",
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignTokens.bg2,
      elevation: 4,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await onPressed();
        },
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DesignTokens.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverChip extends StatelessWidget {
  const _DriverChip({
    required this.label,
    required this.subtitle,
  });

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DesignTokens.bg3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DesignTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: DesignTokens.text,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: DesignTokens.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.tone,
  });

  final String label;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final foreground = switch (tone) {
      "success" => DesignTokens.green,
      "warning" => DesignTokens.warning,
      "info" => DesignTokens.blue,
      _ => DesignTokens.muted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: foreground.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withAlpha(50)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: DesignTokens.muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DesignTokens.text, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnnotationBatch {
  const _AnnotationBatch({
    required this.circles,
    required this.lines,
    required this.bounds,
    required this.fitKey,
  });

  final List<ml.CircleOptions> circles;
  final List<ml.LineOptions> lines;
  final ml.LatLngBounds? bounds;
  final String fitKey;
}

class _DriverMarker {
  const _DriverMarker({
    required this.id,
    required this.point,
    required this.label,
    required this.distanceKm,
    required this.tone,
  });

  final int id;
  final ml.LatLng point;
  final String label;
  final double? distanceKm;
  final String tone;
}

String _pickupColorToHex() => "#0E8C46";
String _dropoffColorToHex() => "#C94530";
String _currentColorToHex() => "#1471C5";
String _liveDriverColorToHex() => "#0A7BD4";
String _nearbyDriverColorToHex() => "#136F3A";
String _assignedDriverColorToHex() => "#F0B429";
String _routeColorToHex() => "#0E8C46";
String _driverRouteColorToHex() => "#205C37";

/// One rider in the "Pumili ng rider" sheet.
class _DriverOptionTile extends StatelessWidget {
  const _DriverOptionTile({
    required this.driver,
    required this.isNearest,
    required this.enabled,
    required this.onTap,
  });

  final Map<String, dynamic> driver;
  final bool isNearest;
  final bool enabled;
  final Future<void> Function(int driverId) onTap;

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse(driver["id"]?.toString() ?? "");
    final name = asText(driver["full_name"]) ?? "Rider";
    final tricycle = asText(driver["tricycle_number"]) ?? "-";
    final rating = double.tryParse(driver["rating"]?.toString() ?? "") ?? 0;
    final rides = int.tryParse(driver["total_rides"]?.toString() ?? "") ?? 0;
    final distance =
        double.tryParse(driver["distanceToPickupKm"]?.toString() ?? "");

    return ListTile(
      enabled: enabled && id != null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isNearest ? DesignTokens.accent : DesignTokens.border,
        ),
      ),
      tileColor: DesignTokens.bg3,
      leading: const CircleAvatar(
        backgroundColor: DesignTokens.accent,
        child: Icon(Icons.pedal_bike_rounded, color: DesignTokens.bg),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: DesignTokens.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isNearest) ...[
            const SizedBox(width: 6),
            const AppBadge(
                label: "Pinakamalapit", style: BadgeStyle.greenStyle),
          ],
        ],
      ),
      subtitle: Text(
        [
          "Tricycle $tricycle",
          if (distance != null)
            distance < 1
                ? "${(distance * 1000).round()} m ang layo"
                : "${distance.toStringAsFixed(1)} km ang layo",
          "$rides rides",
        ].join("  •  "),
        style: const TextStyle(color: DesignTokens.muted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 18),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(color: DesignTokens.text),
          ),
        ],
      ),
      onTap: id == null ? null : () => onTap(id),
    );
  }
}

/// Always-visible pickup PIN chip shown over the map until the trip starts.
class _PickupPinBanner extends StatelessWidget {
  const _PickupPinBanner({
    required this.pin,
    required this.highlight,
    required this.onTap,
  });

  final String pin;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? DesignTokens.accent : DesignTokens.bg2,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.pin_rounded,
                color: highlight ? DesignTokens.bg : DesignTokens.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  highlight
                      ? "Nandito na ang rider — ibigay ang PIN"
                      : "Pickup PIN (ibigay sa rider pagdating)",
                  style: TextStyle(
                    color: highlight ? DesignTokens.bg : DesignTokens.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                pin,
                style: TextStyle(
                  color: highlight ? DesignTokens.bg : DesignTokens.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
