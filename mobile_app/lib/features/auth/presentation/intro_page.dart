import "package:flutter/material.dart";

import "../../../core/components/prism.dart";
import "../../../core/components/sunrise.dart";
import "../../../core/theme/design_tokens.dart";

/// First launch only: three swipeable slides — book in seconds, know
/// who's coming, safe on every ride — each with a small glass
/// illustration, then [onDone].
class IntroPage extends StatefulWidget {
  const IntroPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final _pages = PageController();
  int _slide = 0;

  static const _titles = [
    "Book in seconds",
    "Know who's coming",
    "Safe on every ride",
  ];
  static const _bodies = [
    "Pick where you're going, see your fare first, and find a tricycle nearby.",
    "See your rider's name, tricycle number and rating before you ride.",
    "Every ride has a 4-digit PIN, and the SOS button is always ready.",
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) => _pages.animateToPage(i,
      duration: const Duration(milliseconds: 550), curve: DesignTokens.easeOut);

  @override
  Widget build(BuildContext context) {
    final last = _slide == 2;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Overline("${_slide + 1} / 3"),
                    const Spacer(),
                    SunButton(
                      label: "Skip",
                      tone: SunTone.ghost,
                      height: 40,
                      expand: false,
                      onPressed: widget.onDone,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _slide = i),
                  children: [
                    for (var i = 0; i < 3; i++)
                      _Slide(
                        art: switch (i) {
                          0 => const _BookArt(),
                          1 => const _RiderArt(),
                          _ => const _SafeArt(),
                        },
                        title: _titles[i],
                        body: _bodies[i],
                      ),
                  ],
                ),
              ),
              _Dots(index: _slide),
              const SizedBox(height: 18),
              SunButton(
                label: last ? "Get started" : "Next",
                trailingIcon: Icons.chevron_right_rounded,
                onPressed: last ? widget.onDone : () => _go(_slide + 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.art, required this.title, required this.body});

  final Widget art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(child: FadeRise(child: art)),
        ),
        FadeRise(
          delay: const Duration(milliseconds: 60),
          child: Text(title,
              textAlign: TextAlign.center, style: DesignTokens.display),
        ),
        const SizedBox(height: 12),
        FadeRise(
          delay: const Duration(milliseconds: 120),
          child: Text(body,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: DesignTokens.ink2, fontSize: 14.5, height: 1.55)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Dots, the current one a wide "hot" pill.
class _Dots extends StatelessWidget {
  const _Dots({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Slide ${index + 1} of 3",
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: DesignTokens.snap,
              width: i == index ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: i == index ? null : DesignTokens.lineStrong,
                gradient: i == index ? DesignTokens.hot : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The 240 px glass card every illustration sits on (".ill").
class _IllCard extends StatelessWidget {
  const _IllCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: PrismGlass(
        radius: 24,
        shadows: [
          ...DesignTokens.shadow2,
          BoxShadow(
              color: DesignTokens.glowDusk,
              blurRadius: 90,
              spreadRadius: -50,
              offset: const Offset(0, 40)),
        ],
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _BookArt extends StatelessWidget {
  const _BookArt();

  @override
  Widget build(BuildContext context) {
    Widget loc(bool pickup, String text) => Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: DesignTokens.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DesignTokens.line),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: pickup ? DesignTokens.lagoon : DesignTokens.ember,
                  shape: pickup ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: pickup ? null : BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                        color: pickup ? DesignTokens.lagoon : DesignTokens.ember,
                        blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(text,
                  style: TextStyle(
                      color: DesignTokens.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return _IllCard(children: [
      Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: DesignTokens.inputBg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: DesignTokens.lineStrong),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: DesignTokens.ink2),
            const SizedBox(width: 8),
            Text("Guiuan Public Market",
                style: TextStyle(color: DesignTokens.ink2, fontSize: 13)),
          ],
        ),
      ),
      loc(true, "Your location"),
      loc(false, "Guiuan Public Market"),
    ]);
  }
}

class _RiderArt extends StatelessWidget {
  const _RiderArt();

  @override
  Widget build(BuildContext context) {
    return _IllCard(children: [
      Row(
        children: [
          const ToneAvatar(name: "Ramon Dela Cruz", size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Ramon Dela Cruz",
                    style: TextStyle(
                        color: DesignTokens.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                Text("Tricycle #142 · ★ 4.9",
                    style: TextStyle(color: DesignTokens.ink2, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
      const RideProgressBars(step: 1),
    ]);
  }
}

class _SafeArt extends StatelessWidget {
  const _SafeArt();

  @override
  Widget build(BuildContext context) {
    return _IllCard(children: [
      const DigitBoxes(
          value: "4827", length: 4, readOnly: true, height: 50, fontSize: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_outlined, size: 18, color: DesignTokens.ink1),
          const SizedBox(width: 8),
          Text("Verified drivers only",
              style: TextStyle(color: DesignTokens.ink1, fontSize: 12.5)),
        ],
      ),
    ]);
  }
}
