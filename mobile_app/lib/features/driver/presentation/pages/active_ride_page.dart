import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../../core/components/index.dart";
import "../../../../core/safety/sos_delivery.dart";
import "../../../../core/safety/sos_flow.dart";
import "../../../../core/theme/design_tokens.dart";
import "../driver_home_page.dart" show shortPeso;
import "../driver_ride_controller.dart";
import "../widgets/driver_ride_actions.dart";
import "../widgets/driver_ride_map.dart";

/// The accepted ride on the full-screen map, one sheet per step: head to
/// pickup → at pickup, enter the passenger's PIN on the keypad (starts the
/// trip) → on trip, complete → collect the cash fare.
class ActiveRidePage extends StatefulWidget {
  const ActiveRidePage({super.key});

  @override
  State<ActiveRidePage> createState() => _ActiveRidePageState();
}

class _ActiveRidePageState extends State<ActiveRidePage> {
  /// Digits typed on the keypad so far.
  String _pin = "";
  int _wrongPins = 0;
  bool _pinError = false;

  /// Last known state of the ride, kept for the "Ride completed" card
  /// after the controller clears it.
  Map<String, dynamic>? _last;
  bool _completed = false;

  static const int _maxPinAttempts = 5;

  void _press(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      _pinError = false;
      if (key == "del") {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 4) {
        _pin += key;
      }
    });
  }

  Future<void> _verifyPinAndStart(DriverRideController ctrl) async {
    if (_pin.length != 4) return;
    final ok = await ctrl.startRide(_pin);
    if (!mounted) return;
    setState(() {
      _pin = "";
      if (!ok) {
        _wrongPins++;
        _pinError = true;
      }
    });
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

  Future<void> _call(String? number) async {
    if (number == null) return;
    final ok = await launchUrl(Uri(scheme: "tel", path: number));
    if (!ok && mounted) showSunToast(context, "Couldn't open the dialer.");
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    final booking = ctrl.activeBooking;
    if (booking != null) _last = booking;
    final top = MediaQuery.paddingOf(context).top;

    if (booking == null && !(_completed && _last != null)) {
      return _ended(ctrl);
    }

    final ride = booking ?? _last!;
    final status = booking == null ? "done" : booking["status"]?.toString();
    final passenger = bookingText(ride, "passenger_name") ?? "Passenger";
    final first = passenger.split(RegExp(r"\s+")).first;
    final dropoff = bookingText(ride, "dropoff_address") ?? "-";

    final (title, sub) = switch (status) {
      "accepted" => (
          "Head to pickup",
          bookingText(ride, "pickup_address") ?? ""
        ),
      "arriving" => ("At the pickup point", "Ask $first for the 4-digit PIN"),
      "ongoing" => ("On trip", "Drop off at ${dropoff.split(",").first}"),
      "done" => (
          "Ride completed",
          "Collect ${shortPeso(bookingFare(ride))} in cash"
        ),
      _ => ("Active ride", status?.replaceAll("_", " ") ?? ""),
    };

    final Widget sheet = switch (status) {
      "accepted" => _toPickup(ctrl, ride, passenger),
      "arriving" => _enterPin(ctrl, first),
      "ongoing" => _onTrip(ctrl, ride, first, dropoff),
      "done" => _done(ride, first),
      _ => _toPickup(ctrl, ride, passenger),
    };

    return Scaffold(
      backgroundColor: DesignTokens.mapLand,
      body: Stack(
        children: [
          Positioned.fill(
            child: DriverRideMap(
              fitPadding: EdgeInsets.fromLTRB(50, top + 100, 50, 470),
            ),
          ),
          Positioned(
            top: top + 6,
            left: 12,
            right: 12,
            child: FadeRise(
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.chevron_left_rounded,
                    label: "Back",
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: PrismChip(
                        title: sub.isEmpty ? title : "$title · $sub",
                        leading: const Padding(
                          padding: EdgeInsets.only(left: 9),
                          child: PulseDot(size: 9),
                        ),
                      ),
                    ),
                  ),
                  if (status != "done") ...[
                    const SizedBox(width: 8),
                    SosPill(
                      onTap: ctrl.isSendingSos
                          ? null
                          : () => confirmAndSendDriverSos(context, ctrl),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.78),
              child: SingleChildScrollView(child: sheet),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passengerCard(Map<String, dynamic> ride, String passenger,
      {String? detail}) {
    final phone = bookingText(ride, "passenger_phone");
    return PersonRow(
      name: passenger,
      tone: AvatarTone.lagoon,
      subtitle: detail ?? "Passenger",
      onCall: phone == null ? null : () => _call(phone),
    );
  }

  Widget _reportLink(DriverRideController ctrl) => Center(
        child: SunLink(
          label: "Report an issue",
          color: DesignTokens.ink2,
          onTap: () => showDriverReportDialog(context, ctrl),
        ),
      );

  // ── Head to pickup ────────────────────────────────────────────────────

  Widget _toPickup(
      DriverRideController ctrl, Map<String, dynamic> ride, String passenger) {
    final pax = bookingText(ride, "passenger_count") ?? "1";
    final pickup = bookingText(ride, "pickup_address") ?? "-";
    return MapSheet(
      label: "Head to pickup",
      children: [
        if (ctrl.sosDelivery.status != SosDeliveryStatus.idle)
          SosStatusBanner(delivery: ctrl.sosDelivery, error: ctrl.sosError),
        _passengerCard(ride, passenger,
            detail:
                "Pickup at ${pickup.split(",").first} · $pax passenger${pax == "1" ? "" : "s"}"),
        if (ctrl.error != null) ErrorBox(message: ctrl.error!),
        SunButton(
          label: ctrl.isBusy ? "Updating…" : "I've arrived at pickup",
          loading: ctrl.isBusy,
          onPressed: ctrl.markArrived,
        ),
        Row(
          children: [
            SunButton(
              label: "Cancel ride",
              tone: SunTone.danger,
              height: 40,
              expand: false,
              onPressed: ctrl.isBusy ? null : () => _cancelRide(ctrl),
            ),
            const Spacer(),
            Text("Est. ${shortPeso(bookingFare(ride))} · cash",
                style: DesignTokens.mono
                    .copyWith(color: DesignTokens.ink2, fontSize: 13)),
          ],
        ),
        _reportLink(ctrl),
      ],
    );
  }

  // ── Enter the PIN ─────────────────────────────────────────────────────

  Widget _enterPin(DriverRideController ctrl, String first) {
    final attemptsLeft = (_maxPinAttempts - _wrongPins).clamp(0, 5);
    final locked = attemptsLeft == 0;
    final message = _pinError && ctrl.error != null
        ? ctrl.error!
        : locked
            ? "No attempts left. Contact the admin."
            : "$attemptsLeft attempt${attemptsLeft == 1 ? "" : "s"} left";
    final bad = _pinError || locked;

    Widget key(String label) => Pressable(
          onTap: locked || ctrl.isBusy ? null : () => _press(label),
          semanticLabel: label == "del" ? "Delete last digit" : label,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DesignTokens.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DesignTokens.line),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border(top: BorderSide(color: DesignTokens.hi)),
            ),
            child: label == "del"
                ? Icon(Icons.backspace_outlined,
                    size: 20, color: DesignTokens.ink2)
                : Text(label,
                    style: DesignTokens.mono.copyWith(fontSize: 20)),
          ),
        );

    const rows = [
      ["1", "2", "3"],
      ["4", "5", "6"],
      ["7", "8", "9"],
      ["", "0", "del"],
    ];

    return MapSheet(
      label: "Enter pickup PIN",
      gap: 12,
      bottomPadding: 18,
      children: [
        if (ctrl.sosDelivery.status != SosDeliveryStatus.idle)
          SosStatusBanner(delivery: ctrl.sosDelivery, error: ctrl.sosError),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Overline("At pickup")),
            const SizedBox(height: 6),
            Center(
              child: Text("Ask $first for the PIN",
                  textAlign: TextAlign.center, style: DesignTokens.title),
            ),
          ],
        ),
        Semantics(
          liveRegion: true,
          label: "${_pin.length} of 4 digits entered",
          child: Center(
            child: SizedBox(
                width: 238,
                child: DigitBoxes(value: _pin, length: 4, height: 60, fontSize: 28)),
          ),
        ),
        bad
            ? Shake(
                key: ValueKey("$_wrongPins-$message"),
                child: Text(message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: DesignTokens.sosText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              )
            : Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: DesignTokens.ink2,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
        Column(
          children: [
            for (final row in rows) ...[
              Row(
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: row[i].isEmpty
                          ? const SizedBox(height: 50)
                          : key(row[i]),
                    ),
                  ],
                ],
              ),
              if (row != rows.last) const SizedBox(height: 8),
            ],
          ],
        ),
        SunButton(
          label: ctrl.isBusy ? "Checking…" : "Start trip",
          loading: ctrl.isBusy,
          onPressed: _pin.length == 4 && !locked
              ? () => _verifyPinAndStart(ctrl)
              : null,
        ),
        SunButton(
          label: "Passenger no-show",
          tone: SunTone.danger,
          height: 40,
          onPressed: ctrl.isBusy ? null : () => _noShow(ctrl),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SunLink(
              label: "Cancel ride",
              color: DesignTokens.ink2,
              onTap: ctrl.isBusy ? null : () => _cancelRide(ctrl),
            ),
            Text("  ·  ", style: TextStyle(color: DesignTokens.ink2)),
            SunLink(
              label: "Report an issue",
              color: DesignTokens.ink2,
              onTap: () => showDriverReportDialog(context, ctrl),
            ),
          ],
        ),
      ],
    );
  }

  // ── On trip ───────────────────────────────────────────────────────────

  Widget _onTrip(DriverRideController ctrl, Map<String, dynamic> ride,
      String first, String dropoff) {
    return MapSheet(
      label: "On trip",
      children: [
        if (ctrl.sosDelivery.status != SosDeliveryStatus.idle)
          SosStatusBanner(delivery: ctrl.sosDelivery, error: ctrl.sosError),
        const RideProgressBars(step: 3, labels: true),
        _passengerCard(ride, bookingText(ride, "passenger_name") ?? first,
            detail:
                "To ${dropoff.split(",").first} · ${shortPeso(bookingFare(ride))} cash"),
        if (ctrl.error != null) ErrorBox(message: ctrl.error!),
        SunButton(
          label: ctrl.isBusy ? "Completing…" : "Complete ride",
          loading: ctrl.isBusy,
          onPressed: () => _complete(ctrl),
        ),
        _reportLink(ctrl),
      ],
    );
  }

  // ── Completed ─────────────────────────────────────────────────────────

  Widget _done(Map<String, dynamic> ride, String first) {
    final distance = double.tryParse(ride["distance_km"]?.toString() ?? "");
    final started = DateTime.tryParse(ride["started_at"]?.toString() ?? "");
    final minutes = started == null
        ? null
        : DateTime.now().difference(started.toLocal()).inMinutes.clamp(1, 999);
    final inset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + inset),
      child: FadeRise(
        offset: 40,
        child: PrismGlass(
          strong: true,
          spin: true,
          radius: DesignTokens.radiusSheet,
          shadows: DesignTokens.shadowSheet,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: DesignTokens.lineStrong,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 6),
              const StatusRing(icon: Icons.check_rounded),
              const Overline("Collect in cash"),
              const SizedBox(height: 6),
              Text(pesoText(bookingFare(ride)),
                  style: TextStyle(
                      color: DesignTokens.ink,
                      fontSize: 46,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2.3,
                      fontFeatures: DesignTokens.tabular)),
              const SizedBox(height: 6),
              Text(
                  [
                    bookingText(ride, "passenger_name") ?? first,
                    (bookingText(ride, "dropoff_address") ?? "")
                        .split(",")
                        .first,
                  ].where((p) => p.isNotEmpty).join(" · "),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DesignTokens.ink2, fontSize: 13.5)),
              const SizedBox(height: 14),
              MetaStats(items: [
                (
                  distance == null ? "—" : "${distance.toStringAsFixed(1)} km",
                  "Distance"
                ),
                (minutes == null ? "—" : "$minutes min", "Time"),
                (bookingText(ride, "passenger_count") ?? "1", "Passengers"),
              ]),
              const SizedBox(height: 16),
              SunButton(
                label: "Back to Drive",
                onPressed: () {
                  showSunToast(context,
                      "${shortPeso(bookingFare(ride))} added to today");
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// No active ride any more (cancelled by the passenger, or opened late).
  Widget _ended(DriverRideController ctrl) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmptyState(
                  icon: Icons.close_rounded,
                  message: ctrl.error ?? "No active ride.",
                ),
                SunButton(
                  label: "Back to requests",
                  tone: SunTone.ink,
                  height: 52,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
