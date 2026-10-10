import "dart:async";
import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../theme/design_tokens.dart";
import "prism.dart";

// Sunrise building blocks shared by every screen: press feedback, glass
// over the map, buttons, bottom sheets, the floating tab bar, chips,
// avatars and the entrance animations. Colours always come from
// [DesignTokens].

/// Whether the phone asked for less motion.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

// ── Press feedback ──────────────────────────────────────────────────────

/// Scales its child to 96% while pressed (140 ms, ease-out).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.button = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final bool button;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: widget.button,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: DesignTokens.press,
          curve: DesignTokens.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Glass ───────────────────────────────────────────────────────────────

/// Prism glass for chips, the tab bar and status pills that float over the
/// map (see [PrismGlass]); [strong] for sheets and dialogs.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding,
    this.radius = 999,
    this.width,
    this.height,
    this.circle = false,
    this.strong = false,
    this.spin = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double? width;
  final double? height;
  final bool circle;
  final bool strong;
  final bool spin;

  @override
  Widget build(BuildContext context) {
    return PrismGlass(
      padding: padding,
      radius: radius,
      width: width,
      height: height,
      circle: circle,
      strong: strong,
      spin: spin,
      child: child,
    );
  }
}

/// Round 44 px glass button (back, bell, locate).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.dot = false,
    this.square = false,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String label;
  final bool dot;
  final bool square;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: Glass(
          width: size,
          height: size,
          circle: !square,
          radius: 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: DesignTokens.ink),
              if (dot)
                Positioned(
                  top: size * .22,
                  right: size * .24,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: DesignTokens.ember,
                      shape: BoxShape.circle,
                      border: Border.all(color: DesignTokens.bgDeep, width: 2),
                      boxShadow: [
                        BoxShadow(color: DesignTokens.glowEmber, blurRadius: 8),
                      ],
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

// ── Buttons ─────────────────────────────────────────────────────────────

enum SunTone {
  primary,
  lagoon,
  sos,
  outline,
  soft,
  lagoonSoft,
  ink,
  quiet,
  ghost,

  /// Red text on a faint red tint ("Cancel ride").
  danger,
}

/// The Prism button: a pill with the "hot" ember gradient and neon glow for
/// primary actions, plus the lagoon / SOS / glass / ghost / danger variants.
class SunButton extends StatelessWidget {
  const SunButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = SunTone.primary,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.height = 52,
    this.fontSize,
    this.radius,
    this.expand = true,
    this.foreground,
  });

  final String label;
  final VoidCallback? onPressed;
  final SunTone tone;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final double height;
  final double? fontSize;
  final double? radius;
  final bool expand;

  /// Overrides the label colour (e.g. the red "Log out").
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final (
      Color? bg,
      Gradient? fill,
      Color fg,
      List<BoxShadow>? glow,
      Color? side
    ) = switch (tone) {
      SunTone.primary => (
          null,
          DesignTokens.hot,
          DesignTokens.primaryInk,
          DesignTokens.shadowCta,
          null
        ),
      SunTone.lagoon => (
          null,
          DesignTokens.lagoonFill,
          DesignTokens.onOk,
          DesignTokens.shadowLagoon,
          null
        ),
      SunTone.sos => (
          null,
          DesignTokens.dangerFill,
          Colors.white,
          DesignTokens.shadowSos,
          null
        ),
      SunTone.danger => (
          DesignTokens.sosSoft,
          null,
          DesignTokens.danger,
          null,
          DesignTokens.danger.withValues(alpha: .42)
        ),
      SunTone.outline || SunTone.quiet => (
          DesignTokens.surface2,
          null,
          DesignTokens.ink,
          DesignTokens.shadow1,
          DesignTokens.lineStrong
        ),
      SunTone.soft => (
          DesignTokens.primarySoft,
          null,
          DesignTokens.primaryText,
          null,
          null
        ),
      SunTone.lagoonSoft => (
          DesignTokens.lagoonSoft,
          null,
          DesignTokens.lagoonText,
          null,
          null
        ),
      SunTone.ink => (
          DesignTokens.ink,
          null,
          DesignTokens.background,
          null,
          null
        ),
      SunTone.ghost => (Colors.transparent, null, DesignTokens.ink2, null, null),
    };
    final color = foreground ?? fg;
    final enabled = onPressed != null && !loading;
    final r = radius ?? height / 2;
    final size = fontSize ?? (height >= 46 ? 15.0 : 13.5);
    final hot = tone == SunTone.primary;

    final content = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: size,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.08,
                    shadows: hot
                        ? const [
                            Shadow(color: Color(0x40FFFFFF), offset: Offset(0, 1))
                          ]
                        : null,
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 9),
                Icon(trailingIcon, size: 18, color: color),
              ],
            ],
          );

    Widget body = Container(
      width: expand ? double.infinity : null,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: expand ? 14 : 22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        gradient: fill,
        borderRadius: BorderRadius.circular(r),
        border: side == null ? null : Border.all(color: side),
      ),
      // The top-edge highlight of a raised button.
      foregroundDecoration: fill != null
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x40FFFFFF), Color(0x00FFFFFF), Color(0x14000000)],
                stops: [0, .45, 1],
              ),
            )
          : null,
      child: content,
    );
    if (hot && enabled) body = _Shine(radius: r, child: body);
    body = OuterShadow(shadows: enabled ? glow : null, radius: r, child: body);

    return Pressable(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        opacity: onPressed == null && !loading ? 0.45 : 1,
        duration: DesignTokens.quick,
        child: body,
      ),
    );
  }
}

/// The light sweep that crosses a "hot" button every few seconds.
class _Shine extends StatefulWidget {
  const _Shine({required this.child, required this.radius});

  final Widget child;
  final double radius;

  @override
  State<_Shine> createState() => _ShineState();
}

