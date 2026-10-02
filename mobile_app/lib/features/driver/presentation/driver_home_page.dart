import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/network/socket_client.dart";
import "../../../core/theme/design_tokens.dart";
import "../../shared/presentation/notifications_screen.dart";
import "../../shared/state/notifications_controller.dart";
import "../../shared/state/session_store.dart";
import "driver_ride_controller.dart";
import "pages/active_ride_page.dart";
import "pages/ride_request_page.dart";
import "widgets/driver_ride_actions.dart";

/// Home tab of Driver Mode: who's driving, the Online switch, device
/// status, the active ride or an incoming request, and today's earnings.
/// Reads the DriverRideController provided once by DriverShellPage.
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

  @override
  void initState() {
    super.initState();
    // Keeps the request countdown on the home card moving.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _rideController?.incomingBooking != null) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = context.read<DriverRideController>();
    if (_rideController != ctrl) {
      _rideController?.removeListener(_checkApprovalRevoked);
      _rideController = ctrl..addListener(_checkApprovalRevoked);
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
    _rideController?.removeListener(_checkApprovalRevoked);
    super.dispose();
  }

  // Admin revoked this rider's approval: re-read the account's driver
  // access, which switches the app back to passenger mode.
  void _checkApprovalRevoked() {
    final status = _rideController?.approvalStatus;
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

    final name =
        bookingText(profile, "full_name") ?? session?.fullName ?? "Driver";
    final rating = double.tryParse(summary["rating_avg"]?.toString() ?? "");
    final tricycle = bookingText(profile, "tricycle_number");
    final today = summary["today"] is Map ? summary["today"] as Map : const {};
    final week = summary["week"] is Map ? summary["week"] as Map : const {};

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          ctrl.refreshEarnings(),
          ctrl.refreshProfile(),
        ]),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // Header
            Container(
              color: DesignTokens.bg2,
              padding: EdgeInsets.fromLTRB(
                  16, MediaQuery.paddingOf(context).top + 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Driver Mode",
                                style: TextStyle(
                                    color: DesignTokens.muted, fontSize: 12)),
                            Text(name,
                                style: TextStyle(
                                    color: DesignTokens.text,
                                    fontSize: 18,
                                    fontWeight: DesignTokens.fw700)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 14, color: Colors.amber),
                                const SizedBox(width: 3),
                                Text(
                                    rating == null
                                        ? "—"
                                        : rating.toStringAsFixed(2),
                                    style: TextStyle(
                                        color: DesignTokens.text,
                                        fontSize: 13)),
                                const SizedBox(width: 4),
                                Text("(${ctrl.ratings.length} ratings)",
                                    style: TextStyle(
                                        color: DesignTokens.muted,
                                        fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          NotificationBell(
                            controller: context.read<NotificationsController>(),
                            onPressed: _openNotifications,
                          ),
                          if (tricycle != null) ...[
                            Text("Tricycle",
                                style: TextStyle(
                                    color: DesignTokens.muted, fontSize: 11)),
                            Text(tricycle,
                                style: TextStyle(
                                    color: DesignTokens.text,
                                    fontSize: 13,
                                    fontWeight: DesignTokens.fw500)),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PrimaryActionButton(
                    label: ctrl.isBusy
                        ? "Updating..."
                        : ctrl.isOnline
                            ? "GO OFFLINE"
                            : "GO ONLINE",
                    icon: Icons.power_settings_new_rounded,
                    color:
                        ctrl.isOnline ? DesignTokens.red : DesignTokens.green,
                    foregroundColor: Colors.white,
                    loading: ctrl.isBusy,
                    onPressed: ctrl.activeBooking != null
                        ? null
                        : () => ctrl.setOnline(!ctrl.isOnline),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ctrl.isOnline
                        ? "● Online — Waiting for ride requests..."
                        : "○ Offline — Go online to receive rides",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ctrl.isOnline
                          ? DesignTokens.green
                          : DesignTokens.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatusPill(label: "GPS", ok: ctrl.gpsEnabled),
                      _StatusPill(label: "Internet", ok: ctrl.hasInternet),
                      _StatusPill(label: "Location Sharing", ok: ctrl.isOnline),
                    ],
                  ),
                ],
              ),
            ),

            if (ctrl.approvalMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _Banner(
                  title: switch (ctrl.approvalStatus) {
                    "approved" => "You're approved!",
                    "rejected" => "Application not approved",
                    "needs_correction" => "Documents need correction",
                    _ => "Driver Account",
                  },
                  message: ctrl.approvalMessage!,
                  color: switch (ctrl.approvalStatus) {
                    "approved" => DesignTokens.green,
                    "rejected" => DesignTokens.red,
                    _ => DesignTokens.driverAccent,
                  },
                  onClose: ctrl.dismissApprovalMessage,
                ),
              ),
            if (ctrl.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ErrorBox(message: ctrl.error!),
              ),

            // Active ride
            if (ctrl.activeBooking != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _ActiveRideBanner(
                  booking: ctrl.activeBooking!,
                  onView: () => pushDriverPage(context, const ActiveRidePage()),
                ),
              )
            // Incoming request
            else if (ctrl.incomingBooking != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _IncomingRequestCard(
                  booking: ctrl.incomingBooking!,
                  busy: ctrl.isBusy,
                  onDecline: ctrl.declineIncomingBooking,
                  onView: () =>
                      openRideRequestPage(context, const RideRequestPage()),
                ),
              ),

            // Earnings summary
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel("Earnings Summary"),
                  Row(
                    children: [
                      Expanded(
                        child: _EarningCard(
                          label: "Today",
                          amount: today["earnings"],
                          rides: today["rides"],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _EarningCard(
                          label: "This Week",
                          amount: week["earnings"],
                          rides: week["rides"],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? DesignTokens.green : DesignTokens.red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color, size: 14),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DesignTokens.muted)),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.title,
    required this.message,
    required this.color,
    this.onClose,
  });

  final String title;
  final String message;
  final Color color;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color, fontWeight: DesignTokens.fw700)),
                const SizedBox(height: 4),
                Text(message,
                    style: TextStyle(color: DesignTokens.text, fontSize: 13)),
              ],
            ),
          ),
          if (onClose != null)
            InkWell(
              onTap: onClose,
              child: Icon(Icons.close_rounded,
                  size: 18, color: DesignTokens.muted),
            ),
        ],
      ),
    );
  }
}

