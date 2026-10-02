import "dart:async";
import "dart:math";

import "package:flutter/material.dart";
import "package:latlong2/latlong.dart" as ll;
import "package:maplibre_gl/maplibre_gl.dart" as ml;
import "package:provider/provider.dart";

import "../../../../core/config/app_config.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../../core/utils/geo_utils.dart";
import "../../../../core/widgets/app_map.dart";
import "../../../../core/widgets/map_marker_icons.dart";
import "../passenger_ride_controller.dart";

/// The passenger's live map: "you are here", pickup / drop-off pins, the
/// road route, nearby and assigned riders. Everything it draws comes from
/// the ambient [PassengerRideController], so every passenger screen that
/// embeds it (home, booking steps, ride status) shows the same state.
class PassengerRideMap extends StatefulWidget {
  const PassengerRideMap({
    super.key,
    this.onTap,
    this.showControls = true,
    this.borderRadius = 0,
  });

  /// Called with the tapped coordinate; null makes the map view-only.
  final void Function(ll.LatLng point)? onTap;
  final bool showControls;
  final double borderRadius;

  @override
  State<PassengerRideMap> createState() => _PassengerRideMapState();
}

class _PassengerRideMapState extends State<PassengerRideMap> {
  static const ll.LatLng _fallbackCenter = ll.LatLng(14.5995, 120.9842);

  PassengerRideController? _rideController;
  AppMapController? _mapController;

  bool _mapReady = false;
  bool _mapSlow = false;
  Timer? _mapSlowTimer;
  bool _syncQueued = false;
  bool _syncInProgress = false;
  bool _syncPending = false;
  bool _hasCenteredOnUser = false;
  String? _lastFitKey;

  final List<ml.Circle> _staticCircles = [];
  final List<ml.Symbol> _staticSymbols = [];
  // Signature of what the static layer (route, pins, riders) last drew, so
  // it's only rebuilt when something actually changed.
  String? _staticKey;
  bool _iconsReady = false;
  ml.Circle? _currentLocationCircle; // soft halo under the "you" pin
  ml.Symbol? _currentLocationSymbol;
  ml.Symbol? _assignedDriverSymbol;

  @override
  void initState() {
    super.initState();
    _mapSlowTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_mapReady) setState(() => _mapSlow = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<PassengerRideController>();
    if (_rideController == controller) return;

    _rideController?.removeListener(_requestSync);
    _rideController = controller;
    _rideController?.addListener(_requestSync);
    _requestSync();
  }

  @override
  void dispose() {
    _mapSlowTimer?.cancel();
    _rideController?.removeListener(_requestSync);
    super.dispose();
  }

  void _handleMapCreated(AppMapController controller) {
    _mapController = controller;
    _requestSync();
  }

