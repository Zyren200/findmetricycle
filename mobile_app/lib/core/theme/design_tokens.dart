import 'package:flutter/material.dart';

/// Design tokens extracted from FindMeTricycle mobile design
class DesignTokens {
  // ── Colors ──
  static const Color bg = Color(0xFF0E0F14);
  static const Color bg2 = Color(0xFF161820);
  static const Color bg3 = Color(0xFF1D1F2A);

  static const Color border =
      Color.fromARGB(20, 255, 255, 255); // rgba(255,255,255,0.08)
  static const Color border2 =
      Color.fromARGB(36, 255, 255, 255); // rgba(255,255,255,0.14)

  static const Color text = Color(0xFFF0F0F4);
  static const Color muted = Color(0xFF8B8D99);

  // Brand: FindMeTricycle teal, matched to the driver-apply website and
  // admin dashboard's palette so every surface reads as one brand.
  static const Color accent = Color(0xFF39EFD0); // Passenger teal/mint
  static const Color accent2 = Color(0xFF86F9E6); // Lighter teal, for gradients

  // Driver Mode gets its own headlight-amber identity (matching the
  // FindMeTricycle app redesign prototype) so drivers always know at a
  // glance which mode is active, distinct from the passenger teal.
  static const Color driverAccent = Color(0xFFFFB84D);
  static const Color driverAccent2 = Color(0xFFFFD28A);

  // Kept separate from [accent] so "pending / needs attention" states
  // don't visually collide with the teal brand color.
  static const Color warning = Color(0xFFF9B84C);

  static const Color green = Color(0xFF3ECF78);
  static const Color red = Color(0xFFF05C5C);
  static const Color blue = Color(0xFF4FA3E8);
  static const Color purple = Color(0xFFA78BFA);

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
  greenStyle('green', DesignTokens.green),
  redStyle('red', DesignTokens.red),
  yellowStyle('yellow', DesignTokens.warning),
  blueStyle('blue', DesignTokens.blue),
  grayStyle('gray', Color.fromARGB(15, 255, 255, 255));

  final String name;
  final Color color;
  const BadgeStyle(this.name, this.color);

  Color get backgroundColor => color.withAlpha(31);
}

/// Button styles
enum AppButtonStyle {
  accent('accent', DesignTokens.accent, DesignTokens.bg),
  ghost('ghost', DesignTokens.text, null),
  destructive('destructive', DesignTokens.red, null),
  success('success', DesignTokens.green, null);

  final String name;
  final Color textColor;
  final Color? backgroundColor;
  const AppButtonStyle(this.name, this.textColor, this.backgroundColor);
}

// End of design tokens
