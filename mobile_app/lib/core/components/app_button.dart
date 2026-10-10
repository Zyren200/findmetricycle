import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'sunrise.dart';

/// Button in one of the [AppButtonStyle]s, drawn as a Sunrise button.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final bool isLoading;
  final double? width;
  final double? height;

  const AppButton({
    required this.label,
    this.onPressed,
    this.style = AppButtonStyle.accent,
    this.isLoading = false,
    this.width,
    this.height = 56,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tone = switch (style) {
      AppButtonStyle.accent => SunTone.primary,
      AppButtonStyle.ghost => SunTone.outline,
      AppButtonStyle.destructive => SunTone.outline,
      AppButtonStyle.success => SunTone.lagoon,
    };
    return SizedBox(
      width: width ?? double.infinity,
      child: SunButton(
        label: label,
        onPressed: onPressed,
        loading: isLoading,
        tone: tone,
        height: height ?? 56,
        foreground:
            style == AppButtonStyle.destructive ? DesignTokens.sosText : null,
      ),
    );
  }
}
