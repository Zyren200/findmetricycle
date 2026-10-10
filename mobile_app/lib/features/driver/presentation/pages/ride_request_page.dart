import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../../core/utils/geo_utils.dart";
import "../driver_home_page.dart" show shortPeso;
import "../driver_ride_controller.dart";
import "../widgets/driver_ride_actions.dart";
import "../widgets/driver_ride_map.dart";
import "active_ride_page.dart";

/// An incoming ride offer over the map: fare and distance, a ring that
/// counts down the 20 seconds, the passenger and the route, then Decline
/// or Accept. Accepting continues on [ActiveRidePage].
class RideRequestPage extends StatefulWidget {
  const RideRequestPage({super.key});

  @override
  State<RideRequestPage> createState() => _RideRequestPageState();
}

class _RideRequestPageState extends State<RideRequestPage> {
  Timer? _tick;
  bool _accepting = false;
  bool _declining = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _accept(DriverRideController ctrl) async {
    setState(() => _accepting = true);
    await ctrl.acceptIncomingBooking();
    if (!mounted) return;
    setState(() => _accepting = false);
    if (ctrl.activeBooking != null && ctrl.error == null) {
      pushDriverPage(context, const ActiveRidePage(), replace: true);
    }
  }

  Future<void> _decline(DriverRideController ctrl) async {
    setState(() => _declining = true);
    await ctrl.declineIncomingBooking();
    if (!mounted) return;
    showSunToast(context, "Request declined");
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    final booking = ctrl.incomingBooking;
    final remaining = offerSecondsLeft(booking);
    final expired = booking == null || remaining <= 0;

    return Scaffold(
      backgroundColor: DesignTokens.mapLand,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DriverRideMap(
              fitPadding: EdgeInsets.fromLTRB(60, 80, 60, 470),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: FadeRise(
                offset: 0,
                duration: const Duration(milliseconds: 250),
                child: ColoredBox(color: DesignTokens.scrim),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FadeRise(
                  offset: 40,
                  duration: const Duration(milliseconds: 450),
                  child: expired
                      ? _expiredCard(ctrl)
                      : _requestCard(ctrl, booking, remaining),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      child: PrismGlass(
        strong: true,
        spin: true,
        radius: DesignTokens.radiusSheet,
        shadows: DesignTokens.shadowSheet,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _expiredCard(DriverRideController ctrl) {
    return _card(children: [
      const Center(
        child: StatusRing(
            icon: Icons.timer_off_outlined, fill: DesignTokens.emberFill),
      ),
      const SizedBox(height: 6),
      Text("Request expired",
          textAlign: TextAlign.center, style: DesignTokens.title),
      const SizedBox(height: 6),
      Text(
        ctrl.error ?? "It went back to the passenger to choose another rider.",
        textAlign: TextAlign.center,
        style: DesignTokens.body,
      ),
      const SizedBox(height: 18),
      SunButton(
        label: "Back to requests",
        tone: SunTone.quiet,
        height: 52,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ]);
  }

  Widget _requestCard(
      DriverRideController ctrl, Map<String, dynamic> booking, int remaining) {
    final pax =
        int.tryParse(bookingText(booking, "passenger_count") ?? "") ?? 1;
    final distance = double.tryParse(booking["distance_km"]?.toString() ?? "");
    final passenger = bookingText(booking, "passenger_name") ?? "Passenger";
    final busy = ctrl.isBusy || _accepting || _declining;

    // How far the pickup is from the rider right now.
    final here = ctrl.currentPosition;
    final pickup = ctrl.pickupLocation;
    final toPickup = here == null || pickup == null
        ? null
        : haversineKm(
            lat1: here.latitude,
            lng1: here.longitude,
            lat2: pickup.latitude,
            lng2: pickup.longitude);
    String km(double d) =>
        d < 1 ? "${(d * 1000).round()} m" : "${d.toStringAsFixed(1)} km";
    int minutes(double d) => math.max(1, (d / 18 * 60).ceil());

    return Shake(
      child: _card(children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Overline("Est. fare · cash"),
                  const SizedBox(height: 4),
                  Text(
                    shortPeso(bookingFare(booking)),
                    style: TextStyle(
                      color: DesignTokens.ink,
                      fontSize: 38,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.9,
                      fontFeatures: DesignTokens.tabular,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (distance != null)
                        "${distance.toStringAsFixed(1)} km trip",
                      "$pax passenger${pax > 1 ? "s" : ""}",
                    ].join(" · "),
                    style:
                        TextStyle(color: DesignTokens.ink2, fontSize: 13.5),
                  ),
                ],
              ),
            ),
            _CountdownRing(secondsLeft: remaining, total: 20),
          ],
        ),
        const SizedBox(height: 16),
        PersonRow(
          name: passenger,
          tone: AvatarTone.lagoon,
          subtitle: "Passenger · pays cash",
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 14),
        RoutePoints(
          pickupLabel: toPickup == null
              ? "Pickup"
              : "Pickup · ${km(toPickup)} from you · ${minutes(toPickup)} min",
          pickup: bookingText(booking, "pickup_address") ?? "-",
          dropoffLabel: distance == null
              ? "Drop-off"
              : "Drop-off · about ${minutes(distance)} min",
          dropoff: bookingText(booking, "dropoff_address") ?? "-",
        ),
        if (ctrl.error != null) ...[
          const SizedBox(height: 12),
          ErrorBox(message: ctrl.error!),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SunButton(
                label: "Decline",
                tone: SunTone.quiet,
                loading: _declining,
                onPressed: busy ? null : () => _decline(ctrl),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SunButton(
                label: "Accept",
                loading: _accepting,
                onPressed: busy ? null : () => _accept(ctrl),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

/// 64 px ring that empties as the offer's seconds run out.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.secondsLeft, required this.total});

  final int secondsLeft;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = (secondsLeft / total).clamp(0.0, 1.0);
    return Semantics(
      label: "$secondsLeft seconds left to answer",
      liveRegion: true,
      excludeSemantics: true,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: const Duration(seconds: 1),
              builder: (_, v, __) => CustomPaint(
                size: const Size(64, 64),
                painter: _RingPainter(
                  value: v,
                  track: DesignTokens.lineStrong,
                  color: secondsLeft <= 5
                      ? DesignTokens.danger
                      : DesignTokens.ember,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("$secondsLeft",
                    style: DesignTokens.mono
                        .copyWith(fontSize: 20, height: 1, fontWeight: FontWeight.w600)),
                Text("sec",
                    style: TextStyle(
                        color: DesignTokens.ink2,
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.track, required this.color});

  final double value;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
        center: size.center(Offset.zero), radius: size.width / 2 - 6);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, stroke..color = track);
    final hot = color == DesignTokens.danger
        ? null
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFC24F), Color(0xFFFF5A1F)],
          ).createShader(rect);
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = color
          ..shader = hot);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