  Future<void> _handleStyleLoaded() async {
    if (!mounted) return;

    final map = _mapController;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    if (map != null) {
      try {
        await MapMarkerIcons.register(map, pixelRatio);
        _iconsReady = true;
      } catch (_) {
        // Fall back to plain circles if the icons can't be registered.
        _iconsReady = false;
      }
    }
    if (!mounted) return;

    _staticKey = null;
    setState(() => _mapReady = true);
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

        if (batch.staticKey != _staticKey) {
          _staticKey = batch.staticKey;
          if (_staticCircles.isNotEmpty) {
            await map.removeCircles(_staticCircles);
            _staticCircles.clear();
          }
          if (_staticSymbols.isNotEmpty) {
            await map.removeSymbols(List.of(_staticSymbols));
            _staticSymbols.clear();
          }
          await map.clearLines();

          if (batch.lines.isNotEmpty) {
            await map.addLines(batch.lines);
          }
          for (final option in batch.circles) {
            _staticCircles.add(await map.addCircle(option));
          }
          for (final marker in batch.markers) {
            _staticSymbols.add(
              await map.addMarker(marker.point, marker.icon,
                  anchor: marker.anchor),
            );
          }
        }

        await _updateDynamicCircles(controller);

        if (!_hasCenteredOnUser &&
            controller.currentPosition != null &&
            controller.dropoff == null) {
          // First real GPS fix: snap straight to it at a close zoom instead
          // of the generic bounds fit (or the fallback center).
          _hasCenteredOnUser = true;
          _lastFitKey = batch.fitKey;
          await map.animateCamera(
            _toMapLibre(controller.currentPosition)!,
            zoom: 16.2,
          );
        } else if (batch.bounds != null && batch.fitKey != _lastFitKey) {
          _hasCenteredOnUser = true;
          _lastFitKey = batch.fitKey;
          await map.animateCameraBounds(
            batch.bounds!,
            left: 36,
            top: 36,
            right: 36,
            bottom: 36,
          );
        }
      } while (_syncPending && mounted);
    } catch (_) {
      // Map disposed mid-update.
    } finally {
      _syncInProgress = false;
    }
  }

  _AnnotationBatch _buildAnnotationBatch(PassengerRideController controller) {
    final circles = <ml.CircleOptions>[];
    final lines = <ml.LineOptions>[];
    final fitPoints = <ml.LatLng>[];

    void addFitPoint(ml.LatLng? point) {
      if (point != null) fitPoints.add(point);
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
          geometry: routeGeometry ?? [pickup!, dropoff!],
          lineColor: "#0E8C46",
          lineWidth: 4.5,
          lineOpacity: 0.82,
        ),
      );
    }

    if (assignedDriver != null && pickup != null) {
      lines.add(
        ml.LineOptions(
          geometry: [assignedDriver, pickup],
          lineColor: "#205C37",
          lineWidth: 3.4,
          lineOpacity: 0.7,
        ),
      );
    }

    final markers = <_MapMarker>[];
    // The blue "you" pin already marks the pickup when it's where you
    // stand — only add the green pickup pin when it's somewhere else.
    final pickupIsHere = pickup != null &&
        currentLocation != null &&
        haversineKm(
              lat1: pickup.latitude,
              lng1: pickup.longitude,
              lat2: currentLocation.latitude,
              lng2: currentLocation.longitude,
            ) <
            0.025;
    if (pickup != null && !pickupIsHere) {
      markers
          .add(_MapMarker(pickup, MapMarkerIcons.pickup, "bottom", "#0E8C46"));
    }
    if (dropoff != null) {
      markers.add(
          _MapMarker(dropoff, MapMarkerIcons.dropoff, "bottom", "#C94530"));
    }
    for (final driver in driverMarkers) {
      if (driver.tone == "assigned") continue; // drawn as a moving symbol
      markers.add(_MapMarker(
        driver.point,
        MapMarkerIcons.rider,
        "center",
        driver.tone == "nearby" ? "#136F3A" : "#0A7BD4",
      ));
    }

    if (!_iconsReady) {
      // Icons unavailable: plain coloured circles instead.
      for (final marker in markers) {
        circles.add(ml.CircleOptions(
          geometry: marker.point,
          circleRadius: 9,
          circleColor: marker.fallbackColor,
          circleOpacity: 0.96,
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: 2,
        ));
      }
      markers.clear();
    }

    String pointKey(ml.LatLng p) =>
        "${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}";
    final staticKey = [
      _iconsReady,
      for (final line in lines)
        "${line.geometry?.length}:${line.geometry?.isNotEmpty == true ? pointKey(line.geometry!.first) + pointKey(line.geometry!.last) : ""}",
      for (final m in markers) "${m.icon}@${pointKey(m.point)}",
      for (final c in circles) "c@${pointKey(c.geometry!)}",
    ].join("|");

    return _AnnotationBatch(
      circles: circles,
      markers: markers,
      lines: lines,
      bounds: _buildBounds(fitPoints),
      fitKey: _buildFitKey(controller, driverMarkers),
      staticKey: staticKey,
    );
  }

  List<_DriverMarker> _buildDriverMarkers(PassengerRideController controller) {
    final markers = <_DriverMarker>[];
    final liveIds = <int>{};
    final nearbyIds = <int>{};
    final assignedId =
        int.tryParse(controller.driverInfo?["id"]?.toString() ?? "");

    for (final entry in controller.liveDrivers.entries) {
      final point = _extractPoint(entry.value);
      if (point == null) continue;
      liveIds.add(entry.key);
      markers.add(_DriverMarker(
        id: entry.key,
        point: point,
        distanceKm: _distanceFromPickup(point, controller.pickup),
        tone: "live",
      ));
    }

    for (final rawDriver in controller.nearbyDrivers) {
      final id = int.tryParse(rawDriver["id"]?.toString() ?? "");
      final point = _extractPoint(rawDriver);
      if (point == null || id == null) continue;
      if (liveIds.contains(id) || nearbyIds.contains(id)) continue;
      nearbyIds.add(id);
      markers.add(_DriverMarker(
        id: id,
        point: point,
        distanceKm:
            double.tryParse(rawDriver["distanceToPickupKm"]?.toString() ?? ""),
        tone: "nearby",
      ));
    }

    if (assignedId != null) {
      final assignedPoint = _extractPoint(controller.driverInfo) ??
          _toMapLibre(controller.driverPosition);
      if (assignedPoint != null) {
        markers.removeWhere((marker) => marker.id == assignedId);
        markers.add(_DriverMarker(
          id: assignedId,
          point: assignedPoint,
          distanceKm: controller.driverDistanceToPickupKm,
          tone: "assigned",
        ));
      }
    }

    markers.sort((a, b) => (a.distanceKm ?? double.infinity)
        .compareTo(b.distanceKm ?? double.infinity));
    return markers;
  }

  bool _moved(ml.LatLng? from, ml.LatLng to) =>
      from == null ||
      (from.latitude - to.latitude).abs() > 0.00001 ||
      (from.longitude - to.longitude).abs() > 0.00001;

  Future<void> _updateDynamicCircles(PassengerRideController controller) async {
    final map = _mapController;
    if (map == null) return;

    final currentLocation = _toMapLibre(controller.currentPosition);
    final assignedDriver = _toMapLibre(controller.driverPosition);

    // "You are here": a soft halo with the blue location pin on top.
    if (currentLocation != null) {
      final halo = _currentLocationCircle;
      if (halo == null) {
        _currentLocationCircle = await map.addCircle(ml.CircleOptions(
          geometry: currentLocation,
          circleRadius: 11,
          circleColor: "#1471C5",
          // Solid dot only when the pin icon isn't available.
          circleOpacity: _iconsReady ? 0.18 : 0.9,
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: 1.5,
        ));
      } else if (_moved(halo.options.geometry, currentLocation)) {
        await map.moveCircleSmooth(halo, currentLocation,
            durationMs: 500, steps: 12);
      }

      if (_iconsReady) {
        final pin = _currentLocationSymbol;
        if (pin == null) {
          _currentLocationSymbol = await map
              .addMarker(currentLocation, MapMarkerIcons.me, anchor: "bottom");
        } else if (_moved(pin.options.geometry, currentLocation)) {
          await map.moveSymbolSmooth(pin, currentLocation,
              durationMs: 500, steps: 12, rotate: false);
        }
      }
    } else {
      if (_currentLocationCircle != null) {
        await map.removeCircle(_currentLocationCircle!);
        _currentLocationCircle = null;
      }
      if (_currentLocationSymbol != null) {
        await map.removeSymbol(_currentLocationSymbol!);
        _currentLocationSymbol = null;
      }
    }

    // The rider on their way to you.
    if (assignedDriver != null && _iconsReady) {
      final rider = _assignedDriverSymbol;
      if (rider == null) {
        _assignedDriverSymbol =
            await map.addMarker(assignedDriver, MapMarkerIcons.assignedRider);
      } else if (_moved(rider.options.geometry, assignedDriver)) {
        await map.moveSymbolSmooth(rider, assignedDriver,
            durationMs: 500, steps: 12, rotate: false);
      }
    } else if (_assignedDriverSymbol != null) {
      await map.removeSymbol(_assignedDriverSymbol!);
      _assignedDriverSymbol = null;
    }
  }

  ml.LatLngBounds? _buildBounds(List<ml.LatLng> points) {
    if (points.isEmpty) return null;
    var minLat = double.infinity;
    var minLng = double.infinity;
    var maxLat = -double.infinity;
    var maxLng = -double.infinity;
    for (final point in points) {
      minLat = min(minLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLat = max(maxLat, point.latitude);
      maxLng = max(maxLng, point.longitude);
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
    final driverIds = driverMarkers
        .where((driver) => driver.tone != "live")
        .map((driver) => driver.id)
        .toList()
      ..sort();
    return [
      _pointKey(controller.currentPosition),
      _pointKey(controller.pickup),
      _pointKey(controller.dropoff),
      _pointKey(controller.driverPosition),
      driverIds.join(","),
    ].join("|");
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
      final parsed = double.tryParse(raw[key]?.toString() ?? "");
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return null;
  }

  String _pointKey(ll.LatLng? point) => point == null
      ? "-"
      : "${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}";

  double? _distanceFromPickup(ml.LatLng point, ll.LatLng? pickup) {
    if (pickup == null) return null;
    return haversineKm(
      lat1: point.latitude,
      lng1: point.longitude,
      lat2: pickup.latitude,
      lng2: pickup.longitude,
    );
  }

  ml.LatLng? _toMapLibre(ll.LatLng? point) =>
      point == null ? null : ml.LatLng(point.latitude, point.longitude);

  Future<void> _moveToCurrentLocation() async {
    final map = _mapController;
    final point = _rideController?.currentPosition ?? _fallbackCenter;
    await map?.animateCamera(ml.LatLng(point.latitude, point.longitude),
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
        left: 36, top: 36, right: 36, bottom: 36);
  }

  @override
  Widget build(BuildContext context) {
    final start = _rideController?.currentPosition ?? _fallbackCenter;
    final onTap = widget.onTap;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              initialStyleUrl: AppConfig.openFreeMapStyleUrl,
              initialPosition: ml.LatLng(start.latitude, start.longitude),
              onMapCreated: _handleMapCreated,
              onStyleLoaded: _handleStyleLoaded,
              onMapClick: onTap == null
                  ? null
                  : (Point<double> _, ml.LatLng coordinates) => onTap(
                      ll.LatLng(coordinates.latitude, coordinates.longitude)),
            ),
          ),
          if (!_mapReady)
            Positioned.fill(
              child: Container(
                color: DesignTokens.bg2,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_mapSlow)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(Icons.wifi_off_rounded, color: DesignTokens.muted),
                    const SizedBox(height: 10),
                    Text(
                      _mapSlow
                          ? "Mabagal mag-load ang mapa — tingnan ang internet mo."
                          : "Nilo-load ang mapa…",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DesignTokens.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.showControls && _mapReady)
            Positioned(
              right: 8,
              bottom: 8,
              child: Column(
                children: [
                  _MapButton(
                    icon: Icons.my_location_rounded,
                    tooltip: "Center",
                    onPressed: _moveToCurrentLocation,
                  ),
                  const SizedBox(height: 6),
                  _MapButton(
                    icon: Icons.zoom_out_map_rounded,
                    tooltip: "Fit",
                    onPressed: _fitToSelection,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignTokens.bg2,
      elevation: 3,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 20, color: DesignTokens.text),
        onPressed: () => onPressed(),
      ),
    );
  }
}

class _AnnotationBatch {
  const _AnnotationBatch({
    required this.circles,
    required this.markers,
    required this.lines,
    required this.bounds,
    required this.fitKey,
    required this.staticKey,
  });

  final List<ml.CircleOptions> circles;
  final List<_MapMarker> markers;
  final List<ml.LineOptions> lines;
  final ml.LatLngBounds? bounds;
  final String fitKey;
  final String staticKey;
}

/// An icon marker on the map ([icon] is a MapMarkerIcons name).
class _MapMarker {
  const _MapMarker(this.point, this.icon, this.anchor, this.fallbackColor);

  final ml.LatLng point;
  final String icon;
  final String anchor;
  final String fallbackColor;
}

class _DriverMarker {
  const _DriverMarker({
    required this.id,
    required this.point,
    required this.distanceKm,
    required this.tone,
  });

  final int id;
  final ml.LatLng point;
  final double? distanceKm;
  final String tone;
}
