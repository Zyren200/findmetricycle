import "package:flutter/material.dart";
import "../components/prism.dart";
import "design_tokens.dart";

class AppTheme {
  /// The app theme for the palette currently selected in
  /// [DesignTokens.isDark] — screens read DesignTokens directly, and the
  /// Material widgets (dialogs, switches, snackbars, inputs) follow this.
  static ThemeData build() {
    final dark = DesignTokens.isDark;
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: DesignTokens.font,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DesignTokens.primary,
        primary: DesignTokens.primary,
        onPrimary: DesignTokens.primaryInk,
        secondary: DesignTokens.lagoon,
        onSecondary: DesignTokens.lagoonInk,
        surface: DesignTokens.solid,
        onSurface: DesignTokens.ink,
        error: DesignTokens.danger,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
    );

    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      // Pages are transparent: every route paints the aurora backdrop
      // under its page (see PrismPageTransitionsBuilder).
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: DesignTokens.solid,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PrismPageTransitionsBuilder(),
        TargetPlatform.iOS: PrismPageTransitionsBuilder(),
        TargetPlatform.windows: PrismPageTransitionsBuilder(),
        TargetPlatform.macOS: PrismPageTransitionsBuilder(),
        TargetPlatform.linux: PrismPageTransitionsBuilder(),
        TargetPlatform.fuchsia: PrismPageTransitionsBuilder(),
      }),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: DesignTokens.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: DesignTokens.title,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: DesignTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          side: BorderSide(color: DesignTokens.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: DesignTokens.solid,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSheet),
        ),
        titleTextStyle: DesignTokens.title,
        contentTextStyle: DesignTokens.body,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: DesignTokens.solid,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: DesignTokens.solid,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(DesignTokens.radiusSheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: DesignTokens.solid,
        contentTextStyle: TextStyle(
          color: DesignTokens.ink1,
          fontFamily: DesignTokens.font,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: DesignTokens.lagoonText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: DesignTokens.lineStrong),
        ),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: DesignTokens.ember,
          foregroundColor: DesignTokens.primaryInk,
          elevation: 0,
          textStyle: const TextStyle(
              fontFamily: DesignTokens.font,
              fontSize: 16,
              fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: DesignTokens.ink,
          side: BorderSide(color: DesignTokens.lineStrong),
          textStyle: const TextStyle(
              fontFamily: DesignTokens.font,
              fontSize: 14,
              fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DesignTokens.primaryText,
          textStyle: const TextStyle(
              fontFamily: DesignTokens.font,
              fontSize: 14,
              fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? DesignTokens.lagoon
                : DesignTokens.lineStrong),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: DesignTokens.surface,
        selectedColor: DesignTokens.pillBg,
        side: BorderSide(color: DesignTokens.line),
        labelStyle: TextStyle(
          fontFamily: DesignTokens.font,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: DesignTokens.ink2,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: DesignTokens.font,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: DesignTokens.ink,
        ),
        showCheckmark: false,
        shape: const StadiumBorder(),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: DesignTokens.lagoon,
      ),
      dividerTheme: DividerThemeData(color: DesignTokens.line, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.inputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing14,
          vertical: 16,
        ),
        border: field(DesignTokens.lineStrong),
        enabledBorder: field(DesignTokens.lineStrong),
        focusedBorder: field(DesignTokens.lagoon),
        errorBorder: field(DesignTokens.danger),
        focusedErrorBorder: field(DesignTokens.danger),
        hintStyle: TextStyle(
          color: DesignTokens.ink2,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontFamily: DesignTokens.font,
        ),
        labelStyle: TextStyle(
          color: DesignTokens.ink2,
          fontFamily: DesignTokens.font,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: base.textTheme
          .apply(
            fontFamily: DesignTokens.font,
            bodyColor: DesignTokens.ink,
            displayColor: DesignTokens.ink,
          )
          .copyWith(
            headlineSmall: DesignTokens.title,
            titleMedium: DesignTokens.headline,
            bodyMedium: TextStyle(
              fontFamily: DesignTokens.font,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: DesignTokens.ink,
            ),
            bodySmall: TextStyle(
              fontFamily: DesignTokens.font,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: DesignTokens.ink2,
            ),
          ),
    );
  }
}
