import "dart:async";
import "dart:math" as math;
import "package:flutter/material.dart";
import "package:latlong2/latlong.dart" as ll;
import "package:maplibre_gl/maplibre_gl.dart" as ml;
import "../../../core/config/app_config.dart";
import "../../../core/widgets/app_map.dart";
import "../../../core/widgets/map_marker_icons.dart";
import "package:provider/provider.dart";
import "../../../core/network/socket_client.dart";
import "../../../core/theme/design_tokens.dart";
import "../../../core/components/index.dart";
import "driver_notifications_page.dart";
import "driver_ride_controller.dart";
import "driver_profile_page.dart";

/// Home tab content for Driver Mode. Lives inside DriverShellPage's
/// IndexedStack — the DriverRideController it reads is provided once by
/// the shell, not created here (mirrors PassengerMapPage under
/// PassengerShellPage).
class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  AppMapController? _mapController;
  StreamSubscription? _paymentSub;
  DriverRideController? _rideController;
  bool _mapReady = false;
  String? _lastFitKey;

  final List<ml.Circle> _staticCircles = [];
  final List<ml.Symbol> _staticSymbols = [];
  String? _staticKey;
  bool _iconsReady = false;
  ml.Circle? _currentLocationCircle;
  ml.Symbol? _currentLocationSymbol;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = context.read<DriverRideController>();
    if (_rideController == ctrl) return;
    _rideController = ctrl;
    _rideController?.addListener(_applyMapData);
  }

  @override
  void dispose() {
    _paymentSub?.cancel();
    _rideController?.removeListener(_applyMapData);
    super.dispose();
  }

  Future<void> _applyMapData() async {
    final map = _mapController;
    if (map == null || !_mapReady) return;
    final ctrl = _rideController ?? context.read<DriverRideController>();

    try {
      await _updateStaticCircles(map, ctrl);
      await map.clearLines();

      final lines = <ml.LineOptions>[];
      for (final poly in ctrl.polylines) {
        final pts = <ml.LatLng>[];
        for (final ll.LatLng p in poly.points) {
          pts.add(ml.LatLng(p.latitude, p.longitude));
        }
        if (pts.isNotEmpty) {
          final colorValue = poly.color;
          String componentToHex(double component) {
            final value = (component * 255.0).round().clamp(0, 255);
            return value.toRadixString(16).padLeft(2, '0');
          }
          final lineColor = '#${componentToHex(colorValue.r)}${componentToHex(colorValue.g)}${componentToHex(colorValue.b)}';
          lines.add(
            ml.LineOptions(
              geometry: pts,
              lineColor: lineColor,
              lineWidth: poly.strokeWidth.toDouble(),
              lineOpacity: poly.isDotted ? 0.6 : 0.9,
            ),
          );
        }
      }

      if (lines.isNotEmpty) {
        await map.addLines(lines);
      }

      await _updateCurrentLocationCircle(map, ctrl);

      final bounds = _buildBounds(ctrl);
      final fitKey = _buildFitKey(ctrl);
      if (bounds != null && fitKey != _lastFitKey) {
        _lastFitKey = fitKey;
        await map.animateCameraBounds(bounds,
            left: 32, top: 88, right: 32, bottom: 220);
      }
    } catch (_) {
      // ignore map update failures from state changes during dispose
    }
  }

  Future<void> _updateStaticCircles(
      AppMapController map, DriverRideController ctrl) async {
    final pickup = ctrl.pickupLocation;
    final dropoff = ctrl.dropoffLocation;
    String key(ll.LatLng? p) =>
        p == null ? "-" : "${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}";
    final staticKey = "$_iconsReady|${key(pickup)}|${key(dropoff)}";
    if (staticKey == _staticKey) return;
    _staticKey = staticKey;

    if (_staticCircles.isNotEmpty) {
      await map.removeCircles(_staticCircles);
      _staticCircles.clear();
    }
    if (_staticSymbols.isNotEmpty) {
      await map.removeSymbols(List.of(_staticSymbols));
      _staticSymbols.clear();
    }

    final pins = <(ll.LatLng, String, String)>[
      if (pickup != null) (pickup, MapMarkerIcons.pickup, "#0E8C46"),
      if (dropoff != null) (dropoff, MapMarkerIcons.dropoff, "#C94530"),
    ];
    for (final (point, icon, color) in pins) {
      final target = ml.LatLng(point.latitude, point.longitude);
      if (_iconsReady) {
        _staticSymbols.add(await map.addMarker(target, icon, anchor: "bottom"));
      } else {
        _staticCircles.add(await map.addCircle(ml.CircleOptions(
          geometry: target,
          circleRadius: 10,
          circleColor: color,
          circleOpacity: 0.96,
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: 2,
        )));
      }
    }
  }

  bool _moved(ml.LatLng? from, ml.LatLng to) =>
      from == null ||
      (from.latitude - to.latitude).abs() > 0.00001 ||
      (from.longitude - to.longitude).abs() > 0.00001;

  Future<void> _updateCurrentLocationCircle(
      AppMapController map, DriverRideController ctrl) async {
    final position = ctrl.currentPosition;
    if (position == null) {
      if (_currentLocationCircle != null) {
        await map.removeCircle(_currentLocationCircle!);
        _currentLocationCircle = null;
      }
      if (_currentLocationSymbol != null) {
        await map.removeSymbol(_currentLocationSymbol!);
        _currentLocationSymbol = null;
      }
      return;
    }

    final target = ml.LatLng(position.latitude, position.longitude);
    final halo = _currentLocationCircle;
    if (halo == null) {
      _currentLocationCircle = await map.addCircle(
        ml.CircleOptions(
          geometry: target,
          circleRadius: _iconsReady ? 24 : 10,
          circleColor: "#1471C5",
          // Solid dot only when the rider icon isn't available.
          circleOpacity: _iconsReady ? 0.15 : 0.98,
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: _iconsReady ? 1.5 : 2,
        ),
      );
    } else if (_moved(halo.options.geometry, target)) {
      await map.moveCircleSmooth(halo, target, durationMs: 500, steps: 12);
    }

    if (_iconsReady) {
      final badge = _currentLocationSymbol;
      if (badge == null) {
        _currentLocationSymbol = await map.addMarker(target, MapMarkerIcons.self);
      } else if (_moved(badge.options.geometry, target)) {
        await map.moveSymbolSmooth(badge, target,
            durationMs: 500, steps: 12, rotate: false);
      }
    }
  }

  ml.LatLngBounds? _buildBounds(DriverRideController ctrl) {
    final points = <ml.LatLng>[];
    if (ctrl.currentPosition != null) {
      points.add(ml.LatLng(ctrl.currentPosition!.latitude,
          ctrl.currentPosition!.longitude));
    }
    if (ctrl.pickupLocation != null) {
      points.add(ml.LatLng(ctrl.pickupLocation!.latitude,
          ctrl.pickupLocation!.longitude));
    }
    if (ctrl.dropoffLocation != null) {
      points.add(ml.LatLng(ctrl.dropoffLocation!.latitude,
          ctrl.dropoffLocation!.longitude));
    }
    if (points.isEmpty) return null;

    var minLat = double.infinity;
    var minLng = double.infinity;
    var maxLat = -double.infinity;
    var maxLng = -double.infinity;
    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLat = math.max(maxLat, point.latitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    if (minLat == maxLat) {
      minLat -= 0.002;
      maxLat += 0.002;
    }
    if (minLng == maxLng) {
      minLng -= 0.002;
      maxLng += 0.002;
    }
    return ml.LatLngBounds(
      southwest: ml.LatLng(minLat, minLng),
      northeast: ml.LatLng(maxLat, maxLng),
    );
  }

  String _buildFitKey(DriverRideController ctrl) {
    final values = <String>[];
    if (ctrl.currentPosition != null) {
      values.add(
          '${ctrl.currentPosition!.latitude.toStringAsFixed(5)},${ctrl.currentPosition!.longitude.toStringAsFixed(5)}');
    }
    if (ctrl.pickupLocation != null) {
      values.add(
          '${ctrl.pickupLocation!.latitude.toStringAsFixed(5)},${ctrl.pickupLocation!.longitude.toStringAsFixed(5)}');
    }
    if (ctrl.dropoffLocation != null) {
      values.add(
          '${ctrl.dropoffLocation!.latitude.toStringAsFixed(5)},${ctrl.dropoffLocation!.longitude.toStringAsFixed(5)}');
    }
    return values.join('|');
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    final cameraTarget =
        ctrl.currentPosition ?? const ll.LatLng(14.5995, 120.9842);

    final socketClient = context.read<SocketClient>();
    final messenger = ScaffoldMessenger.of(context);
    _paymentSub ??= socketClient.on("driver:payment_received").listen((event) {
      final data = event is Map ? Map<String, dynamic>.from(event) : {};
      final payment = data["payment"] as Map<String, dynamic>?;
      final label = payment != null
          ? (payment["receiptNumber"] ?? payment["id"] ?? "payment")
          : "payment";
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text("Payment received: $label")),
        );
      }
    });

    return Stack(
      children: [
        Positioned.fill(
          child: AppMap(
            initialStyleUrl: AppConfig.openFreeMapStyleUrl,
            initialPosition:
                ml.LatLng(cameraTarget.latitude, cameraTarget.longitude),
            onMapCreated: (ctrl) {
              _mapController = ctrl;
              _mapReady = true;
              _applyMapData();
            },
            onStyleLoaded: () async {
              final map = _mapController;
              final pixelRatio = MediaQuery.of(context).devicePixelRatio;
              if (map != null) {
                try {
                  await MapMarkerIcons.register(map, pixelRatio);
                  _iconsReady = true;
                } catch (_) {
                  _iconsReady = false; // plain circles instead
                }
              }
              _staticKey = null;
              _mapReady = true;
              _applyMapData();
            },
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 12,
          child: _DriverTopCards(controller: ctrl),
        ),
        if (ctrl.incomingBooking != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: _IncomingBookingCard(controller: ctrl),
          )
        else if (ctrl.activeBooking != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: _ActiveBookingCard(controller: ctrl),
          ),
      ],
    );
  }
}

