import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Badge component
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
      padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing10, vertical: DesignTokens.spacing7),
      decoration: BoxDecoration(
          color: style.backgroundColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: DesignTokens.spacing6,
            height: DesignTokens.spacing6,
            decoration: BoxDecoration(
              color: style.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: DesignTokens.spacing8),
          Text(
            label,
            style: TextStyle(
              fontSize: DesignTokens.fontSize11,
              fontWeight: DesignTokens.fw500,
              color: style.color,
              fontFamily: DesignTokens.fontDmSans,
            ),
          ),
        ],
      ),
    );
  }
}
