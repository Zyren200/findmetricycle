import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'sunrise.dart';

/// Stat card: label above a big number.
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
        color: DesignTokens.surface,
        border: Border.all(color: DesignTokens.line),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        boxShadow: DesignTokens.shadow1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSize12,
                    fontWeight: DesignTokens.fw700,
                    color: DesignTokens.ink2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: DesignTokens.fw800,
                    color: accentColor ?? DesignTokens.ink,
                    fontFeatures: DesignTokens.tabular,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
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
      color: DesignTokens.line,
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
    return SunCard(
      onTap: onTap,
      color: backgroundColor,
      radius: DesignTokens.radiusCard,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: child,
    );
  }
}