class _DriverTopCards extends StatelessWidget {
  const _DriverTopCards({required this.controller});

  final DriverRideController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.earningsSummary ?? {};
    return Column(
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: controller.isBusy
                      ? null
                      : () => controller.setOnline(!controller.isOnline),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: controller.isOnline
                          ? const Color.fromARGB(20, 62, 207, 120)
                          : const Color.fromARGB(20, 143, 145, 157),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: controller.isOnline
                            ? const Color.fromARGB(51, 62, 207, 120)
                            : DesignTokens.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: controller.isOnline ? DesignTokens.green : DesignTokens.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          controller.isOnline ? "Online" : "Offline",
                          style: TextStyle(
                            color: controller.isOnline ? DesignTokens.green : DesignTokens.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _MiniStat(label: "Rides", value: "${summary["total_rides"] ?? 0}"),
                const SizedBox(width: 10),
                _MiniStat(label: "Earned", value: "₱${summary["total_earnings"] ?? 0}"),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DriverNotificationsPage(),
                    ),
                  ),
                  icon: const Icon(Icons.notifications_outlined, size: 20),
                  color: DesignTokens.text,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: "Notifications",
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusPill(label: "GPS", ok: controller.gpsEnabled),
                _StatusPill(label: "Internet", ok: controller.hasInternet),
                _StatusPill(
                  label: "Location Sharing",
                  ok: controller.isOnline,
                ),
              ],
            ),
          ),
        ),
        if (controller.approvalMessage != null) ...[
          const SizedBox(height: 10),
          _BannerCard(
            title: switch (controller.approvalStatus) {
              "approved" => "Approved ka na!",
              "rejected" => "Hindi naaprubahan",
              "needs_correction" => "Kailangang ayusin ang dokumento",
              _ => "Driver Account",
            },
            message: controller.approvalMessage!,
            tone: switch (controller.approvalStatus) {
              "approved" => "success",
              "rejected" => "error",
              _ => "warning",
            },
            onClose: controller.dismissApprovalMessage,
          ),
        ],
        if (controller.error != null) ...[
          const SizedBox(height: 10),
          _BannerCard(
            title: "Driver Status",
            message: controller.error!,
            tone: "error",
          ),
        ],
      ],
    );
  }
}

