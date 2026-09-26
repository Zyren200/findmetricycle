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
      padding: const EdgeInsets.all(DesignTokens.spacing12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: color,
          fontFamily: DesignTokens.fontDmSans,
          fontWeight: DesignTokens.fw600,
        ),
      ),
    );
  }
}