class _ShineState extends State<_Shine> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ambientMotion(context) && _c == null) {
      _c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 4500))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.radius),
              child: AnimatedBuilder(
                animation: c,
                builder: (_, __) {
                  // 6%–22% of the cycle: a skewed band crosses left to right.
                  final v = c.value;
                  if (v < .06 || v > .22) return const SizedBox.shrink();
                  final k = (v - .06) / .16;
                  final opacity = k < .25 ? k / .25 : 1 - (k - .25) / .75;
                  return LayoutBuilder(builder: (_, box) {
                    final w = box.maxWidth * .38;
                    final x = -box.maxWidth * .45 + k * box.maxWidth * 1.6;
                    return Transform(
                      transform: Matrix4.translationValues(x, 0, 0)
                        ..multiply(Matrix4.skewX(-0.32)),
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Container(
                          width: w,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Color(0x00FFFFFF),
                              Color(0x99FFFFFF),
                              Color(0x00FFFFFF),
                            ]),
                          ),
                        ),
                      ),
                    );
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Text-only action ("Mark all read", "Forgot password?").
class SunLink extends StatelessWidget {
  const SunLink(
      {super.key, required this.label, required this.onTap, this.color});

  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = onTap == null ? DesignTokens.ink2 : (color ?? DesignTokens.lagoonText);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: c,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: c.withValues(alpha: .45),
            decorationThickness: 1.2,
          ),
        ),
      ),
    );
  }
}

// ── Surfaces ────────────────────────────────────────────────────────────

/// Strong-glass sheet floating over the bottom of the map (8 px from the
/// edges, 30 px corners, travelling prism rim), above the tab bar when
/// [overTabs]. [bottomPadding] is the space inside, under the content.
class MapSheet extends StatelessWidget {
  const MapSheet({
    super.key,
    required this.children,
    this.overTabs = false,
    this.gap = 14,
    this.label,
    this.bottomPadding,
  });

  final List<Widget> children;
  final bool overTabs;
  final double gap;
  final String? label;
  final double? bottomPadding;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return Semantics(
      container: true,
      label: label,
      child: SlideUp(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            8,
            0,
            8,
            (overTabs ? DesignTokens.tabBarClearance - 12 : 8) + inset,
          ),
          child: PrismGlass(
            strong: true,
            spin: true,
            radius: DesignTokens.radiusSheet,
            shadows: DesignTokens.shadowSheet,
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding ?? 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: DesignTokens.lineStrong,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                SizedBox(height: gap - 4),
                ...Stagger.wrap(children, gap: gap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tinted card with a hairline edge (".trip", ".note" in the design).
class SunCard extends StatelessWidget {
  const SunCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = DesignTokens.radiusCard,
    this.color,
    this.onTap,
    this.border = true,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  final bool border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? DesignTokens.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: DesignTokens.line) : null,
      ),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, child: card);
  }
}

/// Tinted box (surface-2 by default) for grouped details.
class SoftBox extends StatelessWidget {
  const SoftBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 16,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? DesignTokens.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: DesignTokens.line),
      ),
      child: child,
    );
  }
}

/// List group: rows separated by hairlines inside one card.
class SunListCard extends StatelessWidget {
  const SunListCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: DesignTokens.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: DesignTokens.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row of a [SunListCard]: icon tile, label, trailing / chevron.
class SunListRow extends StatelessWidget {
  const SunListRow({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.subtitle,
    this.trailing,
    this.iconBg,
    this.iconFg,
    this.labelColor,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconBg;
  final Color? iconFg;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg ?? DesignTokens.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: DesignTokens.line),
                ),
                child: Icon(icon,
                    size: 17, color: iconFg ?? DesignTokens.ink1),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: labelColor ?? DesignTokens.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: TextStyle(
                            color: DesignTokens.ink2,
                            fontSize: 12,
                            fontWeight: FontWeight.w400)),
                  ],
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? Icon(Icons.chevron_right_rounded,
                        size: 18, color: DesignTokens.ink2)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// Rounded-square tile holding an icon.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 42,
    this.radius = 13,
    this.iconSize = 20,
    this.shadow,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double radius;
  final double iconSize;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}

// ── Text ────────────────────────────────────────────────────────────────

/// Big page title (28/34 · 800) with an optional subtitle and trailing
/// action, as on Rides, Alerts and Profile.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                  header: true,
                  child: Text(title, style: DesignTokens.display)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!,
                    style: TextStyle(
                        color: DesignTokens.ink2,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// "PICKUP", "EST. FARE" — 11 px uppercase label.
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style:
            DesignTokens.overline.copyWith(color: color ?? DesignTokens.ink2),
      );
}

// ── Chips, avatars, dots ────────────────────────────────────────────────

enum ChipTone { ok, cancel, primary, sos, neutral }

/// Rounded status chip (Completed, Cancelled, Est. ₱25, SOS active).
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = ChipTone.neutral});

  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    // ".badge": mono caps, a glowing dot, the tone as a faint fill and ring.
    final tint = switch (tone) {
      ChipTone.ok => DesignTokens.ok,
      ChipTone.cancel => DesignTokens.danger,
      ChipTone.primary => DesignTokens.warn,
      ChipTone.sos => DesignTokens.danger,
      ChipTone.neutral => DesignTokens.ink2,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: tint,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: tint, blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 6),
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontFamily: DesignTokens.fontMono,
                  color: tint,
                  fontSize: 10,
                  height: 1.3,
                  letterSpacing: .8,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

enum AvatarTone { primary, lagoon, sand, solid }

String initialsOf(String? name, {String fallback = "?"}) {
  final parts = (name ?? "")
      .split(RegExp(r"\s+"))
      .where((p) => p.isNotEmpty && RegExp(r"[A-Za-z0-9]").hasMatch(p[0]))
      .toList();
  if (parts.isEmpty) return fallback;
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// A stable tone per person, so the same rider always looks the same.
AvatarTone toneFor(Object? key) {
  const tones = [AvatarTone.primary, AvatarTone.lagoon, AvatarTone.sand];
  final hash = key.toString().codeUnits.fold<int>(0, (a, b) => a + b);
  return tones[hash % tones.length];
}

/// Initials in a rounded square (or circle), toned like the design.
class ToneAvatar extends StatelessWidget {
  const ToneAvatar({
    super.key,
    required this.name,
    this.tone = AvatarTone.primary,
    this.size = 46,
    this.radius,
    this.imageUrl,
    this.circle = false,
  });

  final String? name;
  final AvatarTone tone;
  final double size;
  final double? radius;
  final String? imageUrl;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    // ".av": a glossy gradient disc (ember, lagoon or dusk) with white
    // initials and a soft glow of the same colour.
    final (fill, glow) = switch (tone) {
      AvatarTone.primary || AvatarTone.solid => (
          DesignTokens.emberFill,
          DesignTokens.glowEmber
        ),
      AvatarTone.lagoon => (DesignTokens.lagoonFill, DesignTokens.glowLagoon),
      AvatarTone.sand => (DesignTokens.duskFill, DesignTokens.glowDusk),
    };
    final r = radius ?? size / 2;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: fill,
        borderRadius: BorderRadius.circular(circle ? size / 2 : r),
        boxShadow: [
          BoxShadow(
              color: glow,
              blurRadius: 14,
              spreadRadius: -6,
              offset: const Offset(0, 6)),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(circle ? size / 2 : r),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
          stops: [0, .35],
        ),
      ),
      child: imageUrl != null
          ? Image.network(imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initials())
          : _initials(),
    );
  }

  Widget _initials() => Text(
        initialsOf(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.33,
          fontWeight: FontWeight.w700,
          shadows: const [Shadow(color: Color(0x4D000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
      );
}

/// Blinking live dot.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color, this.size = 9});

  final Color? color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
          color: widget.color ?? DesignTokens.lagoon, shape: BoxShape.circle),
    );
    if (reduceMotion(context)) return dot;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value;
        final o = t < .5 ? 1 - (t / .5) * .55 : .45 + ((t - .5) / .5) * .55;
        return Opacity(opacity: o, child: child);
      },
      child: dot,
    );
  }
}

