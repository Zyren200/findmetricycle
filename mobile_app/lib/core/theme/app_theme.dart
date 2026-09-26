import "package:flutter/material.dart";
import "design_tokens.dart";

class AppTheme {
  /// A light counterpart to [build]. Note: most screens in this app render
  /// with DesignTokens' fixed dark palette directly (not via Theme.of),
  /// so switching to light mode currently affects default Material
  /// widgets (dialogs, switches, snackbars) rather than every screen.
  static ThemeData buildLight() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DesignTokens.accent,
        primary: DesignTokens.accent,
        secondary: DesignTokens.accent2,
        brightness: Brightness.light,
      ),
    );
    return base.copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: DesignTokens.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
        ),
      ),
    );
  }

  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DesignTokens.accent,
        primary: DesignTokens.accent,
        secondary: DesignTokens.accent2,
        surface: DesignTokens.bg2,
        error: DesignTokens.red,
        brightness: Brightness.dark,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: DesignTokens.bg,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: DesignTokens.bg,
        foregroundColor: DesignTokens.text,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: DesignTokens.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          side: const BorderSide(
            color: DesignTokens.border,
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: DesignTokens.accent,
          foregroundColor: DesignTokens.bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.bg3,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing14,
          vertical: DesignTokens.spacing12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius),
          borderSide: const BorderSide(color: DesignTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius),
          borderSide: const BorderSide(color: DesignTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius),
          borderSide: const BorderSide(color: DesignTokens.accent, width: 2),
        ),
        hintStyle: const TextStyle(
          color: DesignTokens.muted,
          fontSize: DesignTokens.fontSize14,
          fontFamily: DesignTokens.fontDmSans,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontFamily: DesignTokens.fontSyne,
          fontSize: DesignTokens.fontSize24,
          fontWeight: DesignTokens.fw700,
          color: DesignTokens.text,
        ),
        titleMedium: TextStyle(
          fontFamily: DesignTokens.fontSyne,
          fontSize: DesignTokens.fontSize14,
          fontWeight: DesignTokens.fw600,
          color: DesignTokens.text,
        ),
        bodyMedium: TextStyle(
          fontFamily: DesignTokens.fontDmSans,
          fontSize: DesignTokens.fontSize14,
          fontWeight: DesignTokens.fw400,
          color: DesignTokens.text,
        ),
        bodySmall: TextStyle(
          fontFamily: DesignTokens.fontDmSans,
          fontSize: DesignTokens.fontSize12,
          fontWeight: DesignTokens.fw400,
          color: DesignTokens.muted,
        ),
      ),
    );
  }
}
