import 'package:flutter/material.dart';

/// Design tokens extracted from FindMeTricycle mobile design
class DesignTokens {
  // ── Colors ──
  // Every colour has a dark and a light value; [isDark] picks the palette.
  // The app sets it from the Dark Mode preference (see main.dart) and
  // rebuilds every screen when it changes.
  static bool isDark = true;

  static Color _pick(Color dark, Color light) => isDark ? dark : light;

  static Color get bg =>
      _pick(const Color(0xFF0E0F14), const Color(0xFFF4F6FA));
  static Color get bg2 =>
      _pick(const Color(0xFF161820), const Color(0xFFFFFFFF));
  static Color get bg3 =>
      _pick(const Color(0xFF1D1F2A), const Color(0xFFECEFF5));

  static Color get border => _pick(
      const Color.fromARGB(20, 255, 255, 255), // rgba(255,255,255,0.08)
      const Color.fromARGB(26, 15, 23, 42));
  static Color get border2 => _pick(
      const Color.fromARGB(36, 255, 255, 255), // rgba(255,255,255,0.14)
      const Color.fromARGB(46, 15, 23, 42));

  static Color get text =>
      _pick(const Color(0xFFF0F0F4), const Color(0xFF111827));
  static Color get muted =>
      _pick(const Color(0xFF8B8D99), const Color(0xFF5F6675));

  // Brand: FindMeTricycle teal, matched to the driver-apply website and
  // admin dashboard's palette so every surface reads as one brand. The
  // light palette uses deeper shades so text and fills stay readable on
  // white.
  static Color get accent =>
      _pick(const Color(0xFF39EFD0), const Color(0xFF0B8F7A));
  static Color get accent2 =>
      _pick(const Color(0xFF86F9E6), const Color(0xFF14B89D));

  // Driver Mode gets its own headlight-amber identity so drivers always
  // know at a glance which mode is active, distinct from the passenger teal.
  static Color get driverAccent =>
      _pick(const Color(0xFFFFB84D), const Color(0xFFC27400));
  static Color get driverAccent2 =>
      _pick(const Color(0xFFFFD28A), const Color(0xFFE39A2A));

  // Kept separate from [accent] so "pending / needs attention" states
  // don't visually collide with the teal brand color.
  static Color get warning =>
      _pick(const Color(0xFFF9B84C), const Color(0xFFB7791F));

  static Color get green =>
      _pick(const Color(0xFF3ECF78), const Color(0xFF1E9E55));
  static Color get red =>
      _pick(const Color(0xFFF05C5C), const Color(0xFFD23B3B));
  static Color get blue =>
      _pick(const Color(0xFF4FA3E8), const Color(0xFF2474C4));
  static Color get purple =>
      _pick(const Color(0xFFA78BFA), const Color(0xFF7C5CE0));

  // ── Radius ──
  // Rounder than before, matching the FindMeTricycle app redesign's
  // softer pill-and-card language.
  static const double radius = 14.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 50.0; // Phone notch
  static const double radiusSm = 8.0;

  // ── Spacing ──
  static const double spacing4 = 4.0;
  static const double spacing5 = 5.0;
  static const double spacing7 = 7.0;
  static const double spacing9 = 9.0;
  static const double spacing12 = 12.0;
  static const double spacing14 = 14.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing18 = 18.0;
  static const double spacing22 = 22.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing10 = 10.0;
  static const double radius14 = 14.0;
  static const double radius16 = 16.0;

  // ── Typography ──
  // Same pairing as the admin dashboard and driver-apply website: a display
  // face for headings, a clean grotesk for body/dense text.
  static const String fontSyne = 'Unbounded';
  static const String fontDmSans = 'Onest';

  // Font sizes
  static const double fontSize10 = 10.0;
  static const double fontSize11 = 11.0;
  static const double fontSize12 = 12.0;
  static const double fontSize13 = 13.0;
  static const double fontSize14 = 14.0;
  static const double fontSize18 = 18.0;
  static const double fontSize24 = 24.0;
  static const double fontSize20 = 20.0;

  // ── Font weights ──
  static const FontWeight fw300 = FontWeight.w300;
  static const FontWeight fw400 = FontWeight.w400;
  static const FontWeight fw500 = FontWeight.w500;
  static const FontWeight fw600 = FontWeight.w600;
  static const FontWeight fw700 = FontWeight.w700;
}

/// Badge styles
enum BadgeStyle {
  greenStyle,
  redStyle,
  yellowStyle,
  blueStyle,
  grayStyle;

  Color get color => switch (this) {
        BadgeStyle.greenStyle => DesignTokens.green,
        BadgeStyle.redStyle => DesignTokens.red,
        BadgeStyle.yellowStyle => DesignTokens.warning,
        BadgeStyle.blueStyle => DesignTokens.blue,
        BadgeStyle.grayStyle => DesignTokens.muted,
      };

  Color get backgroundColor => color.withAlpha(31);
}

/// Button styles
enum AppButtonStyle {
  accent,
  ghost,
  destructive,
  success;

  Color get textColor => switch (this) {
        AppButtonStyle.accent => DesignTokens.accent,
        AppButtonStyle.ghost => DesignTokens.text,
        AppButtonStyle.destructive => DesignTokens.red,
        AppButtonStyle.success => DesignTokens.green,
      };

  Color? get backgroundColor =>
      this == AppButtonStyle.accent ? DesignTokens.bg : null;
}

// End of design tokens