/// Expanding ring (SOS button halo, splash logo).
class HaloRing extends StatefulWidget {
  const HaloRing({
    super.key,
    required this.size,
    required this.color,
    this.radius,
    this.from = 1,
    this.to = 1.6,
    this.period = const Duration(milliseconds: 1800),
  });

  final double size;
  final Color color;
  final double? radius;
  final double from;
  final double to;
  final Duration period;

  @override
  State<HaloRing> createState() => _HaloRingState();
}

class _HaloRingState extends State<HaloRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return SizedBox.square(dimension: widget.size);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = Curves.easeOut.transform(_c.value);
          return Transform.scale(
            scale: widget.from + (widget.to - widget.from) * t,
            child: Opacity(
              opacity: (0.5 * (1 - t)).clamp(0, 1),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: widget.radius == null
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  borderRadius: widget.radius == null
                      ? null
                      : BorderRadius.circular(widget.radius!),
                  border: Border.all(color: widget.color, width: 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Motion ──────────────────────────────────────────────────────────────

/// Fade and rise 14 px on first build (420 ms).
class FadeRise extends StatefulWidget {
  const FadeRise({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = DesignTokens.enter,
    this.offset = 14,
    this.fromRight = false,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;
  final bool fromRight;

  @override
  State<FadeRise> createState() => _FadeRiseState();
}

class _FadeRiseState extends State<FadeRise>
    with SingleTickerProviderStateMixin {
  // The delay is the start of one longer animation (no timers), so an
  // entrance always finishes with its frames.
  late final Duration _total = widget.delay + widget.duration;
  late final AnimationController _c =
      AnimationController(vsync: this, duration: _total)..forward();
  late final double _start = _total.inMicroseconds == 0
      ? 0
      : widget.delay.inMicroseconds / _total.inMicroseconds;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = _start >= 1
            ? 1.0
            : ((_c.value - _start) / (1 - _start)).clamp(0.0, 1.0);
        final t = DesignTokens.easeOut.transform(v);
        final d = (1 - t) * widget.offset;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: widget.fromRight ? Offset(d * 2, 0) : Offset(0, d),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// List entrance: items fade up one after another (60 ms apart).
class Stagger {
  static List<Widget> wrap(List<Widget> children,
      {double gap = 0, Duration start = const Duration(milliseconds: 80)}) {
    final out = <Widget>[];
    var i = 0;
    for (final child in children) {
      if (gap > 0 && out.isNotEmpty) out.add(SizedBox(height: gap));
      out.add(FadeRise(
        delay: start + Duration(milliseconds: 60 * (i < 6 ? i : 6)),
        duration: const Duration(milliseconds: 500),
        child: child,
      ));
      i++;
    }
    return out;
  }
}

/// Slides up from the bottom edge (550 ms, ease-out) — bottom sheets.
class SlideUp extends StatefulWidget {
  const SlideUp({super.key, required this.child});

  final Widget child;

  @override
  State<SlideUp> createState() => _SlideUpState();
}

class _SlideUpState extends State<SlideUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: DesignTokens.sheet)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1.05), end: Offset.zero)
          .animate(CurvedAnimation(parent: _c, curve: DesignTokens.easeOut)),
      child: widget.child,
    );
  }
}

// ── Controls ────────────────────────────────────────────────────────────

