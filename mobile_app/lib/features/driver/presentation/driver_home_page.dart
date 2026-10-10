import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/network/socket_client.dart";
import "../../../core/theme/design_tokens.dart";
import "../../../core/utils/ride_format.dart";
import "../../shared/presentation/notifications_screen.dart";
import "../../shared/state/notifications_controller.dart";
import "../../shared/state/session_store.dart";
import "driver_ride_controller.dart";
import "driver_shell_page.dart";
import "pages/active_ride_page.dart";
import "pages/ride_request_page.dart";
import "widgets/driver_ride_actions.dart";
import "widgets/driver_ride_map.dart";

/// Drive tab: the rider's map with who's driving, today's earnings and the
/// device status on top, and the Go online / You're online sheet (or the
/// active ride, or a pending request) at the bottom.
class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  DriverRideController? _rideController;
  StreamSubscription? _paymentSub;
  Timer? _tick;
  bool _handledRevocation = false;
  bool? _wasOnline;

  @override
  void initState() {
    super.initState();
    // Keeps the request countdown on the sheet moving.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _rideController?.incomingBooking != null) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = context.read<DriverRideController>();
    if (_rideController != ctrl) {
      _rideController?.removeListener(_onControllerChanged);
      _rideController = ctrl..addListener(_onControllerChanged);
    }

    final messenger = ScaffoldMessenger.of(context);
    _paymentSub ??= context
        .read<SocketClient>()
        .on("driver:payment_received")
        .listen((event) {
      final data = event is Map ? Map<String, dynamic>.from(event) : {};
      final payment = data["payment"] as Map<String, dynamic>?;
      final label = payment != null
          ? (payment["receiptNumber"] ?? payment["id"] ?? "payment")
          : "payment";
      if (mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text("Payment received: $label")));
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _paymentSub?.cancel();
    _rideController?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final ctrl = _rideController;
    if (ctrl == null) return;

    // "You're online" toast when the switch actually flips on.
    if (_wasOnline == false && ctrl.isOnline && mounted) {
      showSunToast(context, "You're online");
    }
    _wasOnline = ctrl.isOnline;

    // Admin revoked this rider's approval: re-read the account's driver
    // access, which switches the app back to passenger mode.
    final status = ctrl.approvalStatus;
    if (_handledRevocation ||
        (status != "needs_correction" && status != "rejected")) {
      return;
    }
    _handledRevocation = true;
    context.read<SessionStore>().refreshDriverAccess();
  }

  void _openNotifications() {
    final notifications = context.read<NotificationsController>();
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => NotificationsScreen(controller: notifications)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    final session = context.watch<SessionStore>().session;
    final profile = ctrl.driverProfile ?? {};
    final summary = ctrl.earningsSummary ?? {};
    final top = MediaQuery.paddingOf(context).top;

    final name =
        bookingText(profile, "full_name") ?? session?.fullName ?? "Driver";
    final today = summary["today"] is Map ? summary["today"] as Map : const {};
    final online = ctrl.isOnline;

    return Scaffold(
      backgroundColor: DesignTokens.mapLand,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DriverRideMap(
              fitPadding: EdgeInsets.fromLTRB(60, 180, 60, 420),
            ),
          ),
          // Offline: the map fades back.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: online || ctrl.activeBooking != null ? 0 : 1,
                child:
                    ColoredBox(color: DesignTokens.background.withAlpha(110)),
              ),
            ),
          ),

          // Who's driving, today's earnings, alerts
          Positioned(
            top: top + 6,
            left: 12,
            right: 12,
            child: FadeRise(
              child: Row(
                children: [
                  Flexible(
                    child: Pressable(
                      onTap: () => context.read<ValueNotifier<int>>().value =
                          kEarningsTab,
                      semanticLabel: "Today's earnings",
                      child: PrismChip(
                        leading: ToneAvatar(name: name, size: 34, circle: true),
                        overline: "Today",
                        title:
                            "${shortName(name)} · ${shortPeso(today["earnings"])}",
                      ),
                    ),
                  ),
                  const Spacer(),
                  NotificationBell(
                    controller: context.read<NotificationsController>(),
                    onPressed: _openNotifications,
                  ),
                ],
              ),
            ),
          ),

          // Device status
          Positioned(
            top: top + 62,
            left: 12,
            right: 12,
            child: FadeRise(
              delay: const Duration(milliseconds: 150),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusPill(
                      icon: Icons.gps_fixed_rounded,
                      label: "GPS",
                      ok: ctrl.gpsEnabled),
                  _StatusPill(
                      icon: Icons.wifi_rounded,
                      label: "Internet",
                      ok: ctrl.hasInternet),
                  _StatusPill(
                    icon: Icons.share_location_rounded,
                    label: "Location sharing",
                    ok: online,
                    neutralWhenOff: true,
                  ),
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.66),
              child: SingleChildScrollView(child: _sheet(ctrl, today)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheet(DriverRideController ctrl, Map today) {
    final notices = <Widget>[
      if (ctrl.approvalMessage != null)
        _Banner(
          title: switch (ctrl.approvalStatus) {
            "approved" => "You're approved!",
            "rejected" => "Application not approved",
            "needs_correction" => "Documents need correction",
            _ => "Driver Account",
          },
          message: ctrl.approvalMessage!,
          good: ctrl.approvalStatus == "approved",
          onClose: ctrl.dismissApprovalMessage,
        ),
      if (ctrl.error != null) ErrorBox(message: ctrl.error!),
    ];

    // Active ride
    final active = ctrl.activeBooking;
    if (active != null) {
      final status = active["status"]?.toString() ?? "";
      return MapSheet(
        overTabs: true,
        label: "Active ride",
        children: [
          ...notices,
          Row(
            children: [
              const PulseDot(size: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  switch (status) {
                    "accepted" => "Head to pickup",
                    "arriving" => "At the pickup point",
                    "ongoing" => "On trip",
                    _ => "Active ride",
                  },
                  style: DesignTokens.title,
                ),
              ),
            ],
          ),
          RoutePoints(
            pickup: bookingText(active, "pickup_address") ?? "-",
            dropoff: bookingText(active, "dropoff_address") ?? "-",
            pickupNote: bookingText(active, "passenger_name"),
          ),
          SunButton(
            label: "Open ride",
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: () => pushDriverPage(context, const ActiveRidePage()),
          ),
        ],
      );
    }

    // A request is waiting
    final incoming = ctrl.incomingBooking;
    if (incoming != null) {
      final left = offerSecondsLeft(incoming);
      return MapSheet(
        overTabs: true,
        label: "New ride request",
        children: [
          ...notices,
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Overline("New ride request",
                        color: DesignTokens.primaryText),
                    const SizedBox(height: 2),
                    Text(
                        "${shortPeso(bookingFare(incoming))} · ${bookingText(incoming, "passenger_count") ?? "1"} passenger",
                        style: DesignTokens.title),
                  ],
                ),
              ),
              StatusChip("${left}s",
                  tone: left <= 10 ? ChipTone.sos : ChipTone.primary),
            ],
          ),
          RoutePoints(
            pickup: bookingText(incoming, "pickup_address") ?? "-",
            dropoff: bookingText(incoming, "dropoff_address") ?? "-",
          ),
          Row(
            children: [
              Expanded(
                child: SunButton(
                  label: "Decline",
                  tone: SunTone.quiet,
                  onPressed: ctrl.isBusy ? null : ctrl.declineIncomingBooking,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SunButton(
                  label: "View & accept",
                  onPressed: ctrl.isBusy
                      ? null
                      : () =>
                          openRideRequestPage(context, const RideRequestPage()),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Online
    if (ctrl.isOnline) {
      final rating = double.tryParse(
          ctrl.earningsSummary?["rating_avg"]?.toString() ?? "");
      return MapSheet(
        overTabs: true,
        label: "Online",
        children: [
          ...notices,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _OnlineDot(),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text("You're online", style: DesignTokens.title)),
                  Text("Waiting for requests",
                      style: TextStyle(
                          color: DesignTokens.ink2, fontSize: 13.5)),
                ],
              ),
              const SizedBox(height: 6),
              Text("Requests still arrive with your screen locked.",
                  style: TextStyle(color: DesignTokens.ink2, fontSize: 13)),
            ],
          ),
          Row(
            children: [
              Expanded(
                  child: _Stat(
                      label: "Earnings", value: shortPeso(today["earnings"]))),
              const SizedBox(width: 8),
              Expanded(
                  child: _Stat(
                      label: "Trips",
                      value:
                          "${int.tryParse(today["rides"]?.toString() ?? "") ?? 0}")),
              const SizedBox(width: 8),
              Expanded(
                  child: _Stat(
                      label: "Rating",
                      value: rating == null || rating == 0
                          ? "—"
                          : rating.toStringAsFixed(1))),
            ],
          ),
          SunButton(
            label: ctrl.isBusy ? "Updating…" : "Go offline",
            tone: SunTone.quiet,
            loading: ctrl.isBusy,
            onPressed: () => ctrl.setOnline(false),
          ),
        ],
      );
    }

    // Offline
    return MapSheet(
      overTabs: true,
      label: "Go online",
      children: [
        ...notices,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("You're offline", style: DesignTokens.title),
            const SizedBox(height: 4),
            Text("Go online to get ride requests in Guiuan.",
                style: TextStyle(color: DesignTokens.ink2, fontSize: 13.5)),
          ],
        ),
        Column(
          children: [
            _Check(label: "GPS is on", ok: ctrl.gpsEnabled),
            _Check(
                label: "Location permission allowed",
                ok: ctrl.locationPermissionGranted),
            _Check(label: "Connected to the internet", ok: ctrl.hasInternet),
          ],
        ),
        SunButton(
          label: ctrl.isBusy ? "Going online…" : "Go online",
          tone: SunTone.lagoon,
          loading: ctrl.isBusy,
          onPressed: () => ctrl.setOnline(true),
        ),
      ],
    );
  }
}

