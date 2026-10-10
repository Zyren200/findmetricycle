import "dart:math" as math;

import "package:flutter/material.dart";

import "../../../../core/components/sunrise.dart";
import "../../../../core/theme/design_tokens.dart";

// Illustrations for the first-launch screens: the FindMeTricycle mark, a
// little Guiuan-style map with a route, and the gently floating chips.

/// The FindMeTricycle mark: a map pin holding a wheel whose spokes turn.
class LogoMark extends StatefulWidget {
  const LogoMark({
    super.key,
    required this.size,
    required this.color,
    required this.cutout,
    this.spin = true,
  });

  final double size;
  final Color color;

  /// The colour behind the pin (the wheel is cut out in it).
  final Color cutout;
  final bool spin;

  @override
  State<LogoMark> createState() => _LogoMarkState();
}

class _LogoMarkState extends State<LogoMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    if (widget.spin) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = !widget.spin || reduceMotion(context);
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _LogoPainter(
            color: widget.color,
            cutout: widget.cutout,
            angle: still ? 0 : _c.value * math.pi * 2,
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(
      {required this.color, required this.cutout, required this.angle});

  final Color color;
  final Color cutout;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    canvas.scale(s);
    // Pin: M32 4C19.8 4 10 13.6 10 25.6 10 41.8 32 60 32 60s22-18.2 22-34.4C54 13.6 44.2 4 32 4z
    final pin = Path()
      ..moveTo(32, 4)
      ..cubicTo(19.8, 4, 10, 13.6, 10, 25.6)
      ..cubicTo(10, 41.8, 32, 60, 32, 60)
      ..cubicTo(32, 60, 54, 41.8, 54, 25.6)
      ..cubicTo(54, 13.6, 44.2, 4, 32, 4)
      ..close();
    canvas.drawPath(pin, Paint()..color = color);
    final stroke = Paint()
      ..color = cutout
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(const Offset(32, 25), 11, stroke);
    canvas.save();
    canvas.translate(32, 25);
    canvas.rotate(angle);
    final spoke = Paint()
      ..color = cutout
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, const Offset(0, -10), spoke);
    canvas.drawLine(Offset.zero, const Offset(8.7, 5), spoke);
    canvas.drawLine(Offset.zero, const Offset(-8.7, 5), spoke);
    canvas.restore();
    canvas.drawCircle(const Offset(32, 25), 3, Paint()..color = cutout);
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.angle != angle || old.color != color || old.cutout != cutout;
}

/// Small static map: water on the right, blocks, a park, roads, and an
/// orange route from a lagoon pickup to an orange pin.
class MiniMap extends StatelessWidget {
  const MiniMap({super.key, this.variant = 0, this.riders = const []});

  /// 0: the intro card, 1: the welcome hero.
  final int variant;

  /// Extra tricycle markers as fractions of the size (x, y, heading°).
  final List<(double, double, double)> riders;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniMapPainter(
        variant: variant,
        riders: riders,
        land: DesignTokens.mapLand,
        block: DesignTokens.mapBlock,
        park: DesignTokens.mapPark,
        water: DesignTokens.mapWater,
        road: DesignTokens.mapRoad,
        route: DesignTokens.primaryBright,
        lagoon: DesignTokens.lagoon,
        surface: DesignTokens.surface,
      ),
      size: Size.infinite,
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({
    required this.variant,
    required this.riders,
    required this.land,
    required this.block,
    required this.park,
    required this.water,
    required this.road,
    required this.route,
    required this.lagoon,
    required this.surface,
  });

  final int variant;
  final List<(double, double, double)> riders;
  final Color land, block, park, water, road, route, lagoon, surface;