/// Segmented control (Light / Dark / System, Today / Week / Month).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.height = 44,
    this.semanticLabel,
  });

  final List<(T value, String label, IconData? icon)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      container: true,
      child: PrismSegment<T>(
        height: height < 40 ? height : 36,
        options: [for (final (v, label, icon) in options) (v, label, icon)],
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

/// All / Completed / Cancelled pills: ink when active.
class FilterPills<T> extends StatelessWidget {
  const FilterPills({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return PrismSegment<T>(
      options: [for (final (v, label) in options) (v, label, null)],
      value: value,
      onChanged: onChanged,
    );
  }
}

/// ".seg": a tinted pill track with a white pill that snaps to the chosen
/// option.
class PrismSegment<T> extends StatelessWidget {
  const PrismSegment({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.height = 36,
  });

  final List<(T, String, IconData?)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final index = options.indexWhere((o) => o.$1 == value);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DesignTokens.line),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / options.length;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              if (index >= 0)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 600),
                  curve: DesignTokens.snap,
                  left: w * index,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: OuterShadow(
                    shadows: DesignTokens.shadow1,
                    radius: 999,
                    child: Container(
                      decoration: BoxDecoration(
                        color: DesignTokens.pillBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: DesignTokens.lineStrong),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  for (final (v, label, icon) in options)
                    Expanded(
                      child: Semantics(
                        selected: v == value,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(v),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (icon != null) ...[
                                  Icon(icon,
                                      size: 16,
                                      color: v == value
                                          ? DesignTokens.ink
                                          : DesignTokens.ink2),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: AnimatedDefaultTextStyle(
                                    duration: DesignTokens.quick,
                                    style: TextStyle(
                                        fontFamily: DesignTokens.font,
                                        color: v == value
                                            ? DesignTokens.ink
                                            : DesignTokens.ink2,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600),
                                    child: Text(label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Lagoon toggle with a springy knob.
class SunSwitch extends StatelessWidget {
  const SunSwitch(
      {super.key, required this.value, required this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: Pressable(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: DesignTokens.quick,
          width: 46,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? DesignTokens.lagoon : DesignTokens.lineStrong,
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 500),
            curve: DesignTokens.spring,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 6,
                      offset: Offset(0, 2))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minus · count · plus stepper (passengers).
class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String label, bool enabled, int to) => Pressable(
          onTap: enabled ? () => onChanged(to) : null,
          semanticLabel: label,
          child: AnimatedOpacity(
            duration: DesignTokens.quick,
            opacity: enabled ? 1 : .4,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: DesignTokens.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: DesignTokens.lineStrong),
              ),
              child: Icon(icon, size: 18, color: DesignTokens.ink),
            ),
          ),
        );
    // ".stepper": round − / + buttons on a tinted pill, the count in mono.
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DesignTokens.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          step(Icons.remove_rounded, "Remove a passenger", value > min,
              value - 1),
          Text("$value",
              style: DesignTokens.mono.copyWith(fontSize: 16)),
          step(Icons.add_rounded, "Add a passenger", value < max, value + 1),
        ],
      ),
    );
  }
}

// ── Ride pieces ─────────────────────────────────────────────────────────

/// Pickup (lagoon dot) and drop-off (orange square) joined by a dashed
/// line, inside a tinted box. Rows are tappable when given callbacks.
class RoutePoints extends StatelessWidget {
  const RoutePoints({
    super.key,
    required this.pickup,
    required this.dropoff,
    this.pickupLabel = "Pickup",
    this.dropoffLabel = "Drop-off",
    this.pickupNote,
    this.dropoffNote,
    this.onPickup,
    this.onDropoff,
    this.pickupTrailing,
    this.dropoffTrailing,
    this.highlightPickup = false,
    this.highlightDropoff = false,
    this.showLabels = true,
    this.pickupPlaceholder = false,
    this.dropoffPlaceholder = false,
  });

  final String pickup;
  final String dropoff;
  final String pickupLabel;
  final String dropoffLabel;
  final String? pickupNote;
  final String? dropoffNote;
  final VoidCallback? onPickup;
  final VoidCallback? onDropoff;
  final Widget? pickupTrailing;
  final Widget? dropoffTrailing;
  final bool highlightPickup;
  final bool highlightDropoff;
  final bool showLabels;
  final bool pickupPlaceholder;
  final bool dropoffPlaceholder;

  @override
  Widget build(BuildContext context) {
    Widget row({
      required bool isPickup,
      required String label,
      required String value,
      String? note,
      VoidCallback? onTap,
      Widget? trailing,
      required bool highlight,
      required bool placeholder,
    }) {
      final tint = isPickup ? DesignTokens.lagoon : DesignTokens.ember;
      final marker = Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: tint,
          shape: isPickup ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isPickup ? null : BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(color: tint.withValues(alpha: .25), spreadRadius: 3),
            BoxShadow(color: tint, blurRadius: 10),
          ],
        ),
      );
      final content = AnimatedContainer(
        duration: DesignTokens.quick,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: DesignTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight ? DesignTokens.lagoon : DesignTokens.line,
            width: highlight ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            marker,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showLabels) ...[
                    Overline(label,
                        color: highlight ? DesignTokens.lagoonText : null),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: placeholder ? DesignTokens.ink2 : DesignTokens.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 1),
                    Text(note,
                        style: TextStyle(
                            color: DesignTokens.ink2,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );
      final framed = OuterShadow(
        radius: 16,
        shadows: highlight
            ? [
                BoxShadow(
                    color: DesignTokens.glowLagoon,
                    blurRadius: 20,
                    spreadRadius: -8)
              ]
            : null,
        child: content,
      );
      if (onTap == null) return framed;
      return Pressable(onTap: onTap, child: framed);
    }

    // ".locs": two rows joined by a dashed line through the markers.
    return Stack(
      children: [
          Positioned(
            left: 19,
            top: 26,
            bottom: 26,
            child: CustomPaint(
              size: const Size(2, double.infinity),
              painter: _DashPainter(DesignTokens.lineStrong),
            ),
          ),
          Column(
            children: [
              row(
                isPickup: true,
                label: pickupLabel,
                value: pickup,
                note: pickupNote,
                onTap: onPickup,
                trailing: pickupTrailing,
                highlight: highlightPickup,
                placeholder: pickupPlaceholder,
              ),
              const SizedBox(height: 8),
              row(
                isPickup: false,
                label: dropoffLabel,
                value: dropoff,
                note: dropoffNote,
                onTap: onDropoff,
                trailing: dropoffTrailing,
                highlight: highlightDropoff,
                placeholder: dropoffPlaceholder,
              ),
            ],
          ),
        ],
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
          Offset(0, y), Offset(0, (y + 4).clamp(0, size.height)), paint);
      y += 8;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Row of digit boxes (pickup PIN, sign-up code).
class DigitBoxes extends StatelessWidget {
  const DigitBoxes({
    super.key,
    required this.value,
    required this.length,
    this.height = 56,
    this.fontSize = 26,
    this.gap = 8,
    this.radius = 15,
    this.readOnly = false,
  });

  final String value;
  final int length;
  final double height;
  final double fontSize;
  final double gap;
  final double radius;

  /// A PIN shown to the passenger: every box solid, no "next" cue.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 300),
              curve: DesignTokens.spring,
              scale: !readOnly && i < value.length ? 1.03 : 1,
              child: OuterShadow(
              radius: radius,
              shadows: !readOnly && i == value.length
                  ? [
                      BoxShadow(
                          color: DesignTokens.glowLagoon,
                          blurRadius: 20,
                          spreadRadius: -6)
                    ]
                  : null,
              child: AnimatedContainer(
                duration: DesignTokens.quick,
                height: height,
                alignment: Alignment.center,
                // The next box to fill gets the lagoon focus ring.
                decoration: BoxDecoration(
                  color: DesignTokens.inputBg,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    width: !readOnly && i == value.length ? 1.5 : 1,
                    color: !readOnly && i == value.length
                        ? DesignTokens.lagoon
                        : DesignTokens.lineStrong,
                  ),
                ),
                child: Text(
                  i < value.length ? value[i] : "",
                  style: DesignTokens.mono.copyWith(
                    fontSize: fontSize,
                    shadows: [
                      Shadow(
                          color: DesignTokens.amber.withValues(alpha: .55),
                          blurRadius: 18),
                    ],
                  ),
                ),
              ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A design-style form field: bold label, tinted 54 px box, leading icon,
/// orange focus ring, red when [errorText] is set.
class SunField extends StatefulWidget {
  const SunField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.keyboardType,
    this.obscure = false,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
    this.prefix,
    this.labelTrailing,
    this.inputFormatters,
    this.helper,
    this.helperColor,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? prefix;
  final Widget? labelTrailing;
  final List<TextInputFormatter>? inputFormatters;
  final String? helper;
  final Color? helperColor;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final int maxLines;

  @override
  State<SunField> createState() => _SunFieldState();
}

class _SunFieldState extends State<SunField> {
  final _focus = FocusNode();
  bool _hide = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final error = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(widget.label,
                  style: TextStyle(
                      color: DesignTokens.ink1,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
            if (widget.labelTrailing != null) widget.labelTrailing!,
          ],
        ),
        const SizedBox(height: 6),
        // ".fld input": dark glassy well, lagoon ring and glow on focus,
        // danger ring on error.
        OuterShadow(
          radius: 15,
          shadows: error
              ? [
                  BoxShadow(
                      color: DesignTokens.danger.withValues(alpha: .14),
                      spreadRadius: 4)
                ]
              : focused
                  ? [
                      BoxShadow(
                          color: DesignTokens.lagoon.withValues(alpha: .2),
                          spreadRadius: 4),
                      BoxShadow(
                          color: DesignTokens.glowLagoon,
                          blurRadius: 26,
                          spreadRadius: -6),
                    ]
                  : null,
          child: AnimatedContainer(
          duration: DesignTokens.quick,
          curve: DesignTokens.easeOut,
          constraints: BoxConstraints(minHeight: widget.maxLines > 1 ? 96 : 50),
          padding: EdgeInsets.only(
              left: widget.prefix != null ? 8 : 15,
              right: widget.obscure ? 4 : 15),
          decoration: BoxDecoration(
            color: DesignTokens.inputBg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              width: 1,
              color: error
                  ? DesignTokens.danger
                  : focused
                      ? DesignTokens.lagoon
                      : DesignTokens.lineStrong,
            ),
          ),
          child: Row(
            crossAxisAlignment: widget.maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (widget.prefix != null) ...[
                widget.prefix!,
                const SizedBox(width: 10),
              ],
              // Prism inputs are plain wells: [icon] is kept for callers but
              // not drawn.
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  obscureText: widget.obscure && _hide,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  autofillHints: widget.autofillHints,
                  inputFormatters: widget.inputFormatters,
                  textCapitalization: widget.textCapitalization,
                  maxLines: widget.obscure ? 1 : widget.maxLines,
                  minLines: 1,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: DesignTokens.lagoon,
                  style: TextStyle(
                      color: DesignTokens.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                        color: DesignTokens.ink2.withValues(alpha: .8),
                        fontSize: 15,
                        fontWeight: FontWeight.w400),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (widget.obscure)
                IconButton(
                  onPressed: () => setState(() => _hide = !_hide),
                  tooltip: _hide ? "Show password" : "Hide password",
                  // The icon shows the state: a closed eye while hidden, an
                  // open eye while the password can be read.
                  icon: Icon(
                    _hide
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: DesignTokens.ink2,
                  ),
                ),
            ],
          ),
        ),
        ),
        if (error) ...[
          const SizedBox(height: 6),
          Shake(
            key: ValueKey(widget.errorText),
            child: Text(widget.errorText!,
                style: TextStyle(
                    color: DesignTokens.danger,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
        ] else if (widget.helper != null) ...[
          const SizedBox(height: 6),
          Text(widget.helper!,
              style: TextStyle(
                  color: widget.helperColor ?? DesignTokens.ink2,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

/// Horizontal shake once on first build (wrong PIN, field error).
class Shake extends StatefulWidget {
  const Shake({super.key, required this.child});

  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        const offsets = [0.0, -6.0, 6.0, -4.0, 4.0, 0.0];
        final p = _c.value * (offsets.length - 1);
        final i = p.floor().clamp(0, offsets.length - 2);
        final dx = offsets[i] + (offsets[i + 1] - offsets[i]) * (p - i);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

// ── Dialogs ─────────────────────────────────────────────────────────────

/// A floating card that pops up from the bottom over a blurred scrim —
/// the Sunrise dialog (SOS, confirmations, results).
Future<T?> showSunSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: "Close",
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (dialogContext, _, __) => builder(dialogContext),
    transitionBuilder: (context, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: DesignTokens.spring);
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap:
                  dismissible ? () => Navigator.of(context).maybePop() : null,
              child: FadeTransition(
                opacity: fade,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: ColoredBox(color: DesignTokens.scrim),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: 12 + MediaQuery.viewInsetsOf(context).bottom),
                child: FadeTransition(
                  opacity: fade,
                  child: AnimatedBuilder(
                    animation: curved,
                    builder: (_, c) => Transform.translate(
                      offset: Offset(0, 40 * (1 - curved.value)),
                      child: Transform.scale(
                          scale: 0.96 + 0.04 * curved.value, child: c),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Body of a [showSunSheet] card: optional round icon, title, message and
/// actions, centred.
class SunSheetCard extends StatelessWidget {
  const SunSheetCard({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.iconBg,
    this.iconFg,
    this.ring = false,
    this.content = const [],
    this.actions = const [],
    this.align = CrossAxisAlignment.center,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final Color? iconBg;
  final Color? iconFg;
  final bool ring;
  final List<Widget> content;
  final List<Widget> actions;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final centered = align == CrossAxisAlignment.center;
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: PrismGlass(
        strong: true,
        spin: true,
        radius: 28,
        tint: DesignTokens.solid.withValues(alpha: .94),
        shadows: DesignTokens.shadowSheet,
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: align,
            children: [
              if (icon != null) ...[
                SizedBox(
                  width: 68,
                  height: 68,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (ring)
                        HaloRing(size: 68, color: iconFg ?? DesignTokens.sos),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                            color: iconBg ?? DesignTokens.surface2,
                            shape: BoxShape.circle),
                        child: Icon(icon,
                            size: 30, color: iconFg ?? DesignTokens.ink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(title,
                  textAlign: centered ? TextAlign.center : TextAlign.start,
                  style: DesignTokens.title),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(message!,
                    textAlign: centered ? TextAlign.center : TextAlign.start,
                    style: DesignTokens.body),
              ],
              for (final child in content) ...[
                const SizedBox(height: 14),
                child,
              ],
              for (var i = 0; i < actions.length; i++) ...[
                SizedBox(height: i == 0 ? 18 : 10),
                actions[i],
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Yes/no confirmation in the Sunrise style. Returns true on confirm.
Future<bool> confirmSun(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = "Cancel",
  bool destructive = false,
  IconData? icon,
}) async {
  final ok = await showSunSheet<bool>(
    context,
    builder: (dialogContext) => SunSheetCard(
      title: title,
      message: message,
      icon: icon,
      iconBg: destructive ? DesignTokens.sosSoft : DesignTokens.primarySoft,
      iconFg: destructive ? DesignTokens.sosText : DesignTokens.primaryText,
      actions: [
        SunButton(
          label: confirmLabel,
          tone: destructive ? SunTone.sos : SunTone.primary,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
        SunButton(
          label: cancelLabel,
          tone: SunTone.quiet,
          height: 48,
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
      ],
    ),
  );
  return ok == true;
}

// ── Floating tab bar ────────────────────────────────────────────────────

class SunTab {
  const SunTab({required this.icon, required this.label, this.badge = 0});

  final IconData icon;
  final String label;
  final int badge;
}

/// ".tabbar": a glass pill floating 12 px above the bottom edge with a
/// travelling prism rim; a white pill with a prism underline snaps between
/// tabs. The active icon is ember for passengers, lagoon for drivers
/// ([accent]).
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.semanticLabel = "Main",
    this.accent,
  });

  final List<SunTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final String semanticLabel;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    final driver = semanticLabel == "Driver";
    final iconColor =
        accent ?? (driver ? DesignTokens.lagoonText : DesignTokens.emberInk);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + inset),
      child: Semantics(
        container: true,
        label: semanticLabel,
        child: PrismGlass(
          height: 64,
          radius: 999,
          spin: true,
          shadows: DesignTokens.shadow3,
          padding: const EdgeInsets.all(6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth / tabs.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 650),
                    curve: DesignTokens.snap,
                    left: w * index,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: OuterShadow(
                      shadows: DesignTokens.shadow1,
                      radius: 999,
                      child: Container(
                      decoration: BoxDecoration(
                        color: DesignTokens.pillBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: DesignTokens.lineStrong),
                      ),
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(bottom: 3),
                      child: FractionallySizedBox(
                        widthFactor: .52,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(colors: [
                              DesignTokens.ember,
                              DesignTokens.amber,
                              DesignTokens.lagoon,
                            ]),
                            boxShadow: [
                              BoxShadow(
                                  color: DesignTokens.glowEmber, blurRadius: 4)
                            ],
                          ),
                        ),
                      ),
                    ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < tabs.length; i++)
                        Expanded(
                            child: _TabButton(
                          tab: tabs[i],
                          active: i == index,
                          accent: iconColor,
                          onTap: () => onChanged(i),
                        )),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton(
      {required this.tab,
      required this.active,
      required this.accent,
      required this.onTap});

  final SunTab tab;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      button: true,
      label: tab.badge > 0 ? "${tab.label}, ${tab.badge} unread" : tab.label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSlide(
                  duration: const Duration(milliseconds: 550),
                  curve: DesignTokens.spring,
                  offset: Offset(0, active ? -0.05 : 0),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 550),
                    curve: DesignTokens.spring,
                    scale: active ? 1.08 : 1,
                    child: Icon(tab.icon,
                        size: 20, color: active ? accent : DesignTokens.ink2),
                  ),
                ),
                const SizedBox(height: 3),
                Text(tab.label,
                    style: TextStyle(
                        color: active ? DesignTokens.ink : DesignTokens.ink2,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            // Unread: just a small ember dot by the icon (".ibtn .dot");
            // the count stays in the label read by screen readers.
            if (tab.badge > 0)
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: Align(
                  alignment: const Alignment(0.3, 0),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: DesignTokens.ember,
                      shape: BoxShape.circle,
                      border: Border.all(color: DesignTokens.bgDeep, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: DesignTokens.glowEmber, blurRadius: 6)
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A glass toast near the top with a glowing dot (".toast"), auto-hiding.
void showSunToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      content: PrismGlass(
        strong: true,
        radius: 20,
        shadows: DesignTokens.shadow3,
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: DesignTokens.lagoon,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: DesignTokens.lagoon.withValues(alpha: .2),
                      spreadRadius: 4),
                  BoxShadow(color: DesignTokens.lagoon, blurRadius: 12),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      color: DesignTokens.ink1,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
      duration: const Duration(milliseconds: 2800),
    ));
}

/// ".prog": three bars (Accepted · At pickup · On trip) that fill with the
/// lagoon › amber › ember gradient up to [step] (1–3), with mono labels.
class RideProgressBars extends StatelessWidget {
  const RideProgressBars({super.key, required this.step, this.labels = false});

  final int step;
  final bool labels;

  static const _names = ["Accepted", "At pickup", "On trip"];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: DesignTokens.lineStrong,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: i < step ? 1 : 0),
                    duration: const Duration(milliseconds: 900),
                    curve: DesignTokens.easeOut,
                    builder: (_, v, __) => FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          gradient: LinearGradient(colors: [
                            DesignTokens.lagoon,
                            DesignTokens.amber,
                            DesignTokens.ember,
                          ], stops: const [0, .62, 1]),
                          boxShadow: [
                            BoxShadow(
                                color: DesignTokens.glowEmber, blurRadius: 12)
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (labels) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Overline(_names[i],
                      color: i < step ? DesignTokens.ink : null),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// ".chip": a 44 px glass pill over the map — an optional leading avatar,
/// a mono overline and a bold line ("GOOD MORNING / Juan").
class PrismChip extends StatelessWidget {
  const PrismChip({
    super.key,
    required this.title,
    this.overline,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? overline;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Glass(
      padding: EdgeInsets.fromLTRB(leading == null ? 15 : 5, 5, 15, 5),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 34),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 9)],
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (overline != null)
                    Text(overline!.toUpperCase(),
                        style: DesignTokens.overline
                            .copyWith(fontSize: 9.5, letterSpacing: 1.1)),
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: DesignTokens.ink,
                          fontSize: 13,
                          height: 1.25,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 9), trailing!],
          ],
        ),
      ),
    );
  }
}

/// ".livep": a glass pill with a pinging lagoon dot ("4 riders online
/// nearby").
class LivePill extends StatelessWidget {
  const LivePill({super.key, required this.text, this.active = true});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tint = active ? DesignTokens.lagoon : DesignTokens.ink2;
    return Glass(
      padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                color: tint.withValues(alpha: .18), shape: BoxShape.circle),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (active)
                  HaloRing(
                      size: 12,
                      color: tint,
                      from: .5,
                      to: 1.7,
                      period: const Duration(milliseconds: 2200)),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: tint, blurRadius: 10)],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: DesignTokens.ink1,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// ".search": a 52 px input-like button that opens place search.
class SearchWell extends StatelessWidget {
  const SearchWell(
      {super.key, required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: DesignTokens.inputBg,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: DesignTokens.lineStrong),
        ),
        child: Row(
          children: [
            Icon(icon ?? Icons.search_rounded,
                size: 20, color: DesignTokens.ink2),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: DesignTokens.ink2, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

/// ".pchip": a saved-place pill (Home, School, Market).
class PlaceChip extends StatelessWidget {
  const PlaceChip(
      {super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
        decoration: BoxDecoration(
          color: DesignTokens.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: DesignTokens.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: DesignTokens.emberInk),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    color: DesignTokens.ink1,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// ".pinblk": the passenger's 4-digit PIN in an amber-tinted box.
class PinBlock extends StatelessWidget {
  const PinBlock(
      {super.key,
      required this.pin,
      this.label = "Your PIN · give it to the driver"});

  final String pin;
  final String label;

  @override
  Widget build(BuildContext context) {
    final base =
        DesignTokens.isDark ? const Color(0x8C080918) : const Color(0xA8FFFFFF);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
            DesignTokens.amber.withValues(alpha: .08), base),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.amber.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Overline(label),
          const SizedBox(height: 10),
          DigitBoxes(
              value: pin, length: pin.length, readOnly: true, height: 54),
        ],
      ),
    );
  }
}

/// ".ibtn.sos": the red SOS pill with a pulsing ring.
class SosPill extends StatelessWidget {
  const SosPill({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: "SOS",
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          HaloRing(
              size: 44,
              radius: 22,
              color: DesignTokens.danger,
              from: .9,
              to: 1.25,
              period: const Duration(milliseconds: 2000)),
          OuterShadow(
            radius: 22,
            shadows: DesignTokens.shadowSos,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: DesignTokens.dangerFill,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text("SOS",
                  style: TextStyle(
                      fontFamily: DesignTokens.fontMono,
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// ".alert": a tinted note with a glowing dot (or a spinner) — info in
/// lagoon, ok, warn, error in danger.
class PrismAlert extends StatelessWidget {
  const PrismAlert({
    super.key,
    required this.tone,
    this.title,
    this.message,
    this.spinner = false,
    this.trailing,
  });

  final Color tone;
  final String? title;
  final String? message;
  final bool spinner;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final base =
        DesignTokens.isDark ? const Color(0x8C080918) : const Color(0xA8FFFFFF);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(tone.withValues(alpha: .10), base),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: .34)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: spinner
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: tone))
                : Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: tone,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: tone.withValues(alpha: .18),
                            spreadRadius: 4),
                        BoxShadow(color: tone, blurRadius: 12),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!,
                      style: TextStyle(
                          color: DesignTokens.ink,
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w700)),
                if (message != null)
                  Text(message!,
                      style: TextStyle(
                          color: DesignTokens.ink1,
                          fontSize: 13,
                          height: 1.5)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// ".status-ic": a glossy disc (ok, lagoon, danger, dusk, ember) with a
/// white icon, a turning conic ring and an expanding halo.
class StatusRing extends StatefulWidget {
  const StatusRing({
    super.key,
    required this.icon,
    this.fill = DesignTokens.okFill,
    this.size = 64,
  });

  final IconData icon;
  final Gradient fill;
  final double size;

  @override
  State<StatusRing> createState() => _StatusRingState();
}

class _StatusRingState extends State<StatusRing>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ambientMotion(context) && _c == null) {
      _c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 2400))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Color get _tone {
    final g = widget.fill;
    return g is LinearGradient ? g.colors.last : DesignTokens.ok;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final ring = s + 18;
    Widget conic(double turn) => CustomPaint(
          size: Size.square(ring),
          painter: _ConicRingPainter(tone: _tone, turn: turn),
        );
    final c = _c;
    return SizedBox(
      width: ring + 24,
      height: ring + 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (c != null)
            HaloRing(
                size: ring,
                color: _tone,
                from: .92,
                to: 1.45,
                period: const Duration(milliseconds: 2600)),
          c == null
              ? conic(0)
              : AnimatedBuilder(
                  animation: c, builder: (_, __) => conic(c.value)),
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              gradient: widget.fill,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: _tone.withValues(alpha: .6),
                    blurRadius: 32,
                    spreadRadius: -8,
                    offset: const Offset(0, 12)),
              ],
            ),
            foregroundDecoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x40FFFFFF), Color(0x00FFFFFF), Color(0x1F000000)],
                stops: [0, .4, 1],
              ),
            ),
            child: Icon(widget.icon, size: s * .44, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ConicRingPainter extends CustomPainter {
  _ConicRingPainter({required this.tone, required this.turn});

  final Color tone;
  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          tone.withValues(alpha: 0),
          tone.withValues(alpha: 0),
          tone.withValues(alpha: .35),
          tone,
          Color.lerp(tone, Colors.white, .6)!,
        ],
        stops: const [0, .12, .3, .78, 1],
        transform: GradientRotation(turn * 2 * 3.1415926535),
      ).createShader(rect);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(_ConicRingPainter old) =>
      old.turn != turn || old.tone != tone;
}

/// ".meta3": three small centred stats (Distance · Time · Passengers).
class MetaStats extends StatelessWidget {
  const MetaStats({super.key, required this.items});

  final List<(String value, String label)> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DesignTokens.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DesignTokens.line),
              ),
              child: Column(
                children: [
                  Text(items[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTokens.mono.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(items[i].$2,
                      style:
                          TextStyle(color: DesignTokens.ink2, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// ".drvrow": avatar, name and a small line, with an optional round call
/// button.
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.name,
    required this.subtitle,
    this.tone,
    this.onCall,
    this.imageUrl,
  });

  final String name;
  final String subtitle;
  final AvatarTone? tone;
  final VoidCallback? onCall;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ToneAvatar(
            name: name,
            size: 42,
            circle: true,
            imageUrl: imageUrl,
            tone: tone ?? toneFor(name)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: DesignTokens.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: DesignTokens.ink2, fontSize: 12.5)),
            ],
          ),
        ),
        if (onCall != null)
          Pressable(
            onTap: onCall,
            semanticLabel: "Call $name",
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: DesignTokens.lagoon.withValues(alpha: .16),
                shape: BoxShape.circle,
                border: Border.all(
                    color: DesignTokens.lagoon.withValues(alpha: .4)),
              ),
              child: Icon(Icons.call_outlined,
                  size: 19, color: DesignTokens.lagoonText),
            ),
          ),
      ],
    );
  }
}