class _IncomingBookingCard extends StatefulWidget {
  const _IncomingBookingCard({required this.controller});

  final DriverRideController controller;

  @override
  State<_IncomingBookingCard> createState() => _IncomingBookingCardState();
}

class _IncomingBookingCardState extends State<_IncomingBookingCard> {
  Timer? _tickTimer;
  int _secondsLeft = 20;

  @override
  void initState() {
    super.initState();
    _recomputeSecondsLeft();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_recomputeSecondsLeft);
    });
  }

  @override
  void didUpdateWidget(covariant _IncomingBookingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recomputeSecondsLeft();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _recomputeSecondsLeft() {
    final expiresAtRaw =
        widget.controller.incomingBooking?["offer_expires_at"]?.toString();
    final expiresAt = expiresAtRaw == null ? null : DateTime.tryParse(expiresAtRaw);
    if (expiresAt == null) {
      _secondsLeft = 20;
      return;
    }
    final remaining = expiresAt.toUtc().difference(DateTime.now().toUtc()).inSeconds;
    _secondsLeft = remaining.clamp(0, 999);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final booking = controller.incomingBooking ?? {};

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: DesignTokens.driverAccent),
                const SizedBox(width: 8),
                Text(
                  "New Ride Request",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: DesignTokens.text),
                ),
                const Spacer(),
                _RequestTimer(value: _secondsLeft),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DesignTokens.bg3,
                borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                border: Border.all(color: DesignTokens.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Incoming Request",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: DesignTokens.text,
                        ),
                  ),
                  const SizedBox(height: 10),
                  _DetailLine(label: "Passenger", value: booking["passenger_name"] ?? "-"),
                  _DetailLine(label: "Pickup", value: booking["pickup_address"] ?? "-"),
                  _DetailLine(label: "Drop-off", value: booking["dropoff_address"] ?? "-"),
                  _DetailLine(label: "Fare", value: "₱${booking["estimated_fare"] ?? "-"}"),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: "Decline",
                    style: AppButtonStyle.ghost,
                    onPressed: controller.isBusy ? null : controller.declineIncomingBooking,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: "Accept Ride",
                    onPressed: controller.isBusy ? null : controller.acceptIncomingBooking,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Prompts the driver for the passenger's 4-digit pickup PIN and, if they