/// "Ramon D." of "Ramon Dela Cruz" — fits the glass pill.
String shortName(String name) {
  final parts = name.trim().split(RegExp(r"\s+"));
  if (parts.length < 2) return name.trim();
  return "${parts.first} ${parts.last[0].toUpperCase()}.";
}

/// "₱420" — whole pesos for the compact chips.
String shortPeso(dynamic amount) {
  final value = double.tryParse(amount?.toString() ?? "") ?? 0;
  return value == value.roundToDouble()
      ? "₱${groupThousands(value.toStringAsFixed(0))}"
      : peso(value);
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(
      {required this.icon,
      required this.label,
      required this.ok,
      this.neutralWhenOff = false});

  final IconData icon;
  final String label;
  final bool ok;
  final bool neutralWhenOff;

  @override
  Widget build(BuildContext context) {
    final tint = ok
        ? DesignTokens.ok
        : neutralWhenOff
            ? DesignTokens.ink2
            : DesignTokens.danger;
    return Semantics(
      label: "$label ${ok ? "OK" : "off"}",
      excludeSemantics: true,
      child: Glass(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: tint),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: DesignTokens.ink1,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// A green dot with a ping ring (".onl").
class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          HaloRing(
              size: 12,
              color: DesignTokens.ok,
              from: 1,
              to: 1.9,
              period: const Duration(milliseconds: 2000)),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: DesignTokens.ok,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: DesignTokens.ok, blurRadius: 12)],
            ),
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: ok ? DesignTokens.ok : DesignTokens.danger,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: ok ? DesignTokens.glowOk : DesignTokens.glowDanger,
                    blurRadius: 10),
              ],
            ),
            child: Icon(ok ? Icons.check_rounded : Icons.close_rounded,
                size: 12, color: ok ? DesignTokens.onOk : Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(color: DesignTokens.ink1, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DesignTokens.line),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                    color: DesignTokens.ink,
                    fontSize: 18,
                    height: 1.2,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: DesignTokens.tabular)),
          ),
          Text(label,
              style: TextStyle(color: DesignTokens.ink2, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.title,
    required this.message,
    required this.good,
    this.onClose,
  });

  final String title;
  final String message;
  final bool good;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return PrismAlert(
      tone: good ? DesignTokens.ok : DesignTokens.warn,
      title: title,
      message: message,
      trailing: onClose == null
          ? null
          : Pressable(
              onTap: onClose,
              semanticLabel: "Dismiss",
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.close_rounded,
                    size: 18, color: DesignTokens.ink2),
              ),
            ),
    );
  }
}
