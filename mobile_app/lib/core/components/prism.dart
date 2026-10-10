import "dart:math" as math;
import "dart:ui" as ui;

import "package:flutter/foundation.dart" show listEquals;
import "package:flutter/material.dart";

import "../theme/design_tokens.dart";

// Prism Night primitives shared by every screen: the prism rim drawn around
// glass, the glass panel itself, the aurora behind pages, the logo tile, the
// gradient text accent and the page transition. Same recipe as the driver
// application website.

/// Looping decoration (a spinning rim, a sweeping shine) runs only in the
/// real app: widget tests wait for animations to settle, and these never do.
/// Tests are recognised by their binding (dart:io's Platform.environment
/// isn't available on the web and threw "Unsupported operation").
bool get ambientMotionAllowed => !WidgetsBinding.instance.runtimeType
    .toString()
    .contains("TestWidgetsFlutterBinding");

/// Whether looping decoration may run here (also off with reduced motion).
bool ambientMotion(BuildContext context) =>
    ambientMotionAllowed &&
    !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

// ── Prism rim ───────────────────────────────────────────────────────────

/// A 1 px conic ember › amber › lagoon › dusk ring along a rounded shape.
class PrismRimPainter extends CustomPainter {
  PrismRimPainter({
    required this.radius,
    required this.opacity,
    this.angle = 0,
    this.circle = false,
    this.width = 1,
  });

  final double radius;
  final double opacity;
  final double angle;
  final bool circle;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || size.isEmpty) return;
    final rect = Offset.zero & size;
    final colors = [
      for (final c in DesignTokens.prismRim)
        c.withValues(alpha: c.a * opacity),
    ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..isAntiAlias = true
      ..shader = SweepGradient(
        colors: colors,
        stops: DesignTokens.prismRimStops,
        transform: GradientRotation(angle),
      ).createShader(rect);
    final inner = rect.deflate(width / 2);
    if (circle) {
      canvas.drawOval(inner, paint);
    } else {
      final r = math.min(radius, size.shortestSide / 2) - width / 2;
      canvas.drawRRect(
          RRect.fromRectAndRadius(inner, Radius.circular(math.max(r, 0))),
          paint);
    }
  }

  @override
  bool shouldRepaint(PrismRimPainter old) =>
      old.radius != radius ||
      old.opacity != opacity ||
      old.angle != angle ||
      old.circle != circle ||
      old.width != width;
}

/// Paints the prism rim over [child]; with [spin] it travels slowly around
/// the edge (14 s a turn), as on the website's sheets and tab bar.
class PrismRim extends StatefulWidget {
  const PrismRim({
    super.key,
    required this.child,
    this.radius = DesignTokens.radiusGlass,
    this.opacity,
    this.spin = false,
    this.circle = false,
    this.angle = 0,
    this.period = const Duration(seconds: 14),
    this.reverse = false,
    this.width = 1,
  });

  final Widget child;
  final double radius;
  final double? opacity;
  final bool spin;
  final bool circle;
  final double angle;
  final Duration period;
  final bool reverse;
  final double width;

  @override
  State<PrismRim> createState() => _PrismRimState();
}

class _PrismRimState extends State<PrismRim>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = widget.spin && ambientMotion(context);
    if (run && _c == null) {
      _c = AnimationController(vsync: this, duration: widget.period)..repeat();
    } else if (!run && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  PrismRimPainter _painter(double turn) => PrismRimPainter(
        radius: widget.radius,
        opacity: widget.opacity ??
            (widget.spin
                ? DesignTokens.rimOpacityStrong
                : DesignTokens.rimOpacity),
        angle: widget.angle + (widget.reverse ? -1 : 1) * turn * 2 * math.pi,
        circle: widget.circle,
        width: widget.width,
      );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return CustomPaint(foregroundPainter: _painter(0), child: widget.child);
    }
    return AnimatedBuilder(
      animation: c,
      builder: (_, child) =>
          CustomPaint(foregroundPainter: _painter(c.value), child: child),
      child: widget.child,
    );
  }
}

// ── Shadows ─────────────────────────────────────────────────────────────

/// Box shadows drawn only *outside* a rounded shape, like CSS box-shadow:
/// see-through glass must not show its own shadow through itself. A layer
/// whose negative spread would turn the shape inside out is skipped.
class OuterShadow extends StatelessWidget {
  const OuterShadow({
    super.key,
    required this.shadows,
    required this.child,
    this.radius = 0,
    this.circle = false,
  });

  final List<BoxShadow>? shadows;
  final Widget child;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final list = shadows;
    if (list == null || list.isEmpty) return child;
    return CustomPaint(
      painter: _OuterShadowPainter(list, radius, circle),
      child: child,
    );
  }
}

class _OuterShadowPainter extends CustomPainter {
  _OuterShadowPainter(this.shadows, this.radius, this.circle);

  final List<BoxShadow> shadows;
  final double radius;
  final bool circle;

