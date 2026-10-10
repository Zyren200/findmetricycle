import 'package:flutter/material.dart';

/// FindMeTricycle "Prism Night" design tokens — the same values as the
/// driver application website, so the app and the site read as one product.
///
/// Ember (orange) for every action, lagoon for trust, pickup and "online",
/// dusk (violet) for the glow behind glass, red only for SOS. Glass panels
/// float over a midnight sky; the light theme ("Prism Daylight") swaps to
/// frosted white glass. Every colour has a dark and a light value.
class DesignTokens {
  // ── Theme ──
  // The app sets [isDark] from the Appearance preference (see main.dart)
  // and rebuilds every screen when it changes.
  static bool isDark = false;

  static Color _pick(Color dark, Color light) => isDark ? dark : light;

  // ── Prism palette ──
  static Color get ember =>
      _pick(const Color(0xFFFF7A1A), const Color(0xFFE85A00));
  static Color get amber =>
      _pick(const Color(0xFFFFB23F), const Color(0xFFD98A06));
  static Color get dusk =>
      _pick(const Color(0xFF7867FF), const Color(0xFF6A57F0));
  static Color get emberInk =>
      _pick(const Color(0xFFFF9548), const Color(0xFFB04300));
  static Color get amberInk =>
      _pick(const Color(0xFFFFC56B), const Color(0xFF875300));
  static Color get duskInk =>
      _pick(const Color(0xFFADA2FF), const Color(0xFF5240D4));
  static Color get ok => _pick(const Color(0xFF3BE3A6), const Color(0xFF0B7A53));
  static Color get onOk =>
      _pick(const Color(0xFF03170F), const Color(0xFFFFFFFF));
  static Color get warn =>
      _pick(const Color(0xFFFFBE55), const Color(0xFF8F5500));
  static Color get danger =>
      _pick(const Color(0xFFFF6B7B), const Color(0xFFC42637));

  // ── Surfaces ──
  /// The page: midnight in dark, lavender-white in light.
  static Color get background =>
      _pick(const Color(0xFF04050C), const Color(0xFFF3F1F8));
  static Color get bgDeep =>
      _pick(const Color(0xFF0A0C1D), const Color(0xFFFFFFFF));
  static Color get bgRaised =>
      _pick(const Color(0xFF131630), const Color(0xFFEAE6F3));

  /// Cards and list groups: a faint tint over the page (see-through, so the
  /// aurora behind a page shows).
  static Color get surface =>
      _pick(const Color(0x0BFFFFFF), const Color(0x8CFFFFFF));
  static Color get surface2 =>
      _pick(const Color(0x14FFFFFF), const Color(0xD1FFFFFF));
  static Color get surface3 =>
      _pick(const Color(0x21FFFFFF), const Color(0xFFFFFFFF));

  /// Opaque panel colour (dialogs, menus, anything that must hide what is
  /// behind it).
  static Color get solid =>
      _pick(const Color(0xFF0D0E20), const Color(0xFFFDFCFF));

  /// Text field fill.
  static Color get inputBg =>
      _pick(const Color(0x7303040E), const Color(0xC7FFFFFF));
  static Color get pillBg =>
      _pick(const Color(0x1CFFFFFF), const Color(0xFFFFFFFF));

  static Color get ink => _pick(const Color(0xFFF5F3FF), const Color(0xFF16131F));
  static Color get ink1 =>
      _pick(const Color(0xFFDCDAF0), const Color(0xFF2C2840));
  static Color get ink2 =>
      _pick(const Color(0xFFABB0CD), const Color(0xFF575270));
  static Color get line => _pick(
      const Color(0x14FFFFFF), // rgba(255,255,255,.08)
      const Color(0x172E1E5A)); // rgba(46,30,90,.09)
  static Color get lineStrong => _pick(
      const Color(0x26FFFFFF), // rgba(255,255,255,.15)
      const Color(0x292E1E5A)); // rgba(46,30,90,.16)
  /// Top-edge highlight on raised surfaces.
  static Color get hi => _pick(const Color(0x24FFFFFF), const Color(0xF2FFFFFF));