/// confirm, calls DriverRideController.startRide(pin). The backend is the
/// real gate (wrong/locked PIN comes back as an error) — this dialog is
/// just the entry point.
Future<void> _promptForPinAndStartRide(
  BuildContext context,
  DriverRideController controller,
) async {
  final pin = await showDialog<String>(
    context: context,
    builder: (dialogContext) => const _PinEntryDialog(),
  );
  if (pin == null || pin.length != 4) return;
  if (!context.mounted) return;

  final success = await controller.startRide(pin);
  if (!context.mounted) return;

  if (!success && controller.error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(controller.error!)),
    );
  }
}

class _PinEntryDialog extends StatefulWidget {
  const _PinEntryDialog();

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DesignTokens.bg2,
      title: const Text(
        "Enter Pickup PIN",
        style: TextStyle(color: DesignTokens.text),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ask the passenger for the 4-digit PIN shown in their app.",
            style: TextStyle(color: DesignTokens.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DesignTokens.text,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(
              counterText: "",
              filled: true,
              fillColor: DesignTokens.bg3,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text(
            "Confirm",
            style: TextStyle(color: DesignTokens.driverAccent),
          ),
        ),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.length != 4) return;
    Navigator.pop(context, value);
  }
}

Future<void> _confirmAndSendDriverSos(
  BuildContext context,
  DriverRideController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: DesignTokens.bg2,
      title: const Text("Send SOS Alert?", style: TextStyle(color: DesignTokens.text)),
      content: const Text(
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
      content: Text(
        success
            ? (controller.sosMessage ?? "SOS alert sent.")
            : (controller.error ?? "Failed to send SOS alert."),
      ),
      backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
    ),
  );
}

Future<void> _confirmAndMarkNoShow(
  BuildContext context,
  DriverRideController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: DesignTokens.bg2,
      title: const Text("Report Passenger No-Show?",
          style: TextStyle(color: DesignTokens.text)),
      content: const Text(
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
          child: const Text(
            "Confirm No-Show",
            style: TextStyle(color: DesignTokens.warning),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final success = await controller.markNoShow();
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        success
            ? "Reported. You're ready for your next ride."
            : (controller.error ?? "Failed to report no-show."),
      ),
    ),
  );
}

const Map<String, String> _reportCategoryLabels = {
  "no_show": "Passenger no-show",
  "incorrect_pickup": "Incorrect pickup",
  "fare_dispute": "Fare dispute",
  "safety_concern": "Safety concern",
  "passenger_behavior": "Passenger behavior",
  "other": "Other",
};

