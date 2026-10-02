import "package:flutter/material.dart";
import "../theme/design_tokens.dart";

/// Layout building blocks shared by the passenger and driver screens: a
/// sticky header bar, section labels, label/value rows, list navigation
/// items, status banners and empty states. Colours always come from
/// [DesignTokens]; only the structure is fixed here.

/// Header bar: optional back button, title, optional pill badge and a
/// trailing widget, with a hairline divider underneath.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.onBack,
    this.trailing,
    this.badge,
    this.badgeColor,
  });

  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.bg,
        border: Border(bottom: BorderSide(color: DesignTokens.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  icon:
                      Icon(Icons.arrow_back_rounded, color: DesignTokens.text),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                )
              else
                const SizedBox(width: DesignTokens.spacing16),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: DesignTokens.text,
                    fontSize: 16,
                    fontWeight: DesignTokens.fw700,
                    fontFamily: DesignTokens.fontDmSans,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                AppPill(
                    label: badge!, color: badgeColor ?? DesignTokens.accent),
              ],
              const Spacer(),
              if (trailing != null) trailing!,
              const SizedBox(width: DesignTokens.spacing8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small solid pill (e.g. a countdown or status badge in the top bar).
class AppPill extends StatelessWidget {
  const AppPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: DesignTokens.bg,
          fontSize: 11,
          fontWeight: DesignTokens.fw700,
        ),
      ),
    );
  }
}

/// Uppercase, muted label above a group of rows.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: DesignTokens.muted,
          fontSize: 11,
          fontWeight: DesignTokens.fw600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Rounded, bordered box used for summaries and grouped details.
class InfoBox extends StatelessWidget {
  const InfoBox({
    super.key,
    required this.children,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
    this.spacing = 10,
  });

  final List<Widget> children;
  final Color? color;
  final Color? borderColor;
  final EdgeInsets padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? DesignTokens.bg2,
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        border: Border.all(color: borderColor ?? DesignTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Thin divider inside an [InfoBox].
class InfoDivider extends StatelessWidget {
  const InfoDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: DesignTokens.border);
}

/// "Label ........ value" row.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final Widget? icon;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(padding: const EdgeInsets.only(top: 1), child: icon!),
          const SizedBox(width: 10),
        ],
        Text(label, style: TextStyle(color: DesignTokens.muted, fontSize: 13)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? DesignTokens.text,
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? DesignTokens.fw700 : DesignTokens.fw500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tappable list row: leading icon, label, chevron.
class NavListItem extends StatelessWidget {
  const NavListItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: DesignTokens.border)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? DesignTokens.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style:
                    TextStyle(color: color ?? DesignTokens.text, fontSize: 14),
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: DesignTokens.muted),
          ],
        ),
      ),
    );
  }
}

/// Tinted, bordered banner for a status message.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.showSpinner = false,
    this.subtitle,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool showSpinner;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        children: [
          if (showSpinner)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else if (icon != null)
            Icon(icon, color: color, size: 20),
          if (showSpinner || icon != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: DesignTokens.fw600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style:
                          TextStyle(color: color.withAlpha(210), fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered icon + message for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        children: [
          Icon(icon, size: 40, color: DesignTokens.muted),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: DesignTokens.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Error message with an optional retry action.
class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.red.withAlpha(24),
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        border: Border.all(color: DesignTokens.red.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: DesignTokens.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: DesignTokens.red, fontSize: 13)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text("Retry", style: TextStyle(color: DesignTokens.red)),
            ),
        ],
      ),
    );
  }
}

/// Full-width primary action button (big, rounded) used at the bottom of
/// flow steps.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.color,
    this.foregroundColor,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? color;
  final Color? foregroundColor;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? DesignTokens.accent;
    final fg = foregroundColor ?? (outlined ? bg : DesignTokens.bg);
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: DesignTokens.fw700,
                  ),
                ),
              ),
            ],
          );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radius),
    );
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: outlined
          ? OutlinedButton(
              onPressed: loading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                shape: shape,
                side: BorderSide(
                    color: bg.withAlpha(onPressed == null ? 80 : 255)),
              ),
              child: child,
            )
          : ElevatedButton(
              onPressed: loading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: bg,
                disabledBackgroundColor: bg.withAlpha(90),
                foregroundColor: fg,
                elevation: 0,
                shape: shape,
              ),
              child: child,
            ),
    );
  }
}