  RRect _shape(Rect r, double extra) {
    final rr = circle
        ? r.shortestSide / 2
        : math.max(0.0, math.min(radius + extra, r.shortestSide / 2));
    return RRect.fromRectAndRadius(r, Radius.circular(rr));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(600)),
      Path()..addRRect(_shape(rect, 0)),
    );
    canvas.save();
    canvas.clipPath(outside);
    for (final s in shadows) {
      final r = rect.shift(s.offset).inflate(s.spreadRadius);
      if (r.width <= 0 || r.height <= 0 || s.color.a == 0) continue;
      final paint = Paint()..color = s.color;
      if (s.blurRadius > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blurSigma);
      }
      canvas.drawRRect(_shape(r, s.spreadRadius), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) =>
      old.radius != radius ||
      old.circle != circle ||
      !listEquals(old.shadows, shadows);
}

// ── Glass ───────────────────────────────────────────────────────────────

/// Frosted glass with the prism rim, matching `.glass` on the website.
/// [strong] is for sheets and dialogs (more opaque); the default is for
/// chips and pills floating over the map.
class PrismGlass extends StatelessWidget {
  const PrismGlass({
    super.key,
    required this.child,
    this.padding,
    this.radius = DesignTokens.radiusGlass,
    this.strong = false,
    this.spin = false,
    this.circle = false,
    this.width,
    this.height,
    this.shadows,
    this.tint,
    this.blur = 16,
    this.rim = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool strong;
  final bool spin;
  final bool circle;
  final double? width;
  final double? height;
  final List<BoxShadow>? shadows;
  final Color? tint;
  final double blur;
  final bool rim;

  @override
  Widget build(BuildContext context) {
    final shape = circle
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final borderShape = circle
        ? CircleBorder(side: BorderSide(color: DesignTokens.glassBorder))
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(color: DesignTokens.glassBorder),
          );
    final sheen = DesignTokens.glassSheen;
    Widget body = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: tint ?? (strong ? DesignTokens.glassStrong : DesignTokens.glass),
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: borderShape,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: sheen,
            stops: const [0, 0.62],
          ),
        ),
        child: padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
    if (rim) {
      body = PrismRim(radius: radius, spin: spin, circle: circle, child: body);
    }
    return SizedBox(
      width: width,
      height: height,
      child: OuterShadow(
        shadows: shadows ?? DesignTokens.shadow2,
        radius: radius,
        circle: circle,
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: body,
          ),
        ),
      ),
    );
  }
}

// ── Page backdrop ───────────────────────────────────────────────────────

/// The page behind every non-map screen: midnight (or lavender-white) with
/// soft aurora glows in the corners, like `.page.solid` in the design.
class PrismBackdrop extends StatelessWidget {
  const PrismBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AuroraPainter(
        bg: DesignTokens.background,
        a1: DesignTokens.aurora1,
        a2: DesignTokens.aurora2,
        a4: DesignTokens.aurora4,
      ),
      child: child,
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(
      {required this.bg, required this.a1, required this.a2, required this.a4});

  final Color bg;
  final Color a1;
  final Color a2;
  final Color a4;

  void _glow(Canvas canvas, Offset c, double rx, double ry, Color color,
      double fade) {
    if (rx <= 0 || ry <= 0) return;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, ry / rx);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
        stops: [0, fade],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: rx));
    canvas.drawCircle(Offset.zero, rx, paint);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final w = size.width, h = size.height;
    _glow(canvas, Offset(w * .9, -h * .08), w * 1.2, h * .6, a1, .62);
    _glow(canvas, Offset(-w * .12, h * 1.04), w * .9, h * .5, a2, .62);
    _glow(canvas, Offset(w * 1.1, h * .7), w * .7, h * .4, a4, .7);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.bg != bg || old.a1 != a1 || old.a2 != a2 || old.a4 != a4;
}

/// Page transition: the new page slides in 44 px and fades up while the old
/// one eases 32 px the other way (`.page.in-fwd` / `.out-fwd`), and every
/// opaque page gets the aurora backdrop.
class PrismPageTransitionsBuilder extends PageTransitionsBuilder {
  const PrismPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final page = route.opaque ? PrismBackdrop(child: child) : child;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return page;
    return _PrismTransition(
      animation: animation,
      secondary: secondaryAnimation,
      child: page,
    );
  }
}

class _PrismTransition extends StatelessWidget {
  const _PrismTransition(
      {required this.animation, required this.secondary, required this.child});

  final Animation<double> animation;
  final Animation<double> secondary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondary]),
      builder: (_, c) {
        final t = DesignTokens.easeOut.transform(animation.value);
        final s = DesignTokens.easeOut.transform(secondary.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(44 * (1 - t) - 32 * s, 0),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

// ── Brand ───────────────────────────────────────────────────────────────

/// The logo tile: a tricycle on the prism-gradient rounded square.
class PrismMark extends StatelessWidget {
  const PrismMark({super.key, this.size = 38});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: DesignTokens.markFill,
        borderRadius: BorderRadius.circular(size * 0.33),
        boxShadow: [
          BoxShadow(
              color: DesignTokens.glowEmber,
              blurRadius: 16,
              spreadRadius: -6,
              offset: const Offset(0, 6)),
          BoxShadow(
              color: DesignTokens.glowDusk, blurRadius: 24, spreadRadius: -8),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size.square(size * 0.52),
          painter: TrikePainter(color: Colors.white, shadow: true),
        ),
      ),
    );
  }
}

