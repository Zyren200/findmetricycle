import "dart:typed_data";
import "dart:ui" as ui;

import "package:flutter/material.dart";

import "app_map.dart";

/// Marker icons for the MapLibre maps, drawn at runtime from Material
/// icons (no image assets to ship). Register once per map after its style
/// loads, then use the names as `iconImage`.
class MapMarkerIcons {
  MapMarkerIcons._();

  /// "You are here" — lagoon dot (passenger).
  static const String me = "fmt-me";

  /// Pickup — lagoon dot.
  static const String pickup = "fmt-pickup";

  /// Drop-off — orange pin.
  static const String dropoff = "fmt-dropoff";

  /// Online rider near the passenger.
  static const String rider = "fmt-rider";

  /// Rider assigned to this passenger's ride (larger).
  static const String assignedRider = "fmt-rider-assigned";

  /// The rider's own position on the driver map.
  static const String self = "fmt-rider-self";

  // Sunrise: lagoon for you and the pickup, orange for the drop-off and
  // riders.
  static const Color _lagoon = Color(0xFF1FC8B4);
  static const Color _orange = Color(0xFFFF7A1A);

  /// Renders and registers every marker. [pixelRatio] should be the
  /// device's pixel ratio: the map plugin treats image pixels as physical
  /// pixels, so this keeps markers the same on-screen size on every phone.
  static Future<void> register(AppMapController map, double pixelRatio) async {
    final icons = <String, Future<Uint8List>>{
      me: dot(_lagoon, pixelRatio, diameter: 22),
      pickup: dot(_lagoon, pixelRatio, diameter: 22),
      dropoff: dropPin(_orange, pixelRatio),
      rider: trike(_orange, pixelRatio, diameter: 32),
      assignedRider: trike(_orange, pixelRatio, diameter: 38),
      self: trike(_orange, pixelRatio, diameter: 40),
    };
    for (final entry in icons.entries) {
      await map.addImage(entry.key, await entry.value);
    }
    await map.allowMarkerOverlap();
  }

  /// Solid dot with a thick white ring (you / pickup), anchor center.
  static Future<Uint8List> dot(Color color, double pixelRatio,
      {double diameter = 22}) {
    final size = diameter + 4;
    return _render(size, size, pixelRatio, (canvas) {
      final center = Offset(size / 2, size / 2);
      final radius = diameter / 2;
      canvas.drawShadow(
          Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
          Colors.black,
          2,
          false);
      canvas.drawCircle(center, radius, Paint()..color = Colors.white);
      canvas.drawCircle(center, radius - 4, Paint()..color = color);
    });
  }

  /// Rider: white disc with a hairline, an orange core and a white heading
  /// arrow (anchor center).
  static Future<Uint8List> trike(Color color, double pixelRatio,
      {double diameter = 32}) {
    final size = diameter + 4;
    return _render(size, size, pixelRatio, (canvas) {
      final center = Offset(size / 2, size / 2);
      final outer = diameter / 2;
      final inner = outer * 0.72;
      canvas.drawShadow(
          Path()..addOval(Rect.fromCircle(center: center, radius: outer)),
          Colors.black,
          2.5,
          false);
      canvas.drawCircle(center, outer, Paint()..color = Colors.white);
      canvas.drawCircle(
          center,
          outer - 0.5,
          Paint()
            ..color = const Color(0x291C1814)
            ..style = PaintingStyle.stroke);
      canvas.drawCircle(center, inner, Paint()..color = color);
      final a = inner * 0.52;
      final arrow = Path()
        ..moveTo(center.dx, center.dy - a)
        ..lineTo(center.dx + a * 0.85, center.dy + a * 0.85)
        ..lineTo(center.dx, center.dy + a * 0.42)
        ..lineTo(center.dx - a * 0.85, center.dy + a * 0.85)
        ..close();
      canvas.drawPath(arrow, Paint()..color = Colors.white);
    });
  }

  /// Drop-off: orange teardrop with a white centre, tip at the bottom
  /// (anchor bottom).
  static Future<Uint8List> dropPin(Color color, double pixelRatio,
      {double width = 32, double height = 42}) {
    return _render(width, height, pixelRatio, (canvas) {
      final r = width / 2 - 3;
      final c = Offset(width / 2, r + 3);
      final tip = Offset(width / 2, height - 2);
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..quadraticBezierTo(c.dx - r * 0.95, c.dy + r * 0.9, c.dx - r, c.dy)
        ..arcToPoint(Offset(c.dx + r, c.dy), radius: Radius.circular(r))
        ..quadraticBezierTo(c.dx + r * 0.95, c.dy + r * 0.9, tip.dx, tip.dy)
        ..close();
      canvas.drawShadow(path, Colors.black, 2.5, false);
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawCircle(c, r * 0.36, Paint()..color = Colors.white);
    });
  }

  /// Teardrop location pin, [width]×[height] logical pixels, tip at the
  /// bottom centre (use anchor "bottom").
  static Future<Uint8List> pin(
    Color color,
    IconData glyph,
    double pixelRatio, {
    double width = 26,
    double height = 34,
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
        ..quadraticBezierTo(
            center.dx + radius * 0.95, center.dy + radius * 0.9, tip.dx, tip.dy)
        ..close();

      canvas.drawShadow(path, Colors.black, 2.5, false);
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _drawGlyph(canvas, glyph, center, radius * 2 * glyphScale, Colors.white);
    });
  }

  /// Round badge with an icon, [diameter] logical pixels (anchor "center").
  static Future<Uint8List> badge(
    Color color,
    IconData glyph,
    double pixelRatio, {
    double diameter = 24,
  }) {
    final size = diameter + 4; // room for the shadow
    return _render(size, size, pixelRatio, (canvas) {
      final center = Offset(size / 2, size / 2);
      final radius = diameter / 2 - 1.5;
      final circle = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius));
      canvas.drawShadow(circle, Colors.black, 2.5, false);
      canvas.drawCircle(center, radius, Paint()..color = color);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
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