  // ── Roles ──
  /// Buttons and selected states (ember).
  static Color get primary => ember;

  /// Map pins and the route — never text.
  static Color get primaryBright => ember;

  /// Text and icons on a "hot" button.
  static Color get primaryInk => const Color(0xFF190A00);
  static Color get primarySoft =>
      _pick(const Color(0x1FFF7A1A), const Color(0x1FE85A00));

  /// Orange labels and numbers.
  static Color get primaryText => emberInk;

  /// Trust, pickup, success, "online".
  static Color get lagoon =>
      _pick(const Color(0xFF1FC8B4), const Color(0xFF0B8F80));
  static Color get lagoonInk => onOk;
  static Color get lagoonSoft =>
      _pick(const Color(0x291FC8B4), const Color(0x1F0B8F80));
  static Color get lagoonText =>
      _pick(const Color(0xFF47E4CF), const Color(0xFF066B61));

  /// Emergency only — the fill of the SOS button, the same in both themes.
  static const Color sos = Color(0xFFE0283C);
  static const Color sosInk = Color(0xFFFFFFFF);
  static Color get sosSoft =>
      _pick(const Color(0x24FF6B7B), const Color(0x1AC42637));
  static Color get sosText => danger;

  static Color get star => amber;
  static Color get focus =>
      _pick(const Color(0xFF62F2DE), const Color(0xFF0B8F80));
  static Color get scrim =>
      _pick(const Color(0x9402030A), const Color(0x42281E46));

  /// Glass over the map: chips, the tab bar, status pills.
  static Color get glass =>
      _pick(const Color(0x8C0B0D20), const Color(0xC7FFFFFF));

  /// Strong glass: sheets and dialogs.
  static Color get glassStrong =>
      _pick(const Color(0xDB0D0E20), const Color(0xE6FFFFFF));
  static Color get glassBorder =>
      _pick(const Color(0x13FFFFFF), const Color(0xCCFFFFFF));

  /// The diagonal sheen laid over glass.
  static List<Color> get glassSheen => isDark
      ? const [Color(0x1AFFFFFF), Color(0x05FFFFFF)]
      : const [Color(0xD6FFFFFF), Color(0x85FFFFFF)];

  /// How strongly the prism rim shows on a glass edge.
  static double get rimOpacity => isDark ? 0.42 : 0.8;
  static double get rimOpacityStrong => isDark ? 0.95 : 1.0;

  // Earnings chart bars.
  static Color get bar => surface3;
  static Color get barSelected => ember;

  // Splash.
  static Color get splashBg => background;
  static Color get splashInk => ember;

  // Map (illustrations, and the area outside Guiuan).
  static Color get mapLand =>
      _pick(const Color(0xFF090B1A), const Color(0xFFF8F6FC));
  static Color get mapBlock =>
      _pick(const Color(0x09FFFFFF), const Color(0x0B2E1E5A));
  static Color get mapPark =>
      _pick(const Color(0xFF0B1C1E), const Color(0xFFDDF0E8));
  static Color get mapWater =>
      _pick(const Color(0xFF06141A), const Color(0xFFD7EFEC));
  static Color get mapRoad =>
      _pick(const Color(0x24FFFFFF), const Color(0xFFFFFFFF));
  static Color get mapDim =>
      _pick(const Color(0x8C02030A), const Color(0x1A3C2D6E));
  static Color get mapEdge =>
      _pick(const Color(0x73ADA2FF), const Color(0x736A57F0));
  static Color get mapLabel =>
      _pick(const Color(0xFF6C7192), const Color(0xFF8D88A6));

  // Aurora glows behind pages.
  static Color get aurora1 =>
      _pick(const Color(0x7A6E5CFF), const Color(0x75AC9CFF));
  static Color get aurora2 =>
      _pick(const Color(0x5218BEAC), const Color(0x6664DEC8));
  static Color get aurora3 =>
      _pick(const Color(0x57FF761E), const Color(0x7AFFA67C));
  static Color get aurora4 =>
      _pick(const Color(0x33FF548C), const Color(0x5CFFD474));

