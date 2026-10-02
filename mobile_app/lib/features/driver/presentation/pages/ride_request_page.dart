import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/theme/design_tokens.dart";
import "../driver_ride_controller.dart";
import "../widgets/driver_ride_actions.dart";
import "../widgets/driver_ride_map.dart";
import "active_ride_page.dart";

/// Full-screen view of an incoming ride offer with its countdown.
/// Accepting continues on [ActiveRidePage].
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
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    final booking = ctrl.incomingBooking;
    final remaining = offerSecondsLeft(booking);

    if (booking == null || remaining <= 0) {
      return Scaffold(
        backgroundColor: DesignTokens.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded,
                      size: 48, color: DesignTokens.muted),
                  const SizedBox(height: 16),
                  Text("Request Expired",
                      style: TextStyle(
                          color: DesignTokens.text,
                          fontWeight: DesignTokens.fw600)),
                  const SizedBox(height: 6),
                  Text(
                    ctrl.error ?? "This ride request is no longer available.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DesignTokens.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200,
                    child: PrimaryActionButton(
                      label: "Back to Home",
                      color: DesignTokens.driverAccent,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final pax = bookingText(booking, "passenger_count");
    final distance = double.tryParse(booking["distance_km"]?.toString() ?? "");
    final busy = ctrl.isBusy || _accepting || _declining;

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          AppTopBar(
            title: "New Ride Request",
            showBack: true,
            badge: "${remaining}s",
            badgeColor:
                remaining <= 10 ? DesignTokens.red : DesignTokens.driverAccent,
          ),
          const SizedBox(height: 180, child: DriverRideMap()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                InfoBox(
                  color: DesignTokens.green.withAlpha(24),
                  borderColor: DesignTokens.green.withAlpha(70),
                  spacing: 2,
                  children: [
                    Text("Trip Fare (Cash)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: DesignTokens.green,
                            fontSize: 13,
                            fontWeight: DesignTokens.fw500)),
                    Text(
                      pesoText(bookingFare(booking)),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: DesignTokens.green,
                          fontSize: 34,
                          fontWeight: DesignTokens.fw700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InfoBox(
                  spacing: 12,
                  children: [
                    _TripPoint(
                      icon: Icons.location_on_rounded,
                      color: const Color(0xFF0E8C46),
                      label: "Pickup",
                      value: bookingText(booking, "pickup_address") ?? "-",
                    ),
                    _TripPoint(
                      icon: Icons.navigation_rounded,
                      color: const Color(0xFFC94530),
                      label: "Destination",
                      value: bookingText(booking, "dropoff_address") ?? "-",
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.people_alt_rounded,
                        value: pax ?? "-",
                        label: "Passengers",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.navigation_rounded,
                        value: distance == null
                            ? "-"
                            : "${distance.toStringAsFixed(1)}km",
                        label: "Distance",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.timer_outlined,
                        value: "${remaining}s",
                        label: "To respond",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Passenger: ${bookingText(booking, "passenger_name") ?? "-"} · Payment: Cash",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DesignTokens.muted, fontSize: 12),
                ),
                if (ctrl.error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBox(message: ctrl.error!),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryActionButton(
                        label: _declining ? "Declining..." : "Decline",
                        outlined: true,
                        color: DesignTokens.muted,
                        foregroundColor: DesignTokens.text,
                        loading: _declining,
                        onPressed: busy ? null : () => _decline(ctrl),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryActionButton(
                        label: _accepting ? "Accepting..." : "Accept Ride",
                        color: DesignTokens.green,
                        loading: _accepting,
                        onPressed: busy ? null : () => _accept(ctrl),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripPoint extends StatelessWidget {
  const _TripPoint({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: DesignTokens.muted, fontSize: 11)),
              Text(value,
                  style: TextStyle(
                      color: DesignTokens.text,
                      fontSize: 14,
                      fontWeight: DesignTokens.fw500)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.bg2,
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        border: Border.all(color: DesignTokens.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: DesignTokens.driverAccent),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(value,
                style: TextStyle(
                    color: DesignTokens.text,
                    fontSize: 17,
                    fontWeight: DesignTokens.fw700)),
          ),
          Text(label,
              style: TextStyle(color: DesignTokens.muted, fontSize: 11)),
        ],
      ),
    );
  }
}