/// ".rate-stars": five 48 px stars; chosen ones glow amber and pop.
class RateStars extends StatelessWidget {
  const RateStars({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          Semantics(
            button: true,
            selected: i == value,
            label: "$i star${i > 1 ? "s" : ""}",
            child: Pressable(
              onTap: () => onChanged(i),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey("star-$i-${i <= value}"),
                    tween: Tween(begin: i <= value ? 1.3 : 1, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: DesignTokens.spring,
                    builder: (_, k, child) =>
                        Transform.scale(scale: k, child: child),
                    child: Icon(
                      Icons.star_rounded,
                      size: 36,
                      color: i <= value
                          ? DesignTokens.amber
                          : DesignTokens.ink2.withValues(alpha: .38),
                      shadows: i <= value
                          ? [
                              Shadow(
                                  color: DesignTokens.amber
                                      .withValues(alpha: .6),
                                  blurRadius: 8)
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// ".prism-card": a tappable glass card with a travelling prism rim, a
/// gradient icon tile, a title and a small line ("Switch to Driver Mode").
class PrismCard extends StatelessWidget {
  const PrismCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.lagoon = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Lagoon tile and glow instead of ember (Driver → Passenger).
  final bool lagoon;

  @override
  Widget build(BuildContext context) {
    final glow = lagoon ? DesignTokens.glowLagoon : DesignTokens.glowEmber;
    return Pressable(
      onTap: onTap,
      child: PrismGlass(
        radius: 24,
        spin: true,
        shadows: [
          ...DesignTokens.shadow2,
          BoxShadow(
              color: glow,
              blurRadius: 90,
              spreadRadius: -50,
              offset: const Offset(0, 40)),
        ],
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient:
                    lagoon ? DesignTokens.lagoonFill : DesignTokens.emberFill,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: glow,
                      blurRadius: 22,
                      spreadRadius: -8,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Icon(icon, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: DesignTokens.ink,
                          fontSize: 16,
                          letterSpacing: -0.3,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: DesignTokens.ink2, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: DesignTokens.ink),
          ],
        ),
      ),
    );
  }
}

/// ".prof": the big avatar with a lagoon ring, the name and a line under it.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.subtitle,
    this.imageUrl,
    this.tone = AvatarTone.lagoon,
    this.onAvatarTap,
    this.trailing,
  });

  final String name;
  final String subtitle;
  final String? imageUrl;
  final AvatarTone tone;
  final VoidCallback? onAvatarTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: DesignTokens.lagoon.withValues(alpha: .7), width: 1.5),
      ),
      child: ToneAvatar(
          name: name, size: 72, circle: true, tone: tone, imageUrl: imageUrl),
    );
    return Column(
      children: [
        if (onAvatarTap == null)
          avatar
        else
          Pressable(
            onTap: onAvatarTap,
            semanticLabel: "Change profile picture",
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                avatar,
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: DesignTokens.bgDeep,
                      shape: BoxShape.circle,
                      border: Border.all(color: DesignTokens.lineStrong),
                    ),
                    child: Icon(Icons.photo_camera_outlined,
                        size: 13, color: DesignTokens.ink),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Text(name, textAlign: TextAlign.center, style: DesignTokens.title),
        const SizedBox(height: 4),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: DesignTokens.ink2, fontSize: 13.5)),
        if (trailing != null) ...[const SizedBox(height: 10), trailing!],
      ],
    );
  }
}