  // Glows.
  static Color get glowEmber =>
      _pick(const Color(0x8CFF6E1E), const Color(0x73FF8046));
  static Color get glowLagoon =>
      _pick(const Color(0x731FC8B4), const Color(0x6128BEAA));
  static Color get glowDusk =>
      _pick(const Color(0x997867FF), const Color(0x6B826CFF));
  static Color get glowDanger =>
      _pick(const Color(0x7AFF5C6C), const Color(0x4DDC3246));
  static Color get glowOk =>
      _pick(const Color(0x6B3BE3A6), const Color(0x5214AA6E));

  // ── Gradients ──
  /// The "hot" fill of primary buttons.
  static const LinearGradient hot = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFC24F), Color(0xFFFF8A1F), Color(0xFFFF5A1F)],
    stops: [0, 0.46, 1],
  );
  static const LinearGradient lagoonFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4FE6D2), Color(0xFF12A595), Color(0xFF0B7A98)],
    stops: [0, 0.55, 1],
  );
  static const LinearGradient emberFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFC24F), Color(0xFFFF7A1A), Color(0xFFEE4E16)],
    stops: [0, 0.55, 1],
  );
  static const LinearGradient duskFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA99DFF), Color(0xFF7867FF), Color(0xFF4B3FD1)],
    stops: [0, 0.55, 1],
  );
  static const LinearGradient dangerFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B7B), Color(0xFFE0283C)],
  );
  static const LinearGradient okFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4BEBB2), Color(0xFF0E9E6E)],
  );

  /// The logo tile.
  static const SweepGradient markFill = SweepGradient(
    startAngle: 0,
    endAngle: 6.2832,
    transform: GradientRotation(3.75),
    colors: [
      Color(0xFFFFC24F),
      Color(0xFFFF7A1A),
      Color(0xFFFF4D6D),
      Color(0xFF7867FF),
      Color(0xFF1FC8B4),
      Color(0xFFFFC24F),
    ],
    stops: [0, 0.22, 0.40, 0.62, 0.82, 1],
  );

  /// The prism rim around glass: ember › amber › lagoon › dusk.
  static List<Color> get prismRim => isDark
      ? const [
          Color(0xF2FF7A1A),
          Color(0xE6FFBE50),
          Color(0x00FFFFFF),
          Color(0x00FFFFFF),
          Color(0xF21FD7BE),
          Color(0xF28270FF),
          Color(0x00FFFFFF),
          Color(0xF2FF7A1A),
        ]
      : const [
          Color(0xF2FF9268),
          Color(0xF2FFCC68),
          Color(0x00FFFFFF),
          Color(0x00FFFFFF),
          Color(0xF250D4BE),
          Color(0xF29E88FF),
          Color(0x00FFFFFF),
          Color(0xF2FF9268),
        ];
  static const List<double> prismRimStops = [
    0,
    0.11,
    0.23,
    0.39,
    0.53,
    0.65,
    0.79,
    1
  ];

  /// Animated text accent ("one tap away.").
  static List<Color> get glowText => isDark
      ? const [
          Color(0xFFFFB23F),
          Color(0xFFFF7A1A),
          Color(0xFFFF5D8F),
          Color(0xFFA08FFF),
          Color(0xFF2FD8C3),
        ]
      : const [
          Color(0xFFC25000),
          Color(0xFFD4361F),
          Color(0xFFC2306E),
          Color(0xFF5A43E0),
          Color(0xFF077A6E),
        ];

  // ── Elevation ──
  static Color get _shade =>
      _pick(const Color(0x80000000), const Color(0x123C2878));
  static Color get _shade2 =>
      _pick(const Color(0xD1000000), const Color(0x33482E8C));

  static List<BoxShadow> get shadow1 => [
        BoxShadow(color: _shade, blurRadius: 2, offset: const Offset(0, 1)),
        BoxShadow(
            color: _shade2,
            blurRadius: 16,
            spreadRadius: -8,
            offset: const Offset(0, 6)),
      ];
  static List<BoxShadow> get shadow2 => [
        BoxShadow(color: _shade, blurRadius: 1, offset: const Offset(0, 1)),
        BoxShadow(
            color: _shade2,
            blurRadius: 22,
            spreadRadius: -12,
            offset: const Offset(0, 10)),
        BoxShadow(
            color: _shade2,
            blurRadius: 60,
            spreadRadius: -30,
            offset: const Offset(0, 30)),
      ];
  static List<BoxShadow> get shadow3 => [
        BoxShadow(color: _shade, blurRadius: 4, offset: const Offset(0, 2)),
        BoxShadow(
            color: _shade2,
            blurRadius: 40,
            spreadRadius: -18,
            offset: const Offset(0, 20)),
        BoxShadow(
            color: _shade2,
            blurRadius: 90,
            spreadRadius: -36,
            offset: const Offset(0, 48)),
      ];
  static List<BoxShadow> get shadowSheet => [
        ...shadow3,
        BoxShadow(
            color: glowDusk,
            blurRadius: 90,
            spreadRadius: -50,
            offset: const Offset(0, 40)),
      ];

  /// The neon glow under "hot" buttons.
  static List<BoxShadow> get shadowCta => const [
        BoxShadow(
            color: Color(0x59782800), blurRadius: 2, offset: Offset(0, 1)),
        BoxShadow(
            color: Color(0x9EFF6A14),
            blurRadius: 24,
            spreadRadius: -8,
            offset: Offset(0, 10)),
        BoxShadow(
            color: Color(0x80FF5028),
            blurRadius: 50,
            spreadRadius: -20,
            offset: Offset(0, 24)),
      ];
  static List<BoxShadow> get shadowLagoon => [
        BoxShadow(
            color: glowLagoon,
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 10)),
      ];
  static List<BoxShadow> get shadowSos => [
        BoxShadow(
            color: glowDanger,
            blurRadius: 20,
            spreadRadius: -6,
            offset: const Offset(0, 8)),
      ];

  // ── Motion ──
  static const Duration press = Duration(milliseconds: 140);
  static const Duration quick = Duration(milliseconds: 300);
  static const Duration enter = Duration(milliseconds: 500);
  static const Duration sheet = Duration(milliseconds: 600);
  static const Curve easeOut = Cubic(0.22, 1, 0.36, 1);
  static const Curve easeInOut = Cubic(0.65, 0, 0.35, 1);
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1);
  static const Curve snap = Cubic(0.3, 1.25, 0.4, 1);

  // ── Legacy role names ──
  static Color get bg => background;
  static Color get bg2 => surface;
  static Color get bg3 => surface2;
  static Color get border => line;
  static Color get border2 => lineStrong;
  static Color get text => ink;
  static Color get muted => ink2;
  static Color get accent => primary;
  static Color get accent2 => primaryBright;

  /// Driver Mode shares the passenger palette.
  static Color get driverAccent => primary;
  static Color get driverAccent2 => primaryBright;
  static Color get warning => warn;
  static Color get green => lagoon;
  static Color get red => danger;
  static Color get blue => lagoon;
  static Color get purple => dusk;

  // ── Radius ──
  // 14–15 inputs, 16 rows, 20 cards, 26 glass, 30 sheets, pills 999.
  static const double radiusSm = 14.0;
  static const double radius = 16.0;
  static const double radiusButton = 999.0;
  static const double radiusLg = 20.0;
  static const double radiusCard = 20.0;
  static const double radiusGlass = 26.0;
  static const double radiusSheet = 30.0;
  static const double radiusXl = 50.0;

  // ── Spacing ──
  static const double spacing4 = 4.0;
  static const double spacing5 = 5.0;
  static const double spacing6 = 6.0;
  static const double spacing7 = 7.0;
  static const double spacing8 = 8.0;
  static const double spacing9 = 9.0;
  static const double spacing10 = 10.0;
  static const double spacing12 = 12.0;
  static const double spacing14 = 14.0;
  static const double spacing16 = 16.0;
  static const double spacing18 = 18.0;
  static const double spacing20 = 20.0;
  static const double spacing22 = 22.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double radius14 = 14.0;
  static const double radius16 = 16.0;

  /// Space a tab page leaves at the bottom for the floating tab bar.
  static const double tabBarClearance = 96.0;

  // ── Typography: Geist, Geist Mono for labels, Instrument Serif accents ──
  static const String font = 'Geist';
  static const String fontMono = 'GeistMono';
  static const String fontSerif = 'InstrumentSerif';
  static const String fontSyne = font;
  static const String fontDmSans = font;

  static const double fontSize10 = 10.0;
  static const double fontSize11 = 11.0;
  static const double fontSize12 = 12.0;
  static const double fontSize13 = 13.0;
  static const double fontSize14 = 14.0;
  static const double fontSize18 = 18.0;
  static const double fontSize20 = 20.0;
  static const double fontSize24 = 24.0;

  static const FontWeight fw300 = FontWeight.w300;
  static const FontWeight fw400 = FontWeight.w400;
  static const FontWeight fw500 = FontWeight.w500;
  static const FontWeight fw600 = FontWeight.w600;
  static const FontWeight fw700 = FontWeight.w700;
  static const FontWeight fw800 = FontWeight.w800;

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Page title 27 · 700, tight (".ttl").
  static TextStyle get display => TextStyle(
      fontSize: 27,
      height: 1.06,
      fontWeight: fw700,
      letterSpacing: -1.2,
      color: ink);

  /// Section title 21 · 700 (".h2").
  static TextStyle get title => TextStyle(
      fontSize: 21,
      height: 1.12,
      fontWeight: fw700,
      letterSpacing: -0.7,
      color: ink);

  /// Headline 16 · 700.
  static TextStyle get headline => TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: fw700,
      letterSpacing: -0.3,
      color: ink);

  /// Body 14 · 400, muted.
  static TextStyle get body =>
      TextStyle(fontSize: 14, height: 1.5, fontWeight: fw400, color: ink2);

  /// Mono uppercase label (PICKUP, EST. FARE).
  static TextStyle get overline => TextStyle(
      fontFamily: fontMono,
      fontSize: 10,
      height: 1.3,
      fontWeight: fw500,
      letterSpacing: 1.4,
      color: ink2);

  /// Mono numbers (fares, PIN, distances).
  static TextStyle get mono => TextStyle(
      fontFamily: fontMono,
      fontWeight: fw600,
      fontFeatures: tabular,
      color: ink);
}

