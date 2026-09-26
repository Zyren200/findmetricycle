import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

/// Thin MapLibre abstraction used by the app.
/// Provides simple symbol management and smooth movement helpers.
class AppMap extends StatefulWidget {
  final void Function(AppMapController)? onMapCreated;
  final VoidCallback? onStyleLoaded;
  final void Function(math.Point<double>, ml.LatLng)? onMapClick;
  final String initialStyleUrl;
  final ml.LatLng? initialPosition;
  final double initialZoom;

  /// Distance (logical px) of the map-credits ⓘ button from the bottom
  /// edge, so it can sit above panels/cards that cover the map's bottom.
  final double attributionBottomInset;

  const AppMap({
    this.onMapCreated,
    this.onStyleLoaded,
    this.onMapClick,
    required this.initialStyleUrl,
    this.initialPosition,
    this.initialZoom = 14.0,
    this.attributionBottomInset = 12,
    super.key,
  });

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  @override
  Widget build(BuildContext context) {
    return ml.MapLibreMap(
      styleString: widget.initialStyleUrl,
      initialCameraPosition: ml.CameraPosition(
        target: widget.initialPosition ?? const ml.LatLng(14.5995, 120.9842),
        zoom: widget.initialZoom,
      ),
      onMapCreated: (ctrl) {
        widget.onMapCreated?.call(AppMapController._(ctrl));
      },
      onStyleLoadedCallback: widget.onStyleLoaded,
      onMapClick: widget.onMapClick,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: true,
      compassEnabled: true,
      myLocationEnabled: false,
      // The data licences require the "© OpenStreetMap contributors" credit;
      // MapLibre shows it behind this small ⓘ button (tap to open). Same
      // corner on Android and iOS, lifted clear of the app's bottom UI.
      logoEnabled: false,
      attributionButtonPosition: ml.AttributionButtonPosition.bottomRight,
      attributionButtonMargins: math.Point(12, widget.attributionBottomInset),
      trackCameraPosition: true,
      minMaxZoomPreference: const ml.MinMaxZoomPreference(3.0, 20.0),
    );
  }
}

class AppMapController {
  final ml.MapLibreMapController _ctrl;

  AppMapController._(this._ctrl);

  Future<void> animateCamera(ml.LatLng target,
      {double zoom = 15.0, int durationMs = 500}) async {
    await _ctrl.animateCamera(ml.CameraUpdate.newCameraPosition(
      ml.CameraPosition(target: target, zoom: zoom),
    ));
  }

  Future<ml.Symbol> addSymbol(ml.LatLng position,
      {String? iconImage, double? iconSize}) async {
    return await _ctrl.addSymbol(ml.SymbolOptions(
      geometry: position,
      iconImage: iconImage ?? "default_marker",
      iconSize: iconSize ?? 1.0,
    ));
  }

  Future<void> updateSymbol(ml.Symbol symbol, ml.LatLng position,
      {double? rotate}) async {
    await _ctrl.updateSymbol(
        symbol, ml.SymbolOptions(geometry: position, iconRotate: rotate));
  }

  /// Registers a bitmap (PNG bytes) that markers can use as `iconImage`.
  Future<void> addImage(String name, Uint8List bytes) async {
    await _ctrl.addImage(name, bytes);
  }

  /// Markers always draw, even where they'd collide with map labels or
  /// each other — a pickup pin must never be hidden by a street name.
  Future<void> allowMarkerOverlap() async {
    await _ctrl.setSymbolIconAllowOverlap(true);
    await _ctrl.setSymbolIconIgnorePlacement(true);
  }

  /// Adds an icon marker. [anchor] is "bottom" for pins (the tip marks the
  /// spot) and "center" for round badges.
  Future<ml.Symbol> addMarker(ml.LatLng position, String iconImage,
      {String anchor = "center"}) async {
    return await _ctrl.addSymbol(ml.SymbolOptions(
      geometry: position,
      iconImage: iconImage,
      iconSize: 1.0,
      iconAnchor: anchor,
    ));
  }

