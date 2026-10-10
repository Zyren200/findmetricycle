import "dart:async";

import "package:flutter/material.dart";

import "../components/sunrise.dart";
import "../theme/design_tokens.dart";
import "emergency_dialer.dart";
import "sos_delivery.dart";

/// The SOS flow shared by the passenger and driver screens: confirm, start
/// sending the alert, and — without waiting for the network — open the
/// dialer with the emergency number. [startDelivery] begins sending (it
/// returns at once; [SosDelivery] keeps retrying). Cancelling sends
/// nothing and opens nothing. [openDialer] is replaceable for tests.
///
/// With [delivery] (and [updates], the controller that changes when it
/// does), a "SOS sent" card follows that shows where the alert stands.
Future<void> confirmSosAndDial(
  BuildContext context, {
  required String confirmMessage,
  required void Function() startDelivery,
  Future<bool> Function() openDialer = openEmergencyDialer,
  SosDelivery? delivery,
  Listenable? updates,
}) async {
  final confirmed = await showSunSheet<bool>(
    context,
    builder: (dialogContext) => SunSheetCard(
      title: "Send an SOS?",
      message: "$confirmMessage Then we'll open your phone's dialer with "
          "$kEmergencyNumber ready. You only need to tap Call.",
      icon: Icons.health_and_safety_rounded,
      iconBg: DesignTokens.sosSoft,
      iconFg: DesignTokens.sosText,
      ring: true,
      content: const [
        if (kIsEmergencyTestBuild) EmergencyTestModeLabel(),
      ],
      actions: [
        SunButton(
          label: "Send SOS and open dialer",
          tone: SunTone.sos,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
        SunButton(
          label: "Cancel",
          tone: SunTone.quiet,
          height: 48,
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  startDelivery();
  final opened = await openDialer();
  if (!context.mounted) return;
  if (!opened) {
    await showDialManuallyDialog(context);
  } else if (delivery != null) {
    await showSunSheet<void>(
      context,
      builder: (dialogContext) =>
          _SosResultCard(delivery: delivery, updates: updates),
    );
  }
}

/// "SOS sent" — or still sending / waiting for the network.
class _SosResultCard extends StatelessWidget {
  const _SosResultCard({required this.delivery, this.updates});

  final SosDelivery delivery;
  final Listenable? updates;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: updates ?? const _Never(),
      builder: (context, _) {
        final status = delivery.status;
        final sent = status == SosDeliveryStatus.sent ||
            status == SosDeliveryStatus.idle;
        final pending = status == SosDeliveryStatus.pending;
        return SunSheetCard(
          title: sent
              ? "SOS sent"
              : pending
                  ? "SOS not sent yet"
                  : "Sending SOS…",
          message: sent
              ? "The admin can see your location and ride. Your dialer is open "
                  "with $kEmergencyNumber. Tap Call to reach responders."
              : pending
                  ? "No connection right now. It will send automatically once "
                      "you're back online. Your dialer is open with "
                      "$kEmergencyNumber."
                  : "Your location is being sent to the FindMeTricycle admin. "
                      "Your dialer is open with $kEmergencyNumber.",
          icon: sent
              ? Icons.check_rounded
              : pending
                  ? Icons.wifi_off_rounded
                  : Icons.sync_rounded,
          iconBg: sent ? DesignTokens.lagoonSoft : DesignTokens.sosSoft,
          iconFg: sent ? DesignTokens.lagoonText : DesignTokens.sosText,
          actions: [
            if (pending)
              SunButton(
                label: "Retry now",
                tone: SunTone.sos,
                height: 52,
                onPressed: () => unawaited(delivery.retry()),
              ),
            SunButton(
              label: "Done",
              tone: SunTone.ink,
              height: 52,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }
}

class _Never implements Listenable {
  const _Never();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Where the last SOS alert stands — shown on every screen with an SOS
/// button, so the user sees it on returning from the dialer.
class SosStatusBanner extends StatelessWidget {
  const SosStatusBanner({super.key, required this.delivery, this.error});

  final SosDelivery delivery;

  /// Why the last attempt failed, when known.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, title, detail) = switch (delivery.status) {
      SosDeliveryStatus.idle => (null, null, null, null, null),
      SosDeliveryStatus.sending => (
          DesignTokens.sosSoft,
          DesignTokens.sosText,
          Icons.sync_rounded,
          "Sending SOS…",
          "Your location is being sent to the FindMeTricycle admin.",
        ),
      SosDeliveryStatus.sent => (
          DesignTokens.lagoonSoft,
          DesignTokens.lagoonText,
          Icons.check_circle_rounded,
          "SOS sent to FindMeTricycle admin",
          "The admin team has your location and is responding.",
        ),
      SosDeliveryStatus.pending => (
          DesignTokens.sosSoft,
          DesignTokens.sosText,
          Icons.wifi_off_rounded,
          "SOS not sent yet — retrying",
          "It will send automatically once you're back online."
              "${error == null ? "" : "\n$error"}",
        ),
    };
    if (bg == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: fg, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title!,
                    style: TextStyle(
                        color: fg,
                        fontSize: 14,
                        fontWeight: DesignTokens.fw800)),
                const SizedBox(height: 2),
                Text(detail!,
                    style: TextStyle(
                        color: DesignTokens.ink,
                        fontSize: 12,
                        fontWeight: DesignTokens.fw500)),
              ],
            ),
          ),
          if (delivery.status == SosDeliveryStatus.pending)
            TextButton(
              onPressed: () => unawaited(delivery.retry()),
              child: Text("Retry", style: TextStyle(color: fg)),
            )
          else if (delivery.status == SosDeliveryStatus.sent)
            IconButton(
              tooltip: "Dismiss",
              onPressed: delivery.dismiss,
              icon:
                  Icon(Icons.close_rounded, size: 18, color: DesignTokens.ink2),
            ),
        ],
      ),
    );
  }
}

/// The 56 px red SOS button that sits next to the status pill over the map.
class SosSquareButton extends StatelessWidget {
  const SosSquareButton({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: "SOS emergency",
      child: _SosGlow(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: DesignTokens.sos,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.health_and_safety_rounded,
                  size: 20, color: DesignTokens.sosInk),
              SizedBox(height: 1),
              Text("SOS",
                  style: TextStyle(
                      color: DesignTokens.sosInk,
                      fontSize: 11,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The SOS button's slow breathing red glow.
class _SosGlow extends StatefulWidget {
  const _SosGlow({required this.child});

  final Widget child;

  @override
  State<_SosGlow> createState() => _SosGlowState();
}

class _SosGlowState extends State<_SosGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: DesignTokens.shadowSos),
        child: widget.child,
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value < .5 ? _c.value * 2 : (1 - _c.value) * 2;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              ...DesignTokens.shadowSos,
              BoxShadow(
                color: DesignTokens.sos.withAlpha((115 * (1 - t)).round()),
                spreadRadius: 8 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
