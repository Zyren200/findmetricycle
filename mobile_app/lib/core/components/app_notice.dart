import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Inline notice/banner for success, error, and info messages.
class AppNotice extends StatelessWidget {
  final Color color;
  final String message;

  const AppNotice({required this.color, required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: DesignTokens.spacing12),
      padding: const EdgeInsets.all(DesignTokens.spacing14),
      decoration: BoxDecoration(
        color: color.withAlpha(DesignTokens.isDark ? 40 : 28),
        borderRadius: BorderRadius.circular(DesignTokens.radius),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: DesignTokens.ink,
          fontSize: 13,
          fontWeight: DesignTokens.fw700,
        ),
      ),
    );
  }
}
