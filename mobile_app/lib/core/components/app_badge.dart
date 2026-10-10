import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Rounded status badge.
class AppBadge extends StatelessWidget {
  final String label;
  final BadgeStyle style;

  const AppBadge({
    required this.label,
    this.style = BadgeStyle.grayStyle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: style.backgroundColor,
          borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(
          fontSize: DesignTokens.fontSize12,
          fontWeight: DesignTokens.fw800,
          color: style.color,
        ),
      ),
    );
  }
}
