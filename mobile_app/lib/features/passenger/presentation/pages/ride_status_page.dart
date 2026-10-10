import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/network/api_client.dart";
import "../../../../core/safety/sos_delivery.dart";
import "../../../../core/safety/sos_flow.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../booking/presentation/rating_page.dart";
import "../../../booking/repositories/booking_repository.dart";
import "../../repositories/passenger_repository.dart";
import "../passenger_ride_controller.dart";
import "../widgets/passenger_ride_map.dart";
import "../widgets/passenger_ride_widgets.dart";

/// Live status of the passenger's booking on the full-screen map: choose a
/// rider, wait for them to accept, then follow them (on the way → at
/// pickup with the PIN → on trip), and finally rate or see why it was
/// cancelled.
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
  bool _rated = false;
  int? _selectedDriverId;
  final _map = MapHandle();

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
      _selectedDriverId = null;
      final message = ctrl.rideNotice;
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showSunToast(context, message);
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
    if (message != null) showSunToast(context, message);
  }

  Future<void> _cancel(PassengerRideController ctrl) async {
    final ok = await confirmSun(
      context,
      title: "Cancel this ride?",
      message: ctrl.driverInfo == null
          ? "Your booking will be cancelled."
          : "Your rider will be told the ride was cancelled.",
      confirmLabel: "Cancel ride",
      cancelLabel: "Keep ride",
      destructive: true,
      icon: Icons.close_rounded,
    );
    if (!ok || !mounted) return;
    await ctrl.cancelRide();
    if (mounted && ctrl.error != null) showSunToast(context, ctrl.error!);
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

    if (ctrl.activeBookingId == null) return _noRide();

    final top = MediaQuery.paddingOf(context).top;
    final status = ctrl.bookingStatus;
    final Widget overlay;
    final Widget sheet;
    if (status == "completed") {
      overlay = const SizedBox.shrink();
      sheet = _rated ? _thankYou(ctrl) : _completed(ctrl);
    } else if (status == "cancelled") {
      overlay = const SizedBox.shrink();
      sheet = _cancelled(ctrl);
    } else if (ctrl.isChoosingDriver) {
      overlay = _titleBar(
          "To ${shortPlace(dropoffText(ctrl, empty: "your drop-off"))}");
      sheet = _chooseRider(ctrl);
    } else {
      overlay = _statusBar(ctrl);
      sheet = _rideSheet(ctrl);
    }

    return Scaffold(
      backgroundColor: DesignTokens.mapLand,
      body: Stack(
        children: [
          Positioned.fill(
            child: PassengerRideMap(
              showControls: false,
              handle: _map,
              fitPadding: EdgeInsets.fromLTRB(40, top + 100, 40, 440),
            ),
          ),
          Positioned(top: top + 6, left: 12, right: 12, child: overlay),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (status != "completed" && status != "cancelled")
                  Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 12),
                    child: GlassIconButton(
                      icon: Icons.zoom_out_map_rounded,
                      label: "Show the whole trip",
                      square: true,
                      onTap: _map.fit,
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.72),
                  child: SingleChildScrollView(child: sheet),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Back button and a glass title (choosing a rider).
  Widget _titleBar(String title) {
    return FadeRise(
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.chevron_left_rounded,
            label: "Back",
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
          Flexible(child: PrismChip(title: title)),
        ],
      ),
    );
  }

  /// Live status pill and the SOS button.
  Widget _statusBar(PassengerRideController ctrl) {
    final detail = rideStatusDetail(ctrl);
    final line = detail.isEmpty
        ? rideStatusHeadline(ctrl)
        : "${rideStatusHeadline(ctrl)} · $detail";
    return FadeRise(
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: PrismChip(
                title: line,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 9),
                  child: PulseDot(
                    size: 9,
                    color: ctrl.isWaitingForDriverResponse
                        ? DesignTokens.amber
                        : DesignTokens.lagoon,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SosPill(
            onTap: ctrl.isSendingSos
                ? null
                : () => confirmAndSendSos(context, ctrl),
          ),
        ],
      ),
    );
  }

  // ── Choose a rider ────────────────────────────────────────────────────

  Widget _chooseRider(PassengerRideController ctrl) {
    final drivers = ctrl.nearbyDrivers;
    final ids = [
      for (final d in drivers) int.tryParse(d["id"]?.toString() ?? ""),
    ];
    if (!ids.contains(_selectedDriverId)) {
      _selectedDriverId = ids.isEmpty ? null : ids.first;
    }
    final selected = drivers
        .where(
            (d) => int.tryParse(d["id"]?.toString() ?? "") == _selectedDriverId)
        .firstOrNull;

    return MapSheet(
      label: "Choose your rider",
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Choose your rider", style: DesignTokens.title),
                  const SizedBox(height: 4),
                  Text("Within 5 km · 20 seconds to accept",
                      style: TextStyle(
                          color: DesignTokens.ink2, fontSize: 13.5)),
                ],
              ),
            ),
            IconButton(
              tooltip: "Refresh",
              onPressed:
                  ctrl.isRefreshingDrivers ? null : ctrl.refreshNearbyDrivers,
              icon: ctrl.isRefreshingDrivers
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.refresh_rounded,
                      color: DesignTokens.primaryText),
            ),
          ],
        ),
        if (ctrl.sosDelivery.status != SosDeliveryStatus.idle)
          SosStatusBanner(delivery: ctrl.sosDelivery, error: ctrl.sosError),
        if (drivers.isEmpty)
          const StatusBanner(
            label: "Looking for riders nearby…",
            subtitle: "No online riders yet. We'll keep updating the list.",
            color: Color(0xFFFF7A1A),
            showSpinner: true,
          )
        else
          Column(
            children: [
              for (var i = 0; i < drivers.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                RiderOptionTile(
                  driver: drivers[i],
                  isNearest: i == 0,
                  selected: ids[i] == _selectedDriverId,
                  enabled: !ctrl.isSubmittingRide,
                  onTap: () => setState(() => _selectedDriverId = ids[i]),
                ),
              ],
            ],
          ),
        if (ctrl.error != null) ErrorBox(message: ctrl.error!),
        SunButton(
          label: selected == null
              ? "Request a rider"
              : "Request ${firstName(asText(selected["full_name"]), fallback: "rider")}",
          trailingIcon: Icons.chevron_right_rounded,
          loading: ctrl.isSubmittingRide,
          onPressed: _selectedDriverId == null
              ? null
              : () => _chooseDriver(ctrl, _selectedDriverId!),
        ),
        Center(
          child: SunLink(
            label: "Cancel booking",
            color: DesignTokens.ink2,
            onTap: ctrl.isCompletingAction ? null : () => _cancel(ctrl),
          ),
        ),
      ],
    );
  }

  // ── Waiting / on the way / at pickup / on trip ────────────────────────

  Widget _rideSheet(PassengerRideController ctrl) {
    final status = ctrl.bookingStatus;
    final waiting = ctrl.isWaitingForDriverResponse;
    final ongoing = status == "ongoing" || status == "on_ride";
    final reached = switch (status) {
      "arriving" => 2,
      "ongoing" || "on_ride" => 3,
      _ => waiting ? 0 : 1,
    };
    final canCancel = ["pending", "accepted", "arriving"].contains(status);
    final name = ctrl.driverName ?? "Your rider";
    final rating = ctrl.driverRating;
    final phone = driverPhone(ctrl);
    final trike = ctrl.driverTricycle;

    return MapSheet(
      label: "Your ride",
      gap: 16,
      children: [
        if (ctrl.sosDelivery.status != SosDeliveryStatus.idle)
          SosStatusBanner(delivery: ctrl.sosDelivery, error: ctrl.sosError),
        if (waiting)
          StatusBanner(
            label: rideStatusHeadline(ctrl),
            subtitle: "They have 20 seconds to accept your request.",
            color: DesignTokens.primaryBright,
            showSpinner: true,
          )
        else
          RideProgressBars(step: reached, labels: true),
        PersonRow(
          name: name,
          tone: toneFor(ctrl.driverInfo?["id"] ?? name),
          subtitle: [
            if (trike != null) "Tricycle $trike",
            if (rating != null) "★ ${rating.toStringAsFixed(1)}",
          ].join(" · "),
          onCall: phone != null && !waiting
              ? () => callNumber(context, phone)
              : null,
        ),
        if (ctrl.shouldShowPickupPin && !ongoing)
          Pressable(
            onTap: _showPin,
            semanticLabel: "Your pickup PIN ${ctrl.pickupPin}",
            child: PinBlock(pin: ctrl.pickupPin!),
          ),
        if (ongoing)
          PrismAlert(
            tone: DesignTokens.ok,
            title: "PIN matched. The trip has started.",
            message:
                "Heading to ${shortPlace(dropoffText(ctrl, empty: "your drop-off"))} · ${shortMoney(_fare(ctrl))} cash",
          ),
        if (ctrl.error != null) ErrorBox(message: ctrl.error!),
        if (canCancel)
          Row(
            children: [
              SunButton(
                label: "Cancel ride",
                tone: SunTone.danger,
                height: 40,
                expand: false,
                loading: ctrl.isCompletingAction,
                onPressed: () => _cancel(ctrl),
              ),
              const Spacer(),
              Text("Est. ${shortMoney(_fare(ctrl))} · cash",
                  style: DesignTokens.mono
                      .copyWith(color: DesignTokens.ink2, fontSize: 13)),
            ],
          ),
      ],
    );
  }

  // ── Results ───────────────────────────────────────────────────────────

  Widget _resultCard({required List<Widget> children}) {
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
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _completed(PassengerRideController ctrl) {
    final name = ctrl.driverName;
    final count = _passengers(ctrl);
    return _resultCard(children: [
      const StatusRing(icon: Icons.check_rounded),
      const Overline("Pay in cash"),
      const SizedBox(height: 6),
      Text(formatMoney(_fare(ctrl)),
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
            shortPlace(dropoffText(ctrl, empty: "")),
            if (name != null) name,
          ].where((p) => p.isNotEmpty).join(" · "),
          textAlign: TextAlign.center,
          style: TextStyle(color: DesignTokens.ink2, fontSize: 13.5)),
      const SizedBox(height: 14),
      MetaStats(items: [
        ("$count", count > 1 ? "Passengers" : "Passenger"),
        (firstName(name, fallback: "—"), "Rider"),
        (ctrl.driverTricycle ?? "—", "Tricycle"),
      ]),
      const SizedBox(height: 16),
      SunButton(
        label: "Rate ${firstName(name, fallback: "your rider")}",
        icon: Icons.star_rounded,
        onPressed: () => _rate(ctrl),
      ),
      const SizedBox(height: 4),
      SunButton(
        label: "Skip rating",
        tone: SunTone.ghost,
        height: 44,
        onPressed: () => _done(ctrl),
      ),
    ]);
  }

  Widget _thankYou(PassengerRideController ctrl) {
    return _resultCard(children: [
      const StatusRing(
          icon: Icons.favorite_rounded, fill: DesignTokens.lagoonFill),
      const SizedBox(height: 6),
      Text("Thanks for riding!", style: DesignTokens.title),
      const SizedBox(height: 6),
      Text(
        "You paid ${formatMoney(_fare(ctrl))} in cash. Thank you for using FindMeTricycle.",
        textAlign: TextAlign.center,
        style: DesignTokens.body,
      ),
      const SizedBox(height: 18),
      SunButton(
        label: "Back to Home",
        tone: SunTone.quiet,
        height: 52,
        onPressed: () => _done(ctrl),
      ),
    ]);
  }

  Widget _cancelled(PassengerRideController ctrl) {
    return _resultCard(children: [
      const StatusRing(icon: Icons.close_rounded, fill: DesignTokens.dangerFill),
      const SizedBox(height: 6),
      Text("Ride cancelled", style: DesignTokens.title),
      const SizedBox(height: 6),
      // Says who cancelled and why when it wasn't the passenger (admin,
      // rider no-show report).
      Text(ctrl.rideNotice ?? "Your ride has been cancelled.",
          textAlign: TextAlign.center, style: DesignTokens.body),
      const SizedBox(height: 18),
      SunButton(
        label: "Back to Home",
        tone: SunTone.quiet,
        height: 52,
        onPressed: () => _done(ctrl),
      ),
    ]);
  }

  Widget _noRide() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyState(
                    icon: Icons.electric_rickshaw_outlined,
                    message: "No active ride found."),
                SunButton(
                  label: "Back to Home",
                  tone: SunTone.quiet,
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
