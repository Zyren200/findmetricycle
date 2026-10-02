import "dart:math" as math;

import "package:flutter/material.dart";
import "package:latlong2/latlong.dart" as ll;
import "package:maplibre_gl/maplibre_gl.dart" as ml;
import "package:provider/provider.dart";

import "../../../../core/config/app_config.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../../core/widgets/app_map.dart";
import "../../../../core/widgets/map_marker_icons.dart";
import "../driver_ride_controller.dart";

/// The rider's map: their own position, and the pickup / drop-off pins and
/// route of the incoming or active booking — all read from the ambient
/// [DriverRideController].
class DriverRideMap extends StatefulWidget {
  const DriverRideMap({super.key, this.borderRadius = 0});

  final double borderRadius;

  @override
  State<DriverRideMap> createState() => _DriverRideMapState();
}

class _DriverRideMapState extends State<DriverRideMap> {
  static const ll.LatLng _fallbackCenter = ll.LatLng(14.5995, 120.9842);

  DriverRideController? _rideController;
  AppMapController? _mapController;
  bool _mapReady = false;
  String? _lastFitKey;

  final List<ml.Circle> _staticCircles = [];
  final List<ml.Symbol> _staticSymbols = [];
  String? _staticKey;
  bool _iconsReady = false;
  ml.Circle? _currentLocationCircle;
  ml.Symbol? _currentLocationSymbol;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = context.read<DriverRideController>();
    if (_rideController == ctrl) return;
    _rideController?.removeListener(_applyMapData);
    _rideController = ctrl..addListener(_applyMapData);
  }

  @override
  void dispose() {
    _rideController?.removeListener(_applyMapData);
    super.dispose();
  }

  Future<void> _handleStyleLoaded() async {
    final map = _mapController;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    if (map != null) {
      try {
        await MapMarkerIcons.register(map, pixelRatio);
        _iconsReady = true;
      } catch (_) {
        _iconsReady = false; // plain circles instead
      }
    }
    if (!mounted) return;
    _staticKey = null;
    setState(() => _mapReady = true);
    _applyMapData();
  }

  Future<void> _applyMapData() async {
    final map = _mapController;
    final ctrl = _rideController;
    if (map == null || ctrl == null || !_mapReady) return;

    try {
      await _updateStaticLayer(map, ctrl);
      await _updateCurrentLocation(map, ctrl);

      final bounds = _buildBounds(ctrl);
      final fitKey = _buildFitKey(ctrl);
      if (bounds != null && fitKey != _lastFitKey) {
        _lastFitKey = fitKey;
        await map.animateCameraBounds(bounds,
            left: 32, top: 32, right: 32, bottom: 32);
      }
    } catch (_) {
      // ignore map update failures from state changes during dispose
    }
  }

  Future<void> _updateStaticLayer(
      AppMapController map, DriverRideController ctrl) async {
    final pickup = ctrl.pickupLocation;
    final dropoff = ctrl.dropoffLocation;
    String key(ll.LatLng? p) => p == null
        ? "-"
        : "${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}";
    final hasDriverLeg = ctrl.currentPosition != null && pickup != null;
    final staticKey = "$_iconsReady|${key(pickup)}|${key(dropoff)}|"
        "${hasDriverLeg ? key(ctrl.currentPosition) : "-"}";
    if (staticKey == _staticKey) return;
    _staticKey = staticKey;

    if (_staticCircles.isNotEmpty) {
      await map.removeCircles(_staticCircles);
      _staticCircles.clear();
    }
    if (_staticSymbols.isNotEmpty) {
      await map.removeSymbols(List.of(_staticSymbols));
      _staticSymbols.clear();
    }
    await map.clearLines();

    final lines = <ml.LineOptions>[];
    for (final poly in ctrl.polylines) {
      final pts = [
        for (final p in poly.points) ml.LatLng(p.latitude, p.longitude)
      ];
      if (pts.isEmpty) continue;
      String hex(double c) =>
          (c * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, "0");
      lines.add(ml.LineOptions(
        geometry: pts,
        lineColor:
            "#${hex(poly.color.r)}${hex(poly.color.g)}${hex(poly.color.b)}",
        lineWidth: poly.strokeWidth.toDouble(),
        lineOpacity: poly.isDotted ? 0.6 : 0.9,
      ));
    }
    if (lines.isNotEmpty) await map.addLines(lines);

    final pins = <(ll.LatLng, String, String)>[
      if (pickup != null) (pickup, MapMarkerIcons.pickup, "#0E8C46"),
      if (dropoff != null) (dropoff, MapMarkerIcons.dropoff, "#C94530"),
    ];
    for (final (point, icon, color) in pins) {
      final target = ml.LatLng(point.latitude, point.longitude);
      if (_iconsReady) {
        _staticSymbols.add(await map.addMarker(target, icon, anchor: "bottom"));
      } else {
        _staticCircles.add(await map.addCircle(ml.CircleOptions(
          geometry: target,
          circleRadius: 10,
          circleColor: color,
          circleOpacity: 0.96,
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: 2,
        )));
      }
    }
  }

  bool _moved(ml.LatLng? from, ml.LatLng to) =>
      from == null ||
      (from.latitude - to.latitude).abs() > 0.00001 ||
      (from.longitude - to.longitude).abs() > 0.00001;

  Future<void> _updateCurrentLocation(
      AppMapController map, DriverRideController ctrl) async {
    final position = ctrl.currentPosition;
    if (position == null) {
      if (_currentLocationCircle != null) {
        await map.removeCircle(_currentLocationCircle!);
        _currentLocationCircle = null;
      }
      if (_currentLocationSymbol != null) {
        await map.removeSymbol(_currentLocationSymbol!);
        _currentLocationSymbol = null;
      }
      return;
    }

    final target = ml.LatLng(position.latitude, position.longitude);
    final halo = _currentLocationCircle;
    if (halo == null) {
      _currentLocationCircle = await map.addCircle(ml.CircleOptions(
        geometry: target,
        circleRadius: _iconsReady ? 16 : 8,
        circleColor: "#1471C5",
        // Solid dot only when the rider icon isn't available.
        circleOpacity: _iconsReady ? 0.15 : 0.98,
        circleStrokeColor: "#FFFFFF",
        circleStrokeWidth: _iconsReady ? 1.5 : 2,
      ));
    } else if (_moved(halo.options.geometry, target)) {
      await map.moveCircleSmooth(halo, target, durationMs: 500, steps: 12);
    }

    if (_iconsReady) {
      final badge = _currentLocationSymbol;
      if (badge == null) {
        _currentLocationSymbol =
            await map.addMarker(target, MapMarkerIcons.self);
      } else if (_moved(badge.options.geometry, target)) {
        await map.moveSymbolSmooth(badge, target,
            durationMs: 500, steps: 12, rotate: false);
      }
    }
  }

  ml.LatLngBounds? _buildBounds(DriverRideController ctrl) {
    final points = [
      ctrl.currentPosition,
      ctrl.pickupLocation,
      ctrl.dropoffLocation,
    ].whereType<ll.LatLng>().toList();
    if (points.isEmpty) return null;

    var minLat = double.infinity;
    var minLng = double.infinity;
    var maxLat = -double.infinity;
    var maxLng = -double.infinity;
    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLat = math.max(maxLat, point.latitude);
      maxLng = math.max(maxLng, point.longitude);
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

  String _buildFitKey(DriverRideController ctrl) => [
        ctrl.currentPosition,
        ctrl.pickupLocation,
        ctrl.dropoffLocation,
      ]
          .map((p) => p == null
              ? "-"
              : "${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}")
          .join("|");

  @override
  Widget build(BuildContext context) {
    final start = _rideController?.currentPosition ?? _fallbackCenter;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              initialStyleUrl: AppConfig.openFreeMapStyleUrl,
              initialPosition: ml.LatLng(start.latitude, start.longitude),
              onMapCreated: (map) {
                _mapController = map;
                _applyMapData();
              },
              onStyleLoaded: _handleStyleLoaded,
            ),
          ),
          if (!_mapReady)
            Positioned.fill(
              child: Container(
                color: DesignTokens.bg2,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
