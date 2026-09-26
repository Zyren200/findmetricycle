import "dart:typed_data";
import "dart:ui" as ui;

import "package:flutter/material.dart";

import "app_map.dart";

/// Marker icons for the MapLibre maps, drawn at runtime from Material
/// icons (no image assets to ship). Register once per map after its style
/// loads, then use the names as `iconImage`.
class MapMarkerIcons {
  MapMarkerIcons._();

  /// "You are here" — blue location pin (passenger).
  static const String me = "fmt-me";

  /// Pickup — green location pin.
  static const String pickup = "fmt-pickup";

  /// Drop-off — red pin with a flag.
  static const String dropoff = "fmt-dropoff";

  /// Online rider near the passenger.
  static const String rider = "fmt-rider";

  /// Rider assigned to this passenger's ride (larger, amber).
  static const String assignedRider = "fmt-rider-assigned";

  /// The rider's own position on the driver map.
  static const String self = "fmt-rider-self";

  static const Color _blue = Color(0xFF1471C5);
  static const Color _green = Color(0xFF0E8C46);
  static const Color _red = Color(0xFFC94530);
  static const Color _riderGreen = Color(0xFF136F3A);
  static const Color _amber = Color(0xFFF0B429);

  /// Renders and registers every marker. [pixelRatio] should be the
  /// device's pixel ratio: the map plugin treats image pixels as physical
  /// pixels, so this keeps markers the same on-screen size on every phone.
  static Future<void> register(AppMapController map, double pixelRatio) async {
    final icons = <String, Future<Uint8List>>{
      me: pin(_blue, Icons.person_rounded, pixelRatio),
      pickup: pin(_green, Icons.circle, pixelRatio, glyphScale: 0.42),
      dropoff: pin(_red, Icons.flag_rounded, pixelRatio),
      rider: badge(_riderGreen, Icons.two_wheeler_rounded, pixelRatio),
      assignedRider: badge(
        _amber,
        Icons.two_wheeler_rounded,
        pixelRatio,
        diameter: 42,
      ),
      self: badge(_blue, Icons.two_wheeler_rounded, pixelRatio, diameter: 40),
    };
    for (final entry in icons.entries) {
      await map.addImage(entry.key, await entry.value);
    }
    await map.allowMarkerOverlap();
  }

  /// Teardrop location pin, [width]×[height] logical pixels, tip at the
  /// bottom centre (use anchor "bottom").
  static Future<Uint8List> pin(
    Color color,
    IconData glyph,
    double pixelRatio, {
    double width = 38,
    double height = 50,
    double glyphScale = 0.55,
  }) {
    return _render(width, height, pixelRatio, (canvas) {
      final radius = width / 2 - 3;
      final center = Offset(width / 2, radius + 3);
      final tip = Offset(width / 2, height - 2);

      // Circle head plus a tapered tail meeting it tangentially.
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..quadraticBezierTo(center.dx - radius * 0.95, center.dy + radius * 0.9,
            center.dx - radius, center.dy)
        ..arcToPoint(Offset(center.dx + radius, center.dy),
            radius: Radius.circular(radius))
        ..quadraticBezierTo(center.dx + radius * 0.95, center.dy + radius * 0.9,
            tip.dx, tip.dy)
        ..close();

      canvas.drawShadow(path, Colors.black, 2.5, false);
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      _drawGlyph(canvas, glyph, center, radius * 2 * glyphScale, Colors.white);
    });
  }

  /// Round badge with an icon, [diameter] logical pixels (anchor "center").
  static Future<Uint8List> badge(
    Color color,
    IconData glyph,
    double pixelRatio, {
    double diameter = 34,
  }) {
    final size = diameter + 4; // room for the shadow
    return _render(size, size, pixelRatio, (canvas) {
      final center = Offset(size / 2, size / 2);
      final radius = diameter / 2 - 1.5;
      final circle = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
      canvas.drawShadow(circle, Colors.black, 2.5, false);
      canvas.drawCircle(center, radius, Paint()..color = color);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      _drawGlyph(canvas, glyph, center, diameter * 0.58, Colors.white);
    });
  }

  static void _drawGlyph(
    Canvas canvas,
    IconData glyph,
    Offset center,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(glyph.codePoint),
        style: TextStyle(
          fontFamily: glyph.fontFamily,
          package: glyph.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  static Future<Uint8List> _render(
    double width,
    double height,
    double pixelRatio,
    void Function(Canvas canvas) draw,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    draw(canvas);
    final image = await recorder.endRecording().toImage(
          (width * pixelRatio).ceil(),
          (height * pixelRatio).ceil(),
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}
