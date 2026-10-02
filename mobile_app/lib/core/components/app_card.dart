import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Stat card component
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? accentColor;
  final Widget? trailing;

  const StatCard({
    required this.label,
    required this.value,
    this.accentColor,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: DesignTokens.bg2,
        border: Border.all(color: DesignTokens.border, width: 1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent bar
          Container(
            height: 4,
            width: 48,
            decoration: BoxDecoration(
              color: accentColor ?? DesignTokens.accent,
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
          const SizedBox(height: DesignTokens.spacing14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: DesignTokens.fontSize12,
                        fontWeight: DesignTokens.fw500,
                        color: DesignTokens.muted,
                        fontFamily: DesignTokens.fontDmSans,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: DesignTokens.fontSize18,
                        fontWeight: DesignTokens.fw700,
                        color: DesignTokens.text,
                        fontFamily: DesignTokens.fontSyne,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    );
  }
}

/// Divider component
class AppDivider extends StatelessWidget {
  final double height;
  const AppDivider({this.height = 1, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: DesignTokens.border,
      margin: const EdgeInsets.symmetric(vertical: DesignTokens.spacing12),
    );
  }
}

/// Generic card wrapper
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const AppCard({
    required this.child,
    this.padding,
    this.backgroundColor,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(DesignTokens.spacing14),
        decoration: BoxDecoration(
          color: backgroundColor ?? DesignTokens.bg2,
          border: Border.all(color: DesignTokens.border, width: 1),
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.12),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
