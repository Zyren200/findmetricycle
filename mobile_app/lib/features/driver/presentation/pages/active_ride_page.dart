import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/theme/design_tokens.dart";
import "../driver_ride_controller.dart";
import "../widgets/driver_ride_actions.dart";
import "../widgets/driver_ride_map.dart";

/// The accepted ride, step by step: head to pickup → arrived → verify the
/// passenger's PIN (starts the trip) → complete → collect the cash fare.
class ActiveRidePage extends StatefulWidget {
  const ActiveRidePage({super.key});

  @override
  State<ActiveRidePage> createState() => _ActiveRidePageState();
}

class _ActiveRidePageState extends State<ActiveRidePage> {
  final _pinController = TextEditingController();

  /// Last known state of the ride, kept for the "Trip Done" screen after
  /// the controller clears it.
  Map<String, dynamic>? _last;
  bool _completed = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPinAndStart(DriverRideController ctrl) async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) return;
    final ok = await ctrl.startRide(pin);
    if (!mounted) return;
    if (ok) _pinController.clear();
  }

  Future<void> _complete(DriverRideController ctrl) async {
    await ctrl.completeRide();
    if (!mounted) return;
    if (ctrl.activeBooking == null && ctrl.error == null) {
      setState(() => _completed = true);
    }
  }

  Future<void> _noShow(DriverRideController ctrl) async {
    final ok = await confirmAndMarkNoShow(context, ctrl);
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _cancelRide(DriverRideController ctrl) async {
    final ok = await confirmAndCancelRide(context, ctrl);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    final booking = ctrl.activeBooking;
    if (booking != null) _last = booking;

    if (booking == null) {
      final last = _last;
      if (_completed && last != null) return _tripDone(last);
      return _ended(ctrl);
    }

    final status = booking["status"]?.toString() ?? "";
    final (statusLabel, statusColor) = switch (status) {
      "accepted" => ("Ride accepted — Head to pickup", DesignTokens.blue),
      "arriving" => ("Arrived — Ask for PIN", DesignTokens.warning),
      "ongoing" => (
          "Ride in progress — Head to destination",
          DesignTokens.blue
        ),
      _ => (status.replaceAll("_", " "), DesignTokens.muted),
    };

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          AppTopBar(
            title: "Active Ride",
            showBack: true,
            badge: status.toUpperCase(),
            badgeColor: DesignTokens.driverAccent,
            trailing: TextButton(
              onPressed: ctrl.isSendingSos
                  ? null
                  : () => confirmAndSendDriverSos(context, ctrl),
              child: Text("SOS",
                  style: TextStyle(
                      color: DesignTokens.red, fontWeight: DesignTokens.fw700)),
            ),
          ),
          const SizedBox(height: 200, child: DriverRideMap()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StatusBanner(label: statusLabel, color: statusColor),
                const SizedBox(height: 16),
                InfoBox(
                  spacing: 8,
                  children: [
                    InfoRow(
                        label: "Passenger:",
                        value: bookingText(booking, "passenger_name") ?? "-"),
                    InfoRow(
                        label: "Pickup:",
                        value: bookingText(booking, "pickup_address") ?? "-"),
                    InfoRow(
                        label: "Destination:",
                        value: bookingText(booking, "dropoff_address") ?? "-"),
                    if (bookingText(booking, "passenger_count") != null)
                      InfoRow(
                          label: "Passengers:",
                          value: bookingText(booking, "passenger_count")!),
                    InfoRow(
                        label: "Fare:",
                        value: "${pesoText(bookingFare(booking))} Cash"),
                  ],
                ),
                if (ctrl.error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBox(message: ctrl.error!),
                ],
                const SizedBox(height: 16),
                if (status == "accepted")
                  PrimaryActionButton(
                    label:
                        ctrl.isBusy ? "Updating..." : "I've Arrived at Pickup",
                    icon: Icons.location_on_rounded,
                    color: DesignTokens.driverAccent,
                    loading: ctrl.isBusy,
                    onPressed: ctrl.markArrived,
                  ),
                if (status == "arriving") ...[
                  _PinEntry(
                    controller: _pinController,
                    busy: ctrl.isBusy,
                    onSubmit: () => _verifyPinAndStart(ctrl),
                  ),
                  const SizedBox(height: 12),
                  PrimaryActionButton(
                    label: "Passenger No-Show",
                    outlined: true,
                    color: DesignTokens.warning,
                    onPressed: ctrl.isBusy ? null : () => _noShow(ctrl),
                  ),
                ],
                if (status == "ongoing")
                  PrimaryActionButton(
                    label: ctrl.isBusy ? "Completing..." : "Complete Ride",
                    icon: Icons.flag_rounded,
                    color: DesignTokens.green,
                    loading: ctrl.isBusy,
                    onPressed: () => _complete(ctrl),
                  ),
                if (status == "accepted" || status == "arriving") ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: ctrl.isBusy ? null : () => _cancelRide(ctrl),
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: DesignTokens.red),
                    label: Text("Cancel Ride",
                        style: TextStyle(color: DesignTokens.red)),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => showDriverReportDialog(context, ctrl),
                  icon: Icon(Icons.flag_outlined,
                      size: 18, color: DesignTokens.muted),
                  label: Text("Report an Issue",
                      style: TextStyle(color: DesignTokens.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripDone(Map<String, dynamic> ride) {
    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          const AppTopBar(title: "Ride Completed"),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 64, color: DesignTokens.green),
                const SizedBox(height: 16),
                Text("Trip Done!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: DesignTokens.text,
                        fontSize: 20,
                        fontWeight: DesignTokens.fw700)),
                const SizedBox(height: 4),
                Text("Collect from passenger:",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DesignTokens.muted)),
                const SizedBox(height: 6),
                Text(
                  pesoText(bookingFare(ride)),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: DesignTokens.green,
                      fontSize: 34,
                      fontWeight: DesignTokens.fw700),
                ),
                const SizedBox(height: 24),
                InfoBox(
                  spacing: 8,
                  children: [
                    InfoRow(
                        label: "Pickup:",
                        value: bookingText(ride, "pickup_address") ?? "-"),
                    InfoRow(
                        label: "Destination:",
                        value: bookingText(ride, "dropoff_address") ?? "-"),
                    if (bookingText(ride, "passenger_count") != null)
                      InfoRow(
                          label: "Passengers:",
                          value: bookingText(ride, "passenger_count")!),
                    const InfoRow(label: "Payment:", value: "Cash"),
                  ],
                ),
                const SizedBox(height: 24),
                PrimaryActionButton(
                  label: "Done — Back to Home",
                  color: DesignTokens.driverAccent,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// No active ride any more (cancelled by the passenger, or opened late).
  Widget _ended(DriverRideController ctrl) {
    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close_rounded, size: 56, color: DesignTokens.muted),
                const SizedBox(height: 12),
                Text(
                  ctrl.error ?? "No active ride.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DesignTokens.muted),
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
}

/// Inline 4-digit PIN entry; the backend verifies it when starting the
/// ride (a wrong or locked PIN comes back as an error).
class _PinEntry extends StatefulWidget {
  const _PinEntry(
      {required this.controller, required this.busy, required this.onSubmit});

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  State<_PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<_PinEntry> {
  @override
  Widget build(BuildContext context) {
    final complete = widget.controller.text.trim().length == 4;
    return InfoBox(
      color: DesignTokens.blue.withAlpha(20),
      borderColor: DesignTokens.blue.withAlpha(70),
      children: [
        Row(
          children: [
            Icon(Icons.keyboard_rounded, size: 18, color: DesignTokens.blue),
            const SizedBox(width: 8),
            Text("Enter Passenger PIN",
                style: TextStyle(
                    color: DesignTokens.blue, fontWeight: DesignTokens.fw600)),
          ],
        ),
        Text(
          "Ask the passenger for their 4-digit PIN to verify pickup.",
          style: TextStyle(color: DesignTokens.blue, fontSize: 12),
        ),
        TextField(
          controller: widget.controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (complete) widget.onSubmit();
          },
          style: TextStyle(
            color: DesignTokens.text,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 12,
          ),
          decoration: InputDecoration(
            counterText: "",
            hintText: "_ _ _ _",
            filled: true,
            fillColor: DesignTokens.bg3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              borderSide:
                  BorderSide(color: DesignTokens.blue.withAlpha(120), width: 2),
            ),
          ),
        ),
        PrimaryActionButton(
          label: widget.busy ? "Verifying..." : "Verify PIN & Start Ride",
          icon: Icons.play_circle_outline_rounded,
          color: DesignTokens.blue,
          loading: widget.busy,
          onPressed: complete ? widget.onSubmit : null,
        ),
      ],
    );
  }
}
