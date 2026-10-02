import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/network/api_client.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../booking/presentation/rating_page.dart";
import "../../../booking/repositories/booking_repository.dart";
import "../../repositories/passenger_repository.dart";
import "../passenger_ride_controller.dart";
import "../widgets/passenger_ride_map.dart";
import "../widgets/passenger_ride_widgets.dart";

/// Live status of the passenger's booking: choosing a rider, waiting,
/// driver on the way / arrived (PIN), in progress, then completed (rate)
/// or cancelled.
class RideStatusPage extends StatefulWidget {
  const RideStatusPage({super.key});

  @override
  State<RideStatusPage> createState() => _RideStatusPageState();
}

class _RideStatusPageState extends State<RideStatusPage> {
  PassengerRideController? _ctrl;
  int _seenPinPrompt = 0;
  int _seenPickerRequest = 0;
  bool _pinDialogOpen = false;
  bool _showCancelConfirm = false;
  bool _rated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = context.read<PassengerRideController>();
    if (_ctrl == ctrl) return;
    _ctrl?.removeListener(_onRideChanged);
    _ctrl = ctrl;
    _seenPinPrompt = ctrl.pinPromptRequest;
    _seenPickerRequest = ctrl.driverPickerRequest;
    ctrl.addListener(_onRideChanged);
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onRideChanged);
    super.dispose();
  }

  void _onRideChanged() {
    final ctrl = _ctrl;
    if (ctrl == null) return;

    // The rider just arrived and will ask for the PIN — put it front and
    // centre.
    if (ctrl.pinPromptRequest != _seenPinPrompt) {
      _seenPinPrompt = ctrl.pinPromptRequest;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPin());
    }

    // The chosen rider declined / timed out: say so; the rider list is
    // back on screen to choose again.
    if (ctrl.driverPickerRequest != _seenPickerRequest) {
      _seenPickerRequest = ctrl.driverPickerRequest;
      final message = ctrl.rideNotice;
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(message)));
          }
        });
      }
    }
  }

  Future<void> _showPin() async {
    final pin = _ctrl?.pickupPin;
    if (!mounted || pin == null || _pinDialogOpen) return;
    _pinDialogOpen = true;
    await showPickupPinDialog(context, pin);
    _pinDialogOpen = false;
  }

  Future<void> _chooseDriver(PassengerRideController ctrl, int id) async {
    await ctrl.chooseDriver(id);
    if (!mounted) return;
    final message = ctrl.error ?? ctrl.rideNotice;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _cancel(PassengerRideController ctrl) async {
    await ctrl.cancelRide();
    if (!mounted) return;
    if (ctrl.error == null) setState(() => _showCancelConfirm = false);
  }

  Future<void> _rate(PassengerRideController ctrl) async {
    final bookingId = ctrl.activeBookingId;
    if (bookingId == null) return;
    final apiClient = context.read<ApiClient>();
    final rated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => Provider<BookingRepository>(
          create: (_) => BookingRepository(PassengerRepository(apiClient)),
          child: RatingPage(
            bookingId: bookingId,
            driverName: ctrl.driverName,
            vehicle: ctrl.driverTricycle == null
                ? null
                : "Tricycle ${ctrl.driverTricycle}",
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (rated == true) {
      setState(() => _rated = true);
    } else if (rated == false) {
      _done(ctrl);
    }
  }

  void _done(PassengerRideController ctrl) {
    ctrl.resetTripSelection();
    Navigator.of(context).pop();
  }

  double _fare(PassengerRideController ctrl) {
    final data = ctrl.bookingData;
    return double.tryParse(data?["final_fare"]?.toString() ?? "") ??
        double.tryParse(data?["estimated_fare"]?.toString() ?? "") ??
        ctrl.estimatedFare;
  }

  int _passengers(PassengerRideController ctrl) =>
      int.tryParse(ctrl.bookingData?["passenger_count"]?.toString() ?? "") ??
      ctrl.passengerCount;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PassengerRideController>();

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: switch (ctrl.bookingStatus) {
        _ when ctrl.activeBookingId == null => _noRide(),
        "completed" => _rated ? _thankYou(ctrl) : _completed(ctrl),
        "cancelled" => _cancelled(ctrl),
        _ => _inProgress(ctrl),
      },
    );
  }

  Widget _noRide() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("No active ride found.",
                style: TextStyle(color: DesignTokens.muted)),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: PrimaryActionButton(
                label: "Back to Home",
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inProgress(PassengerRideController ctrl) {
    final drivers = ctrl.nearbyDrivers;
    final canCancel =
        ["pending", "accepted", "arriving"].contains(ctrl.bookingStatus);
    final statusColor = switch (ctrl.bookingStatus) {
      "arriving" => DesignTokens.green,
      "pending" || "searching" => DesignTokens.warning,
      _ => DesignTokens.blue,
    };

    return Column(
      children: [
        AppTopBar(
          title: "Ride Status",
          showBack: true,
          trailing: TextButton(
            onPressed: ctrl.isSendingSos
                ? null
                : () => confirmAndSendSos(context, ctrl),
            child: Text(
              "SOS",
              style: TextStyle(
                  color: DesignTokens.red, fontWeight: DesignTokens.fw700),
            ),
          ),
        ),
        const SizedBox(height: 200, child: PassengerRideMap()),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StatusBanner(
                label: rideStatusHeadline(ctrl),
                color: statusColor,
                showSpinner: ctrl.isWaitingForDriverResponse ||
                    (ctrl.isChoosingDriver && drivers.isEmpty),
                icon: ctrl.bookingStatus == "arriving"
                    ? Icons.check_circle_rounded
                    : Icons.electric_rickshaw_rounded,
                subtitle: ctrl.rideNotice,
              ),
              if (ctrl.isChoosingDriver) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SectionLabel(
                        drivers.isEmpty
                            ? "Available riders"
                            : "Available riders (${drivers.length}) · nearest first",
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    IconButton(
                      tooltip: "Refresh",
                      visualDensity: VisualDensity.compact,
                      onPressed: ctrl.isRefreshingDrivers
                          ? null
                          : ctrl.refreshNearbyDrivers,
                      icon: ctrl.isRefreshingDrivers
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.refresh_rounded,
                              color: DesignTokens.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (drivers.isEmpty)
                  InfoBox(children: [
                    Text(
                      "No online riders nearby yet. We'll keep updating the list.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DesignTokens.muted, fontSize: 13),
                    ),
                  ])
                else
                  for (var i = 0; i < drivers.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    DriverOptionTile(
                      driver: drivers[i],
                      isNearest: i == 0,
                      enabled: !ctrl.isSubmittingRide,
                      onTap: (id) => _chooseDriver(ctrl, id),
                    ),
                  ],
              ],
              if (ctrl.driverInfo != null) ...[
                const SizedBox(height: 16),
                _DriverCard(ctrl: ctrl),
              ],
              const SizedBox(height: 16),
              InfoBox(
                children: [
                  InfoRow(
                    label: "Pickup",
                    value: pickupText(ctrl, empty: "-"),
                    icon: const Icon(Icons.location_on_rounded,
                        size: 14, color: kPickupColor),
                  ),
                  InfoRow(
                    label: "Destination",
                    value: dropoffText(ctrl, empty: "-"),
                    icon: const Icon(Icons.location_on_rounded,
                        size: 14, color: kDropoffColor),
                  ),
                  InfoRow(label: "Passengers", value: "${_passengers(ctrl)}"),
                  InfoRow(
                      label: "Fare",
                      value: "${formatMoney(_fare(ctrl))} (Cash)"),
                  if (ctrl.shouldShowPickupPin)
                    _PinBox(
                      pin: ctrl.pickupPin!,
                      highlight: ctrl.bookingStatus == "arriving",
                      onTap: _showPin,
                    ),
                ],
              ),
              if (ctrl.error != null) ...[
                const SizedBox(height: 12),
                ErrorBox(message: ctrl.error!),
              ],
              if (canCancel) ...[
                const SizedBox(height: 16),
                if (_showCancelConfirm)
                  InfoBox(
                    color: DesignTokens.red.withAlpha(20),
                    borderColor: DesignTokens.red.withAlpha(70),
                    children: [
                      Text(
                        "Cancel this ride?",
                        style: TextStyle(
                            color: DesignTokens.red,
                            fontWeight: DesignTokens.fw600),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _showCancelConfirm = false),
                              child: const Text("Keep Ride"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DesignTokens.red,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(40),
                              ),
                              onPressed: ctrl.isCompletingAction
                                  ? null
                                  : () => _cancel(ctrl),
                              child: ctrl.isCompletingAction
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text("Cancel Ride"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  TextButton.icon(
                    onPressed: () => setState(() => _showCancelConfirm = true),
                    icon: Icon(Icons.close_rounded,
                        color: DesignTokens.red, size: 18),
                    label: Text("Cancel Ride",
                        style: TextStyle(color: DesignTokens.red)),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _completed(PassengerRideController ctrl) {
    return Column(
      children: [
        const AppTopBar(title: "Ride Completed"),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              InfoBox(
                color: DesignTokens.green.withAlpha(24),
                borderColor: DesignTokens.green.withAlpha(70),
                padding: const EdgeInsets.all(20),
                spacing: 6,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: DesignTokens.green, size: 40),
                  Text(
                    "You have arrived!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: DesignTokens.text,
                        fontSize: 18,
                        fontWeight: DesignTokens.fw700),
                  ),
                  Text(
                    formatMoney(_fare(ctrl)),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: DesignTokens.green,
                        fontSize: 30,
                        fontWeight: DesignTokens.fw700),
                  ),
                  Text("Pay in Cash",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: DesignTokens.muted, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 20),
              InfoBox(
                spacing: 8,
                children: [
                  InfoRow(label: "Pickup", value: pickupText(ctrl, empty: "-")),
                  InfoRow(
                      label: "Destination",
                      value: dropoffText(ctrl, empty: "-")),
                  InfoRow(label: "Passengers", value: "${_passengers(ctrl)}"),
                  InfoRow(label: "Driver", value: ctrl.driverName ?? "—"),
                  InfoRow(label: "Tricycle", value: ctrl.driverTricycle ?? "—"),
                ],
              ),
              const SizedBox(height: 24),
              PrimaryActionButton(
                  label: "Rate Driver", onPressed: () => _rate(ctrl)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _done(ctrl),
                child: Text("Skip Rating",
                    style: TextStyle(color: DesignTokens.muted)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thankYou(PassengerRideController ctrl) {
    return _CenteredResult(
      icon: Icons.check_circle_rounded,
      iconColor: DesignTokens.green,
      title: "Ride Completed!",
      lines: [
        "You paid ${formatMoney(_fare(ctrl))} cash",
        "Thank you for using FindMeTricycle",
      ],
      onDone: () => _done(ctrl),
    );
  }

  Widget _cancelled(PassengerRideController ctrl) {
    return _CenteredResult(
      icon: Icons.close_rounded,
      iconColor: DesignTokens.red,
      title: "Ride Cancelled",
      // Says who cancelled and why when it wasn't the passenger (admin,
      // driver no-show report).
      lines: [ctrl.rideNotice ?? "Your ride has been cancelled."],
      onDone: () => _done(ctrl),
    );
  }
}

class _CenteredResult extends StatelessWidget {
  const _CenteredResult({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.lines,
    required this.onDone,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> lines;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                  color: DesignTokens.text,
                  fontSize: 20,
                  fontWeight: DesignTokens.fw700),
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DesignTokens.muted)),
              ),
            const SizedBox(height: 28),
            PrimaryActionButton(label: "Back to Home", onPressed: onDone),
          ],
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.ctrl});

  final PassengerRideController ctrl;

  @override
  Widget build(BuildContext context) {
    final name = ctrl.driverName ?? "Assigned driver";
    final distance = ctrl.driverDistanceToPickupKm;
    return InfoBox(
      children: [
        Row(
          children: [
            InitialAvatar(name: name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: DesignTokens.text,
                          fontWeight: DesignTokens.fw600)),
                  if (ctrl.driverTricycle != null)
                    Text("Tricycle ${ctrl.driverTricycle}",
                        style:
                            TextStyle(color: DesignTokens.muted, fontSize: 13)),
                  if (ctrl.driverRating != null)
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(ctrl.driverRating!.toStringAsFixed(1),
                            style: TextStyle(
                                color: DesignTokens.muted, fontSize: 12)),
                      ],
                    ),
                ],
              ),
            ),
            if (distance != null)
              Row(
                children: [
                  Icon(Icons.near_me_rounded,
                      size: 14, color: DesignTokens.blue),
                  const SizedBox(width: 4),
                  Text(
                    distance < 1
                        ? "${(distance * 1000).round()} m"
                        : "${distance.toStringAsFixed(1)} km",
                    style: TextStyle(color: DesignTokens.blue, fontSize: 13),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _PinBox extends StatelessWidget {
  const _PinBox(
      {required this.pin, required this.highlight, required this.onTap});

  final String pin;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? DesignTokens.green : DesignTokens.warning;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Row(
          children: [
            Text("PIN:",
                style: TextStyle(
                    color: DesignTokens.text, fontWeight: DesignTokens.fw700)),
            const SizedBox(width: 10),
            Text(
              pin,
              style: TextStyle(
                color: DesignTokens.accent,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text("(Show to driver)",
                  style: TextStyle(color: DesignTokens.muted, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
