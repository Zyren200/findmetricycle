import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../../core/theme/design_tokens.dart";
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
/// when a request arrives (DriverShellPage) and from the Home card.
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
  return "₱${value.toStringAsFixed(2)}";
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

Future<void> confirmAndSendDriverSos(
    BuildContext context, DriverRideController controller) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: DesignTokens.bg2,
      title:
          Text("Send SOS Alert?", style: TextStyle(color: DesignTokens.text)),
      content: Text(
        "This will immediately notify the admin team with your current location and active ride. Only use this in a real emergency.",
        style: TextStyle(color: DesignTokens.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text("Send SOS"),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final success = await controller.sendSos();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(success
          ? (controller.sosMessage ?? "SOS alert sent.")
          : (controller.error ?? "Failed to send SOS alert.")),
      backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
    ),
  );
}

Future<bool> confirmAndMarkNoShow(
    BuildContext context, DriverRideController controller) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: DesignTokens.bg2,
      title: Text("Report Passenger No-Show?",
          style: TextStyle(color: DesignTokens.text)),
      content: Text(
        "This ends the trip and files a report for admin review. Only use this if you've waited at the pickup point and the passenger hasn't shown up.",
        style: TextStyle(color: DesignTokens.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text("Confirm No-Show",
              style: TextStyle(color: DesignTokens.warning)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final success = await controller.markNoShow();
  if (!context.mounted) return success;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(success
          ? "Reported. You're ready for your next ride."
          : (controller.error ?? "Failed to report no-show.")),
    ),
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
  String reason = _cancelReasons.first;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        backgroundColor: DesignTokens.bg2,
        title: Text("Cancel this ride?",
            style: TextStyle(color: DesignTokens.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "The passenger will be asked to choose another rider. Only cancel if you really can't make the trip.",
              style: TextStyle(color: DesignTokens.muted),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: reason,
              dropdownColor: DesignTokens.bg2,
              style: TextStyle(color: DesignTokens.text),
              decoration: const InputDecoration(labelText: "Reason"),
              items: _cancelReasons
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => reason = value ?? reason),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Keep Ride"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text("Cancel Ride",
                style: TextStyle(color: DesignTokens.red)),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final success = await controller.cancelActiveRide(reason: reason);
  if (!context.mounted) return success;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(success
          ? "Ride cancelled. The passenger will choose another rider."
          : (controller.error ?? "Failed to cancel ride.")),
    ),
  );
  return success;
}

const Map<String, String> _reportCategoryLabels = {
  "no_show": "Passenger no-show",
  "incorrect_pickup": "Incorrect pickup",
  "fare_dispute": "Fare dispute",
  "safety_concern": "Safety concern",
  "passenger_behavior": "Passenger behavior",
  "other": "Other",
};

Future<void> showDriverReportDialog(
    BuildContext context, DriverRideController controller) async {
  final report = await showDialog<({String category, String description})>(
    context: context,
    builder: (_) => const _DriverReportDialog(),
  );
  if (report == null || !context.mounted) return;

  final success = await controller.reportIssue(
      category: report.category, description: report.description);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(success
          ? "Report submitted. Admin will review it."
          : (controller.error ?? "Failed to submit report.")),
    ),
  );
}

/// Owns its text controller so it's disposed only after the dialog has
/// fully closed. Disposing it as soon as showDialog returned crashed the
/// TextField still rebuilding during the closing animation (red screen:
/// "TextEditingController was used after being disposed").
class _DriverReportDialog extends StatefulWidget {
  const _DriverReportDialog();

  @override
  State<_DriverReportDialog> createState() => _DriverReportDialogState();
}

class _DriverReportDialogState extends State<_DriverReportDialog> {
  String _category = "no_show";
  final _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final description = _description.text.trim();
    return AlertDialog(
      backgroundColor: DesignTokens.bg2,
      title: Text("Report an Issue", style: TextStyle(color: DesignTokens.text)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              dropdownColor: DesignTokens.bg2,
              style: TextStyle(color: DesignTokens.text),
              items: _reportCategoryLabels.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: DesignTokens.text),
              decoration: InputDecoration(
                hintText: "Describe what happened…",
                filled: true,
                fillColor: DesignTokens.bg3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: description.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    (category: _category, description: description),
                  ),
          child: Text("Submit",
              style: TextStyle(color: DesignTokens.driverAccent)),
        ),
      ],
    );
  }
}