class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner({required this.booking, required this.onView});

  final Map<String, dynamic> booking;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final muted = DesignTokens.bg.withAlpha(190);
    final status = booking["status"]?.toString() ?? "";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.driverAccent,
        borderRadius: BorderRadius.circular(DesignTokens.radius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Active Ride",
                    style: TextStyle(color: muted, fontSize: 12)),
                Text(status.replaceAll("_", " ").toUpperCase(),
                    style: TextStyle(
                        color: DesignTokens.bg,
                        fontWeight: DesignTokens.fw600)),
                Text(bookingText(booking, "dropoff_address") ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onView,
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.bg,
              foregroundColor: DesignTokens.driverAccent,
              minimumSize: const Size(0, 40),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
            ),
            child: const Text("View",
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _IncomingRequestCard extends StatelessWidget {
  const _IncomingRequestCard({
    required this.booking,
    required this.busy,
    required this.onDecline,
    required this.onView,
  });

  final Map<String, dynamic> booking;
  final bool busy;
  final VoidCallback onDecline;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final remaining = offerSecondsLeft(booking);
    final pax = bookingText(booking, "passenger_count");
    final distance = double.tryParse(booking["distance_km"]?.toString() ?? "");
    final amber = DesignTokens.driverAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: amber.withAlpha(24),
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        border: Border.all(color: amber.withAlpha(110)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("New Ride Request!",
                    style: TextStyle(
                        color: amber, fontWeight: DesignTokens.fw700)),
              ),
              Text(
                "${remaining}s",
                style: TextStyle(
                  color: remaining <= 10 ? DesignTokens.red : amber,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 14, color: Color(0xFF0E8C46)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(bookingText(booking, "pickup_address") ?? "-",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: DesignTokens.text, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.navigation_rounded,
                  size: 14, color: Color(0xFFC94530)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(bookingText(booking, "dropoff_address") ?? "-",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: DesignTokens.text, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            children: [
              if (pax != null)
                Text("$pax pax",
                    style: TextStyle(color: DesignTokens.muted, fontSize: 12)),
              if (distance != null)
                Text("${distance.toStringAsFixed(1)} km",
                    style: TextStyle(color: DesignTokens.muted, fontSize: 12)),
              Text("${pesoText(bookingFare(booking))} Cash",
                  style: TextStyle(
                      color: DesignTokens.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    side: BorderSide(color: DesignTokens.border2),
                  ),
                  child: Text("Decline",
                      style: TextStyle(color: DesignTokens.text)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onView,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    backgroundColor: DesignTokens.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("View & Accept",
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarningCard extends StatelessWidget {
  const _EarningCard(
      {required this.label, required this.amount, required this.rides});

  final String label;
  final dynamic amount;
  final dynamic rides;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: DesignTokens.muted, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(pesoText(amount),
                style: TextStyle(
                    color: DesignTokens.text,
                    fontSize: 20,
                    fontWeight: DesignTokens.fw700)),
          ),
          Text("${int.tryParse(rides?.toString() ?? "") ?? 0} rides",
              style: TextStyle(color: DesignTokens.muted, fontSize: 12)),
        ],
      ),
    );
  }
}
