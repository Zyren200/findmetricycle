import "package:flutter/material.dart";

import "../../../core/components/prism.dart";
import "../../../core/components/sunrise.dart";
import "../../../core/theme/design_tokens.dart";
import "widgets/onboarding_art.dart";

/// Launch screen while the saved session is restored: the prism logo tile
/// springs in over the aurora, inside a slowly turning halo, with the name
/// and loading dots.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Semantics(
        label: "FindMeTricycle, Guiuan, Eastern Samar. Loading",
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Align(
              alignment: Alignment(0, -0.18),
              child: PrismHalo(size: 300),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _LogoPop(child: PrismMark(size: 96)),
                const SizedBox(height: 18),
                const FadeRise(
                  delay: Duration(milliseconds: 350),
                  duration: Duration(milliseconds: 700),
                  child: PrismWordmark(fontSize: 26),
                ),
                const SizedBox(height: 18),
                LoadingDots(color: DesignTokens.ink1),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Scale up from 40% with a quarter-turn twist, springing into place
/// (".mark.big" — markIn).
class _LogoPop extends StatefulWidget {
  const _LogoPop({required this.child});

  final Widget child;

  @override
  State<_LogoPop> createState() => _LogoPopState();
}

class _LogoPopState extends State<_LogoPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = DesignTokens.spring.transform(_c.value);
        return Opacity(
          opacity: _c.value.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: -0.42 * (1 - t),
            child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
