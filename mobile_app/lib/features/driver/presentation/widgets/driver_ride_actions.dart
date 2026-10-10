import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/safety/sos_flow.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../../core/utils/ride_format.dart";
import "../../../shared/presentation/report_issue_sheet.dart";
import "../../../shared/state/notifications_controller.dart";
import "../driver_ride_controller.dart";

// Navigation, dialogs and small helpers shared by the Driver Mode pages.

/// Pushes a full-screen driver page (ride request, active ride, ...).
///
/// A pushed route isn't a descendant of DriverShellPage's providers, so the
/// shell-scoped controllers are handed over by value.
Future<T?> pushDriverPage<T>(BuildContext context, Widget page,
    {bool replace = false}) {
  final route = MaterialPageRoute<T>(
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
            value: context.read<DriverRideController>()),
        ChangeNotifierProvider.value(
            value: context.read<NotificationsController>()),
        ChangeNotifierProvider.value(value: context.read<ValueNotifier<int>>()),
      ],
      child: page,
    ),
  );
  final navigator = Navigator.of(context);
  return replace ? navigator.pushReplacement(route) : navigator.push(route);
}

bool _rideRequestOpen = false;

/// Opens the Ride Request screen unless it's already showing — used both
/// when a request arrives (DriverShellPage) and from the Drive sheet.
Future<void> openRideRequestPage(BuildContext context, Widget page) async {
  if (_rideRequestOpen) return;
  _rideRequestOpen = true;
  try {
    await pushDriverPage<void>(context, page);
  } finally {
    _rideRequestOpen = false;
  }
}

String? bookingText(Map<String, dynamic>? booking, String key) {
  final value = booking?[key]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

String pesoText(dynamic amount) {
  final value = double.tryParse(amount?.toString() ?? "") ?? 0;
  return peso(value);
}

/// The fare shown for a booking: final if set, else the estimate.
dynamic bookingFare(Map<String, dynamic>? booking) =>
    booking?["final_fare"] ?? booking?["estimated_fare"];

/// Seconds left on an incoming offer (20 when the server sent no expiry).
int offerSecondsLeft(Map<String, dynamic>? booking) {
  final raw = booking?["offer_expires_at"]?.toString();
  final expiresAt = raw == null ? null : DateTime.tryParse(raw);
  if (expiresAt == null) return 20;
  final remaining =
      expiresAt.toUtc().difference(DateTime.now().toUtc()).inSeconds;
  return remaining.clamp(0, 999);
}

/// Confirms, then sends an SOS alert with the rider's location and active
/// ride and opens the dialer with the emergency number; [SosStatusBanner]
/// shows how the alert is doing.
Future<void> confirmAndSendDriverSos(
    BuildContext context, DriverRideController controller) {
  return confirmSosAndDial(
    context,
    confirmMessage:
        "We'll alert the FindMeTricycle admin with your location and this ride.",
    startDelivery: controller.startSos,
    delivery: controller.sosDelivery,
    updates: controller,
  );
}

Future<bool> confirmAndMarkNoShow(
    BuildContext context, DriverRideController controller) async {
  final confirmed = await confirmSun(
    context,
    title: "Passenger didn't show up?",
    message:
        "This ends the trip and files a report for admin review. Only use this if you've waited at the pickup point and the passenger hasn't shown up.",
    confirmLabel: "Confirm no-show",
    icon: Icons.person_off_outlined,
  );
  if (!confirmed || !context.mounted) return false;

  final success = await controller.markNoShow();
  if (!context.mounted) return success;
  showSunToast(
    context,
    success
        ? "Marked as no-show. A report was sent to the admin."
        : (controller.error ?? "Failed to report no-show."),
  );
  return success;
}

const List<String> _cancelReasons = [
  "Tricycle problem",
  "Emergency",
  "Passenger asked me to cancel",
  "Can't reach the pickup point",
  "Other",
];

/// Backing out before the trip starts. The passenger keeps the booking and
/// picks another rider, so the reason is shown to them.
Future<bool> confirmAndCancelRide(
    BuildContext context, DriverRideController controller) async {
  final reason = await showSunSheet<String>(
    context,
    builder: (_) => const _CancelRideCard(),
  );
  if (reason == null || !context.mounted) return false;

  final success = await controller.cancelActiveRide(reason: reason);
  if (!context.mounted) return success;
  showSunToast(
    context,
    success
        ? "Ride cancelled. The passenger can choose another rider."
        : (controller.error ?? "Failed to cancel ride."),
  );
  return success;
}

class _CancelRideCard extends StatefulWidget {
  const _CancelRideCard();

  @override
  State<_CancelRideCard> createState() => _CancelRideCardState();
}

class _CancelRideCardState extends State<_CancelRideCard> {
  String _reason = _cancelReasons.first;

  @override
  Widget build(BuildContext context) {
    return SunSheetCard(
      title: "Cancel this ride?",
      message:
          "The passenger will be asked to choose another rider. Only cancel if you really can't make the trip.",
      icon: Icons.close_rounded,
      iconBg: DesignTokens.sosSoft,
      iconFg: DesignTokens.sosText,
      content: [
        ChoiceList(
          options: [for (final r in _cancelReasons) (r, r)],
          value: _reason,
          onChanged: (r) => setState(() => _reason = r),
        ),
      ],
      actions: [
        SunButton(
          label: "Cancel ride",
          tone: SunTone.sos,
          onPressed: () => Navigator.pop(context, _reason),
        ),
        SunButton(
          label: "Keep ride",
          tone: SunTone.quiet,
          height: 48,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

/// "Report an issue": goes to the admin's Complaints inbox, tied to the
/// ride in progress when there is one.
Future<void> showDriverReportDialog(
    BuildContext context, DriverRideController controller) async {
  final rideId = controller.activeBooking?["id"];
  final report = await showReportIssueSheet(
    context,
    categories: kDriverReportCategories,
    about: rideId == null ? null : "About your current ride (#$rideId).",
  );
  if (report == null || !context.mounted) return;

  final success = await controller.reportIssue(
      category: report.category, description: report.description);
  if (!context.mounted) return;
  showSunToast(
    context,
    success
        ? "Report submitted. Admin will review it."
        : (controller.error ?? "Failed to submit report."),
  );
}