Future<void> _showReportDialog(
  BuildContext context,
  DriverRideController controller,
) async {
  String category = "no_show";
  final descriptionController = TextEditingController();

  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        backgroundColor: DesignTokens.bg2,
        title: const Text("Report an Issue", style: TextStyle(color: DesignTokens.text)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                dropdownColor: DesignTokens.bg2,
                style: const TextStyle(color: DesignTokens.text),
                items: _reportCategoryLabels.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => category = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                style: const TextStyle(color: DesignTokens.text),
                decoration: const InputDecoration(
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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: descriptionController.text.trim().isEmpty
                ? null
                : () => Navigator.pop(dialogContext, true),
            child: const Text(
              "Submit",
              style: TextStyle(color: DesignTokens.driverAccent),
            ),
          ),
        ],
      ),
    ),
  );

  final description = descriptionController.text.trim();
  descriptionController.dispose();

  if (submitted != true || description.isEmpty || !context.mounted) return;

  final success = await controller.reportIssue(
    category: category,
    description: description,
  );
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        success
            ? "Report submitted. Admin will review it."
            : (controller.error ?? "Failed to submit report."),
      ),
    ),
  );
}

class _ActiveBookingCard extends StatelessWidget {
  const _ActiveBookingCard({required this.controller});

  final DriverRideController controller;

  @override
  Widget build(BuildContext context) {
    final booking = controller.activeBooking ?? {};
    final status = booking["status"]?.toString() ?? "";

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Active Ride",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                _MiniPill(label: status.toUpperCase()),
              ],
            ),
            const SizedBox(height: 10),
            _DetailLine(label: "Passenger", value: booking["passenger_name"] ?? "-"),
            _DetailLine(label: "Pickup", value: booking["pickup_address"] ?? "-"),
            _DetailLine(label: "Drop-off", value: booking["dropoff_address"] ?? "-"),
            const SizedBox(height: 12),
            if (status == "accepted")
              AppButton(
                label: "Mark Arrived",
                onPressed: controller.isBusy ? null : controller.markArrived,
              ),
            if (status == "arriving") ...[
              AppButton(
                label: "Start Ride",
                onPressed: controller.isBusy
                    ? null
                    : () => _promptForPinAndStartRide(context, controller),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: "Passenger No-Show",
                style: AppButtonStyle.ghost,
                onPressed: controller.isBusy
                    ? null
                    : () => _confirmAndMarkNoShow(context, controller),
              ),
            ],
            if (status == "ongoing")
              AppButton(
                label: "Complete Ride",
                onPressed: controller.isBusy ? null : controller.completeRide,
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.isSendingSos
                        ? null
                        : () => _confirmAndSendDriverSos(context, controller),
                    icon: const Icon(Icons.sos_rounded, color: Colors.red, size: 18),
                    label: const Text("SOS", style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showReportDialog(context, controller),
                    icon: const Icon(Icons.flag_outlined,
                        color: DesignTokens.muted, size: 18),
                    label: const Text("Report",
                        style: TextStyle(color: DesignTokens.muted)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: DesignTokens.border),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppButton(
              label: "Driver Profile",
              style: AppButtonStyle.ghost,
              onPressed: () {
                // DriverProfilePage reads DriverRideController, which lives
                // in DriverShellPage's ChangeNotifierProvider — a pushed
                // route's Overlay entry is a sibling of that subtree, not a
                // descendant, so the instance is re-supplied by value
                // instead of relying on ambient inheritance. (The Profile
                // tab itself doesn't need this — it's already a descendant.)
                final rideController = context.read<DriverRideController>();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: rideController,
                      child: const DriverProfilePage(),
                    ),
                  ),
                );
              },
            ),
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
        Icon(
          ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: color,
          size: 14,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: DesignTokens.muted,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: DesignTokens.driverAccent,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.title,
    required this.message,
    required this.tone,
    this.onClose,
  });

  final String title;
  final String message;
  final String tone;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      "error" => DesignTokens.red,
      "success" => DesignTokens.green,
      _ => DesignTokens.driverAccent,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (onClose != null)
                InkWell(
                  onTap: onClose,
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: DesignTokens.muted),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(message),
        ],
      ),
    );
  }
}

class _RequestTimer extends StatelessWidget {
  const _RequestTimer({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: DesignTokens.driverAccent, width: 2),
        color: DesignTokens.bg3,
      ),
      alignment: Alignment.center,
      child: Text(
        "$value",
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: DesignTokens.driverAccent,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DesignTokens.bg3,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DesignTokens.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: DesignTokens.muted),
            ),
          ),
          Text(
            value?.toString() ?? "-",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.text,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