/// ".sosbtn": the 170 px glossy red SOS disc with two rings rippling out.
class SosBigButton extends StatefulWidget {
  const SosBigButton({super.key, required this.onTap, required this.caption});

  final VoidCallback? onTap;
  final String caption;

  @override
  State<SosBigButton> createState() => _SosBigButtonState();
}

class _SosBigButtonState extends State<SosBigButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _ring(double t) {
    final k = DesignTokens.easeOut.transform(t);
    return Transform.scale(
      scale: 1 + .25 * k,
      child: Opacity(
        opacity: (.7 * (1 - k)).clamp(0.0, 1.0),
        child: Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: DesignTokens.danger, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return Semantics(
      button: true,
      label: "SOS. ${widget.caption}",
      excludeSemantics: true,
      child: Pressable(
        onTap: widget.onTap,
        child: SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!still)
                AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      _ring(_c.value),
                      _ring((_c.value + .5) % 1),
                    ],
                  ),
                ),
              OuterShadow(
                circle: true,
                shadows: [
                  BoxShadow(
                      color: DesignTokens.glowDanger,
                      blurRadius: 50,
                      spreadRadius: -14,
                      offset: const Offset(0, 20)),
                ],
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF7A88),
                        Color(0xFFE0283C),
                        Color(0xFFB0172A)
                      ],
                      stops: [0, .6, 1],
                    ),
                  ),
                  foregroundDecoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-.3, -.4),
                      radius: .55,
                      colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("SOS",
                          style: TextStyle(
                              fontFamily: DesignTokens.fontMono,
                              color: Colors.white,
                              fontSize: 34,
                              height: 1,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(widget.caption,
                          style: const TextStyle(
                              color: Color(0xE6FFFFFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
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
