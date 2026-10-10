import "package:flutter/material.dart";
import "../theme/design_tokens.dart";
import "sunrise.dart";

/// Layout building blocks shared by the passenger and driver screens: a
/// header bar, section labels, label/value rows, list navigation items,
/// status banners and empty states, in the Sunrise style. Colours always
/// come from [DesignTokens]; only the structure is fixed here.

/// Header: a rounded back button, the title, an optional pill badge and a
/// trailing widget.
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
    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                if (showBack) ...[
                  BackSquareButton(
                      onTap: onBack ?? () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 14),
                ] else
                  const SizedBox(width: 4),
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTokens.title,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  AppPill(
                      label: badge!, color: badgeColor ?? DesignTokens.primary),
                ],
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 42 px round back button with a hairline border.
class BackSquareButton extends StatelessWidget {
  const BackSquareButton({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: "Back",
      // ".ibtn": a 42 px round button with a hairline and a top highlight.
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: DesignTokens.surface2,
          shape: BoxShape.circle,
          border: Border.all(color: DesignTokens.line),
        ),
        child:
            Icon(Icons.chevron_left_rounded, size: 24, color: DesignTokens.ink),
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
    final fg = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A0D04);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: DesignTokens.fw800,
          fontFeatures: DesignTokens.tabular,
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
      padding: padding ?? const EdgeInsets.only(bottom: 10),
      child: Overline(text),
    );
  }
}

/// Rounded card for summaries and grouped details.
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
        color: color ?? DesignTokens.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(color: borderColor ?? DesignTokens.line),
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
      Container(height: 1, color: DesignTokens.line);
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
        Text(label,
            style: TextStyle(
                color: DesignTokens.ink2,
                fontSize: 13,
                fontWeight: DesignTokens.fw600)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? DesignTokens.ink,
              fontSize: bold ? 15 : 14,
              fontWeight: bold ? DesignTokens.fw800 : DesignTokens.fw700,
              fontFeatures: DesignTokens.tabular,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tappable list row: leading icon tile, label, chevron.
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: DesignTokens.line)),
        ),
        child: Row(
          children: [
            IconTile(
              icon: icon,
              size: 36,
              radius: 11,
              iconSize: 18,
              background:
                  color == null ? DesignTokens.surface2 : color!.withAlpha(30),
              foreground: color ?? DesignTokens.ink,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    color: color ?? DesignTokens.ink,
                    fontSize: 15,
                    fontWeight: DesignTokens.fw700),
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: DesignTokens.ink2),
          ],
        ),
      ),
    );
  }
}

/// Tinted banner for a status message.
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
    return PrismAlert(
      tone: color,
      title: label,
      message: subtitle,
      spinner: showSpinner,
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
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          IconTile(
            icon: icon,
            size: 56,
            radius: 18,
            iconSize: 26,
            background: DesignTokens.surface2,
            foreground: DesignTokens.ink2,
          ),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: DesignTokens.ink2,
                  fontSize: 14,
                  fontWeight: DesignTokens.fw600)),
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
    return Shake(
      key: ValueKey(message),
      child: PrismAlert(
        tone: DesignTokens.danger,
        message: message,
        trailing: onRetry == null
            ? null
            : SunLink(
                label: "Retry", color: DesignTokens.danger, onTap: onRetry),
      ),
    );
  }
}

/// Full-width primary action button (56 px, rounded, orange glow) used at
/// the bottom of flow steps.
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
    if (color == null && foregroundColor == null) {
      return SunButton(
        label: label,
        onPressed: onPressed,
        loading: loading,
        icon: icon,
        tone: outlined ? SunTone.outline : SunTone.primary,
      );
    }
    final bg = color ?? DesignTokens.primary;
    final fg = foregroundColor ??
        (outlined
            ? bg
            : ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
                ? Colors.white
                : const Color(0xFF1A0D04));
    final enabled = onPressed != null && !loading;
    return Pressable(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: DesignTokens.quick,
        opacity: onPressed == null && !loading ? 0.4 : 1,
        child: Container(
          width: double.infinity,
          height: 56,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : bg,
            borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
            border: outlined ? Border.all(color: bg, width: 1.5) : null,
            boxShadow: outlined || !enabled
                ? null
                : [
                    BoxShadow(
                        color: bg.withAlpha(80),
                        blurRadius: 24,
                        offset: const Offset(0, 10)),
                  ],
          ),
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.6, color: fg),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: fg),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: fg,
                          fontSize: 17,
                          fontWeight: DesignTokens.fw800,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