/// Badge styles
enum BadgeStyle {
  greenStyle,
  redStyle,
  yellowStyle,
  blueStyle,
  grayStyle;

  Color get color => switch (this) {
        BadgeStyle.greenStyle => DesignTokens.lagoonText,
        BadgeStyle.redStyle => DesignTokens.sosText,
        BadgeStyle.yellowStyle => DesignTokens.primaryText,
        BadgeStyle.blueStyle => DesignTokens.lagoonText,
        BadgeStyle.grayStyle => DesignTokens.ink2,
      };

  Color get backgroundColor => switch (this) {
        BadgeStyle.greenStyle => DesignTokens.lagoonSoft,
        BadgeStyle.redStyle => DesignTokens.sosSoft,
        BadgeStyle.yellowStyle => DesignTokens.primarySoft,
        BadgeStyle.blueStyle => DesignTokens.lagoonSoft,
        BadgeStyle.grayStyle => DesignTokens.surface2,
      };
}

/// Button styles
enum AppButtonStyle {
  accent,
  ghost,
  destructive,
  success;

  Color get textColor => switch (this) {
        AppButtonStyle.accent => DesignTokens.primaryInk,
        AppButtonStyle.ghost => DesignTokens.ink,
        AppButtonStyle.destructive => DesignTokens.sosText,
        AppButtonStyle.success => DesignTokens.lagoonInk,
      };

  Color? get backgroundColor => switch (this) {
        AppButtonStyle.accent => DesignTokens.primary,
        AppButtonStyle.ghost => null,
        AppButtonStyle.destructive => null,
        AppButtonStyle.success => DesignTokens.lagoon,
      };
}