  @override
  void paint(Canvas canvas, Size size) {
    // Design coordinates, scaled to cover the box.
    final (vw, vh) = variant == 0 ? (270.0, 210.0) : (366.0, 430.0);
    final scale = math.max(size.width / vw, size.height / vh);
    canvas.drawRect(Offset.zero & size, Paint()..color = land);
    canvas.save();
    canvas.translate(
        (size.width - vw * scale) / 2, (size.height - vh * scale) / 2);
    canvas.scale(scale);

    final fill = Paint();
    RRect r(double x, double y, double w, double h, double rad) =>
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h), Radius.circular(rad));
    final roadPaint = Paint()
      ..color = road
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final routePaint = Paint()
      ..color = route
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (variant == 0) {
      canvas.drawPath(
          Path()
            ..moveTo(200, -5)
            ..cubicTo(186, 50, 236, 100, 220, 215)
            ..lineTo(275, 215)
            ..lineTo(275, -5)
            ..close(),
          fill..color = water);
      canvas.drawRRect(r(16, 20, 50, 46, 8), fill..color = block);
      canvas.drawRRect(r(110, 18, 60, 50, 8), fill..color = park);
      canvas.drawRRect(r(16, 130, 60, 60, 8), fill..color = block);
      canvas.drawLine(const Offset(-5, 92), const Offset(200, 84), roadPaint);
      canvas.drawLine(const Offset(90, -5), const Offset(96, 215), roadPaint);
      canvas.drawPath(
          Path()
            ..moveTo(95, 170)
            ..lineTo(92, 90)
            ..lineTo(160, 86),
          routePaint);
      _dot(canvas, const Offset(95, 170), 8);
      _pin(canvas, const Offset(160, 86), 0.85);
    } else {
      canvas.drawPath(
          Path()
            ..moveTo(262, -5)
            ..cubicTo(240, 90, 300, 170, 286, 260)
            ..cubicTo(276, 330, 320, 380, 330, 440)
            ..lineTo(371, 440)
            ..lineTo(371, -5)
            ..close(),
          fill..color = water);
      fill.color = block;
      for (final b in const [
        (14.0, 20.0, 56.0, 90.0),
        (104.0, 24.0, 70.0, 80.0),
        (14.0, 150.0, 56.0, 110.0),
        (104.0, 146.0, 40.0, 120.0),
        (180.0, 150.0, 60.0, 100.0),
        (14.0, 300.0, 80.0, 110.0),
        (190.0, 300.0, 70.0, 110.0),
      ]) {
        canvas.drawRRect(r(b.$1, b.$2, b.$3, b.$4, 10), fill);
      }
      canvas.drawRRect(r(180, 20, 62, 86, 18), fill..color = park);
      for (final l in const [
        (Offset(-5, 128), Offset(270, 120)),
        (Offset(-5, 282), Offset(280, 270)),
        (Offset(88, -5), Offset(92, 440)),
        (Offset(162, -5), Offset(170, 440)),
      ]) {
        canvas.drawLine(l.$1, l.$2, roadPaint);
      }
      canvas.drawPath(
          Path()
            ..moveTo(90, 360)
            ..lineTo(89, 200)
            ..lineTo(166, 196)
            ..lineTo(168, 124),
          routePaint);
      _dot(canvas, const Offset(90, 360), 9);
      _pin(canvas, const Offset(168, 124), 1);
      _trike(canvas, const Offset(130, 282), 90);
      _trike(canvas, const Offset(60, 128), -90);
    }
    canvas.restore();

    for (final (x, y, heading) in riders) {
      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      _trike(canvas, Offset.zero, heading);
      canvas.restore();
    }
  }

  void _dot(Canvas canvas, Offset c, double radius) {
    canvas.drawCircle(c, radius + 3, Paint()..color = surface);
    canvas.drawCircle(c, radius, Paint()..color = lagoon);
  }

  void _pin(Canvas canvas, Offset at, double k) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(k);
    final pin = Path()
      ..moveTo(0, -34)
      ..cubicTo(-11, -34, -18, -26, -18, -16)
      ..cubicTo(-18, -4, 0, 7, 0, 7)
      ..cubicTo(0, 7, 18, -4, 18, -16)
      ..cubicTo(18, -26, 11, -34, 0, -34)
      ..close();
    canvas.drawPath(pin, Paint()..color = route);
    canvas.drawPath(
        pin,
        Paint()
          ..color = surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    canvas.drawCircle(const Offset(0, -17), 5.5, Paint()..color = surface);
    canvas.restore();
  }

  void _trike(Canvas canvas, Offset c, double headingDeg) {
    canvas.drawCircle(c, 15, Paint()..color = surface);
    canvas.drawCircle(c, 11, Paint()..color = route);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(headingDeg * math.pi / 180);
    canvas.drawPath(
        Path()
          ..moveTo(0, -5.5)
          ..lineTo(4.5, 4.5)
          ..lineTo(0, 2.3)
          ..lineTo(-4.5, 4.5)
          ..close(),
        Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) =>
      old.land != land || old.variant != variant || old.route != route;
}

/// Bobs its child up and down 8 px, forever (unless motion is reduced).
class FloatY extends StatefulWidget {
  const FloatY({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 4200),
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration period;
  final Duration delay;

  @override
  State<FloatY> createState() => _FloatYState();
}

class _FloatYState extends State<FloatY> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    final phase = widget.delay.inMilliseconds / widget.period.inMilliseconds;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(
            0, -8 * (0.5 - 0.5 * math.cos(2 * math.pi * (_c.value + phase)))),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Three dots that pulse in turn (splash loading).
class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key, required this.color});

  final Color color;

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Builder(builder: (_) {
              final t = (_c.value - i * 0.125) % 1;
              final on = t < 0.4 ? t / 0.4 : (t < 0.8 ? (0.8 - t) / 0.4 : 0);
              return Transform.scale(
                scale: 0.8 + 0.2 * on,
                child: Opacity(
                  opacity: 0.3 + 0.7 * on,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: widget.color, shape: BoxShape.circle),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
