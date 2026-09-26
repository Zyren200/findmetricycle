import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Custom button component
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
    this.height = 52,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isGhost = style == AppButtonStyle.ghost;
    final backgroundColor = style.backgroundColor ?? (isGhost ? Colors.transparent : DesignTokens.bg3);
    final textColor = style.textColor;
    final borderSide = isGhost
      ? const BorderSide(color: DesignTokens.border2, width: 1)
      : (style == AppButtonStyle.accent ? BorderSide.none : const BorderSide(color: DesignTokens.border, width: 1));

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(DesignTokens.radius),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: borderSide.color,
                width: borderSide.width,
              ),
              borderRadius: BorderRadius.circular(DesignTokens.radius),
              boxShadow: style == AppButtonStyle.accent
                  ? const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.12),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: DesignTokens.fontSize14,
                        fontWeight: DesignTokens.fw600,
                        color: textColor,
                        fontFamily: DesignTokens.fontSyne,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