/// The design's line tricycle (24 px grid).
class TrikePainter extends CustomPainter {
  TrikePainter({required this.color, this.shadow = false, this.stroke = 2});

  final Color color;
  final bool shadow;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.save();
    canvas.scale(k);
    Path trike() => Path()
      ..addOval(Rect.fromCircle(center: const Offset(6, 17), radius: 2.5))
      ..addOval(Rect.fromCircle(center: const Offset(18, 17), radius: 2.5))
      ..moveTo(8.5, 17)
      ..lineTo(15.5, 17)
      ..moveTo(4, 13)
      ..lineTo(4, 8)
      ..arcToPoint(const Offset(6, 6), radius: const Radius.circular(2))
      ..lineTo(12, 6)
      ..lineTo(15, 11)
      ..lineTo(18.5, 11)
      ..arcToPoint(const Offset(20.5, 13), radius: const Radius.circular(2))
      ..lineTo(20.5, 15)
      ..moveTo(12, 6)
      ..lineTo(12, 11)
      ..lineTo(15, 11);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (shadow) {
      canvas.drawPath(
          trike().shift(const Offset(0, .6)),
          Paint()
            ..color = const Color(0x73000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .8));
    }
    canvas.drawPath(trike(), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(TrikePainter old) =>
      old.color != color || old.shadow != shadow || old.stroke != stroke;
}

/// "FindMe**Tricycle**" with the amber › ember gradient on the second word.
class PrismWordmark extends StatelessWidget {
  const PrismWordmark({super.key, this.fontSize = 18});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -fontSize * 0.035,
      height: 1,
      color: DesignTokens.ink,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("FindMe", style: style),
        GradientText("Tricycle",
            style: style,
            colors: [DesignTokens.amberInk, DesignTokens.emberInk]),
      ],
    );
  }
}

/// Text filled with a horizontal gradient.
class GradientText extends StatelessWidget {
  const GradientText(this.text,
      {super.key, required this.style, required this.colors, this.textAlign});

  final String text;
  final TextStyle style;
  final List<Color> colors;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => LinearGradient(colors: colors)
          .createShader(Rect.fromLTWH(0, 0, rect.width, rect.height)),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}

/// The italic serif accent with the drifting prism gradient
/// (".glow" — "one tap away.", "Guiuan.").
class GlowText extends StatefulWidget {
  const GlowText(this.text, {super.key, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  State<GlowText> createState() => _GlowTextState();
}

class _GlowTextState extends State<GlowText>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ambientMotion(context) && _c == null) {
      _c = AnimationController(
          vsync: this, duration: const Duration(seconds: 10))
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Widget _paint(double shift) {
    final style = TextStyle(
      fontFamily: DesignTokens.fontSerif,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
      fontSize: widget.fontSize * 1.1,
      height: 0.95,
      letterSpacing: -widget.fontSize * 0.01,
      color: Colors.white,
    );
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) {
        // 200%-wide gradient sliding across the word, as on the website.
        final w = rect.width * 2;
        return LinearGradient(
          colors: DesignTokens.glowText,
          stops: const [0, .24, .48, .72, 1],
        ).createShader(Rect.fromLTWH(-shift * rect.width, 0, w, rect.height));
      },
      child: Text(widget.text, style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return _paint(0);
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) =>
          _paint(DesignTokens.easeInOut.transform(c.value)),
    );
  }
}

/// A ring of the prism gradient spinning slowly behind the splash and
/// welcome screens (".halo-ring").
class PrismHalo extends StatefulWidget {
  const PrismHalo({super.key, this.size = 300});

  final double size;

  @override
  State<PrismHalo> createState() => _PrismHaloState();
}

class _PrismHaloState extends State<PrismHalo>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ambientMotion(context) && _c == null) {
      _c = AnimationController(
          vsync: this, duration: const Duration(seconds: 40))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Widget _ring(double turn) => CustomPaint(
        size: Size.square(widget.size),
        painter: _HaloPainter(
          turn: turn,
          colors: [
            DesignTokens.aurora3,
            DesignTokens.aurora1,
            DesignTokens.aurora2,
            DesignTokens.aurora4,
            DesignTokens.aurora3,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return IgnorePointer(
      child: c == null
          ? _ring(0)
          : AnimatedBuilder(animation: c, builder: (_, __) => _ring(c.value)),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.turn, required this.colors});

  final double turn;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: r);
    // A soft band between 40% and 100% of the radius, brightest at 62%.
    final band = Paint()
      ..shader = SweepGradient(
        colors: colors,
        transform: GradientRotation(turn * 2 * math.pi),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .36
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .12);
    canvas.drawCircle(center, r * .64, band);
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.turn != turn;
}