  Future<void> removeSymbols(List<ml.Symbol> symbols) async {
    if (symbols.isEmpty) return;
    await _ctrl.removeSymbols(symbols);
  }

  Future<void> removeSymbol(ml.Symbol symbol) async {
    await _ctrl.removeSymbol(symbol);
  }

  /// Smoothly move a symbol from its current position to [to] over [durationMs].
  /// This uses a simple linear interpolation on a timer. Pass `rotate: false`
  /// for upright icons such as pins.
  Future<void> moveSymbolSmooth(ml.Symbol symbol, ml.LatLng to,
      {int durationMs = 800, int steps = 16, bool rotate = true}) async {
    try {
      final start = symbol.options.geometry!;
      final startLat = start.latitude;
      final startLng = start.longitude;
      final endLat = to.latitude;
      final endLng = to.longitude;

      for (var i = 1; i <= steps; i++) {
        final t = i / steps;
        final curLat = _lerp(startLat, endLat, t);
        final curLng = _lerp(startLng, endLng, t);
        final heading = _bearing(startLat, startLng, endLat, endLng);
        await updateSymbol(symbol, ml.LatLng(curLat, curLng),
            rotate: rotate ? heading : null);
        await Future.delayed(
            Duration(milliseconds: (durationMs / steps).round()));
      }
    } catch (_) {
      // best-effort: ignore errors from controller being disposed
    }
  }

  Future<ml.Circle> addCircle(ml.CircleOptions circle) async {
    return await _ctrl.addCircle(circle);
  }

  Future<void> updateCircle(ml.Circle circle, ml.CircleOptions changes) async {
    await _ctrl.updateCircle(circle, changes);
  }

  /// Smoothly move a circle from its current position to [to] over [durationMs].
  Future<void> moveCircleSmooth(ml.Circle circle, ml.LatLng to,
      {int durationMs = 800, int steps = 16}) async {
    try {
      final start = circle.options.geometry!;
      final startLat = start.latitude;
      final startLng = start.longitude;
      final endLat = to.latitude;
      final endLng = to.longitude;

      for (var i = 1; i <= steps; i++) {
        final t = i / steps;
        final curLat = _lerp(startLat, endLat, t);
        final curLng = _lerp(startLng, endLng, t);
        await updateCircle(circle, ml.CircleOptions(geometry: ml.LatLng(curLat, curLng)));
        await Future.delayed(
            Duration(milliseconds: (durationMs / steps).round()));
      }
    } catch (_) {
      // best-effort: ignore errors from controller being disposed
    }
  }

  Future<void> removeCircle(ml.Circle circle) async {
    await _ctrl.removeCircle(circle);
  }

  Future<void> removeCircles(List<ml.Circle> circles) async {
    for (final circle in circles) {
      await _ctrl.removeCircle(circle);
    }
  }

  Future<void> clearCircles() async {
    await _ctrl.clearCircles();
  }

  Future<void> addCircles(List<ml.CircleOptions> circles) async {
    for (final c in circles) {
      await _ctrl.addCircle(c);
    }
  }

  Future<void> clearLines() async {
    await _ctrl.clearLines();
  }

  Future<void> addLines(List<ml.LineOptions> lines) async {
    for (final l in lines) {
      await _ctrl.addLine(l);
    }
  }

  Future<void> animateCameraBounds(ml.LatLngBounds bounds,
      {double left = 0,
      double top = 0,
      double right = 0,
      double bottom = 0}) async {
    await _ctrl.animateCamera(ml.CameraUpdate.newLatLngBounds(bounds,
        left: left, top: top, right: right, bottom: bottom));
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _bearing(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = _deg2rad(lat1);
    final phi2 = _deg2rad(lat2);
    final deltaLam = _deg2rad(lon2 - lon1);
    final y = math.sin(deltaLam) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLam);
    var theta = math.atan2(y, x);
    theta = theta * 180 / math.pi;
    return (theta + 360) % 360;
  }

  static double _deg2rad(double deg) => deg * math.pi / 180.0;
}
