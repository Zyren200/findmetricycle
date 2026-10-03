import "package:flutter/material.dart";
import "package:latlong2/latlong.dart" as ll;
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/state/app_config_store.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../../core/utils/place_search.dart";
import "../passenger_navigation.dart";
import "../passenger_profile_controller.dart";
import "../passenger_ride_controller.dart";
import "../widgets/passenger_ride_map.dart";
import "../widgets/passenger_ride_widgets.dart";
import "place_search_page.dart";
import "ride_status_page.dart";

enum _Step { pickup, destination, passengers, fare, confirm }

/// Step-by-step booking: pickup → destination → passenger count → fare
/// estimate → confirm. Confirming creates the booking and hands over to
/// [RideStatusPage], where the passenger picks a rider.
class BookingFlowPage extends StatefulWidget {
  const BookingFlowPage({super.key, this.startAtDestination = false});

  /// Skip straight to the destination step (pickup already chosen).
  final bool startAtDestination;

  @override
  State<BookingFlowPage> createState() => _BookingFlowPageState();
}

class _BookingFlowPageState extends State<BookingFlowPage> {
  late _Step _step;

  @override
  void initState() {
    super.initState();
    // Fresh service hours for the notice on the Confirm step.
    context.read<AppConfigStore>().refresh();
    final ctrl = context.read<PassengerRideController>();
    _step = widget.startAtDestination && ctrl.pickup != null
        ? _Step.destination
        : _Step.pickup;
  }

  void _goTo(_Step step) => setState(() => _step = step);

  void _back() {
    switch (_step) {
      case _Step.pickup:
        Navigator.of(context).pop();
      case _Step.destination:
        _goTo(_Step.pickup);
      case _Step.passengers:
        _goTo(_Step.destination);
      case _Step.fare:
        _goTo(_Step.passengers);
      case _Step.confirm:
        _goTo(_Step.fare);
    }
  }

  Future<void> _search(PassengerRideController ctrl,
      {required bool isPickup}) async {
    final place = await Navigator.push<PlaceSuggestion?>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceSearchPage(
          title: isPickup ? "Search pickup location" : "Search destination",
        ),
      ),
    );
    if (place == null || !mounted) return;
    if (isPickup) {
      await ctrl.setPickupFromSearch(place);
      if (mounted && ctrl.pickup != null) _goTo(_Step.destination);
    } else {
      await ctrl.setDropoffFromSearch(place);
      if (mounted && ctrl.dropoff != null) _goTo(_Step.passengers);
    }
  }

  Future<void> _useFavorite(Map<String, dynamic> favorite) async {
    final lat = double.tryParse(favorite["lat"]?.toString() ?? "");
    final lng = double.tryParse(favorite["lng"]?.toString() ?? "");
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This favorite has no saved location.")),
      );
      return;
    }
    final id = favorite["id"] as int?;
    final profile = context.read<PassengerProfileController>();
    final ctrl = context.read<PassengerRideController>();
    if (id != null) await profile.useFavorite(id: id);
    if (!mounted) return;
    // Refused (shown in the error box) when it's outside Guiuan.
    if (!ctrl.setDestinationFromFavorite(ll.LatLng(lat, lng),
        address: favorite["address"] as String?)) {
      return;
    }
    _goTo(_Step.passengers);
  }

  bool _handedOff = false;

  /// Replaces this flow with the ride status screen (once).
  void _showRideStatus() {
    if (_handedOff || !mounted) return;
    _handedOff = true;
    pushPassengerPage(context, const RideStatusPage(), replace: true);
  }

  Future<void> _confirm(PassengerRideController ctrl) async {
    await ctrl.findRide();
    if (!mounted) return;
    if (ctrl.error == null && ctrl.activeBookingId != null) _showRideStatus();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PassengerRideController>();

    // A booking was created (or restored) — it continues on the status
    // screen.
    if (hasOngoingBooking(ctrl) && !ctrl.isSubmittingRide) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showRideStatus());
    }

    return PopScope(
      canPop: _step == _Step.pickup,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: DesignTokens.bg,
        body: switch (_step) {
          _Step.pickup => _pickupStep(ctrl),
          _Step.destination => _destinationStep(ctrl),
          _Step.passengers => _passengersStep(ctrl),
          _Step.fare => _fareStep(ctrl),
          _Step.confirm => _confirmStep(ctrl),
        },
      ),
    );
  }

  Widget _mapHeader({required bool? tapSetsPickup}) {
    final ctrl = context.read<PassengerRideController>();
    return SizedBox(
      height: 180,
      child: PassengerRideMap(
        onTap: tapSetsPickup == null
            ? null
            : (point) => ctrl.selectOnMap(point, asPickup: tapSetsPickup),
      ),
    );
  }

  Widget _tapHint(PassengerRideController ctrl, String text) {
    if (ctrl.isValidatingTap) {
      return Row(
        children: [
          const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text("Checking nearest road…",
              style: TextStyle(color: DesignTokens.muted, fontSize: 12)),
        ],
      );
    }
    return Text(text,
        style: TextStyle(color: DesignTokens.muted, fontSize: 12));
  }

  // ── Step: Pickup ──────────────────────────────────────────────────────
  Widget _pickupStep(PassengerRideController ctrl) {
    return Column(
      children: [
        AppTopBar(title: "Set Pickup", showBack: true, onBack: _back),
        _mapHeader(tapSetsPickup: true),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LocationField(
                icon: Icons.search_rounded,
                iconColor: kPickupColor,
                text: "Search pickup location...",
                isPlaceholder: true,
                onTap: () => _search(ctrl, isPickup: true),
              ),
              const SizedBox(height: 8),
              _tapHint(ctrl, "Or tap the map to set your pickup point."),
              if (ctrl.error != null) ...[
                const SizedBox(height: 8),
                ErrorBox(message: ctrl.error!),
              ],
              const SizedBox(height: 16),
              LocationStatusBox(ctrl: ctrl),
              ServiceAreaNotice(ctrl: ctrl),
              const SectionLabel("Pickup"),
              if (ctrl.currentPosition != null)
                PlaceListTile(
                  icon: Icons.my_location_rounded,
                  iconColor: DesignTokens.blue,
                  title: "Use my current location",
                  subtitle: "Current GPS location",
                  onTap: ctrl.usePickupAtCurrentLocation,
                ),
              if (ctrl.pickup != null)
                PlaceListTile(
                  icon: Icons.location_on_rounded,
                  iconColor: kPickupColor,
                  title: pickupText(ctrl),
                  subtitle: "Selected pickup",
                  onTap: null,
                ),
              const SizedBox(height: 20),
              PrimaryActionButton(
                label: "Continue",
                icon: Icons.chevron_right_rounded,
                onPressed:
                    ctrl.pickup == null ? null : () => _goTo(_Step.destination),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step: Destination ─────────────────────────────────────────────────
  Widget _destinationStep(PassengerRideController ctrl) {
    final favorites = context.watch<PassengerProfileController>().favorites;
    return Column(
      children: [
        AppTopBar(title: "Set Destination", showBack: true, onBack: _back),
        _mapHeader(tapSetsPickup: false),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: kPickupColor.withAlpha(28),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  border: Border.all(color: kPickupColor.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 16, color: kPickupColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(pickupText(ctrl),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: DesignTokens.text, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LocationField(
                icon: Icons.navigation_rounded,
                iconColor: kDropoffColor,
                text: ctrl.dropoff == null
                    ? "Search destination..."
                    : dropoffText(ctrl),
                isPlaceholder: ctrl.dropoff == null,
                onTap: () => _search(ctrl, isPickup: false),
              ),
              const SizedBox(height: 8),
              _tapHint(ctrl, "Or tap the map to set your drop-off point."),
              if (ctrl.error != null) ...[
                const SizedBox(height: 8),
                ErrorBox(message: ctrl.error!),
              ],
              if (favorites.isNotEmpty) ...[
                const SizedBox(height: 16),
                const SectionLabel("Where to? · Saved places"),
                for (final fav in favorites)
                  PlaceListTile(
                    icon: Icons.star_rounded,
                    iconColor: Colors.amber,
                    title: fav["label"] as String? ?? "Favorite",
                    subtitle: fav["address"] as String?,
                    onTap: () => _useFavorite(fav),
                  ),
              ],
              const SizedBox(height: 20),
              PrimaryActionButton(
                label: "Continue",
                icon: Icons.chevron_right_rounded,
                onPressed:
                    ctrl.dropoff == null ? null : () => _goTo(_Step.passengers),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step: Passenger count ─────────────────────────────────────────────
  Widget _passengersStep(PassengerRideController ctrl) {
    return Column(
      children: [
        AppTopBar(title: "Passenger Count", showBack: true, onBack: _back),
        _mapHeader(tapSetsPickup: null),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            children: [
              Row(
                children: [
                  Icon(Icons.people_alt_rounded,
                      color: DesignTokens.accent, size: 20),
                  const SizedBox(width: 8),
                  Text("How many passengers?",
                      style: TextStyle(
                          color: DesignTokens.text,
                          fontWeight: DesignTokens.fw600)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Maximum ${PassengerRideController.maxPassengers} passengers per tricycle",
                style: TextStyle(color: DesignTokens.muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  for (var n = PassengerRideController.minPassengers;
                      n <= PassengerRideController.maxPassengers;
                      n++) ...[
                    if (n > PassengerRideController.minPassengers)
                      const SizedBox(width: 10),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _CountTile(
                          value: n,
                          selected: ctrl.passengerCount == n,
                          onTap: () => ctrl.setPassengerCount(n),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),
              InfoBox(
                spacing: 6,
                children: [
                  InfoRow(label: "Pickup:", value: pickupText(ctrl)),
                  InfoRow(label: "Destination:", value: dropoffText(ctrl)),
                  InfoRow(
                      label: "Passengers:", value: "${ctrl.passengerCount}"),
                ],
              ),
              const SizedBox(height: 24),
              PrimaryActionButton(
                label: ctrl.isLoadingRoute
                    ? "Calculating fare..."
                    : "Calculate Fare",
                icon: Icons.chevron_right_rounded,
                loading: ctrl.isLoadingRoute,
                onPressed: () => _goTo(_Step.fare),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step: Fare estimate ───────────────────────────────────────────────
  Widget _fareStep(PassengerRideController ctrl) {
    final distance = ctrl.estimatedDistanceKm;
    return Column(
      children: [
        AppTopBar(title: "Fare Estimate", showBack: true, onBack: _back),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: DesignTokens.accent,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                ),
                child: Column(
                  children: [
                    Text("Amount to Pay",
                        style: TextStyle(
                            color: DesignTokens.bg.withAlpha(200),
                            fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      formatMoney(ctrl.estimatedFare),
                      style: TextStyle(
                        color: DesignTokens.bg,
                        fontSize: 40,
                        fontWeight: DesignTokens.fw700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text("Payment: Cash",
                        style: TextStyle(
                            color: DesignTokens.bg.withAlpha(200),
                            fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              InfoBox(
                children: [
                  InfoRow(label: "Pickup", value: pickupText(ctrl)),
                  InfoRow(label: "Destination", value: dropoffText(ctrl)),
                  InfoRow(
                      label: "Passengers", value: "${ctrl.passengerCount} pax"),
                  const InfoDivider(),
                  InfoRow(
                      label: "Distance",
                      value: "${distance.toStringAsFixed(2)} km"),
                  InfoRow(
                      label: "Base Fare", value: formatMoney(ctrl.baseFare)),
                  InfoRow(
                      label: "Distance Fare",
                      value: formatMoney(ctrl.distanceFare)),
                  if (ctrl.additionalPassengersFare > 0)
                    InfoRow(
                      label: "Additional Passengers",
                      value: formatMoney(ctrl.additionalPassengersFare),
                    ),
                  const InfoDivider(),
                  InfoRow(
                      label: "Total Fare",
                      value: formatMoney(ctrl.estimatedFare),
                      bold: true),
                  const InfoRow(label: "Payment Method", value: "Cash"),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Final fare may vary slightly based on the actual distance travelled.",
                textAlign: TextAlign.center,
                style: TextStyle(color: DesignTokens.muted, fontSize: 12),
              ),
              const SizedBox(height: 24),
              PrimaryActionButton(
                label: "Continue to Confirm",
                onPressed: () => _goTo(_Step.confirm),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step: Confirm ─────────────────────────────────────────────────────
  Widget _confirmStep(PassengerRideController ctrl) {
    final count = ctrl.passengerCount;
    final config = context.watch<AppConfigStore>();
    return Column(
      children: [
        AppTopBar(title: "Confirm Booking", showBack: true, onBack: _back),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            children: [
              InfoBox(
                children: [
                  Text("Booking Summary",
                      style: TextStyle(
                          color: DesignTokens.text,
                          fontWeight: DesignTokens.fw600)),
                  InfoRow(
                    label: "Pickup",
                    value: pickupText(ctrl),
                    icon: const Icon(Icons.location_on_rounded,
                        size: 16, color: kPickupColor),
                  ),
                  InfoRow(
                    label: "Destination",
                    value: dropoffText(ctrl),
                    icon: const Icon(Icons.navigation_rounded,
                        size: 16, color: kDropoffColor),
                  ),
                  InfoRow(
                    label: "Passengers",
                    value: "$count passenger${count > 1 ? "s" : ""}",
                    icon: Icon(Icons.people_alt_rounded,
                        size: 16, color: DesignTokens.muted),
                  ),
                  const InfoDivider(),
                  InfoRow(
                    label: "Fare",
                    value: formatMoney(ctrl.estimatedFare),
                    bold: true,
                    icon: Icon(Icons.payments_rounded,
                        size: 16, color: DesignTokens.green),
                  ),
                  InfoRow(
                    label: "Payment",
                    value: "Cash",
                    icon: Icon(Icons.check_rounded,
                        size: 16, color: DesignTokens.green),
                  ),
                ],
              ),
              // Heads-up only; the server is what actually refuses the booking.
              if (config.bookingClosedNow && ctrl.error == null)
                AppNotice(
                  color: DesignTokens.warning,
                  message:
                      "Bookings are only available ${config.operatingHoursLabel}. Please try again during service hours.",
                ),
              if (ctrl.error != null) ...[
                const SizedBox(height: 16),
                ErrorBox(message: ctrl.error!),
              ],
              const SizedBox(height: 24),
              PrimaryActionButton(
                label:
                    ctrl.isSubmittingRide ? "Confirming..." : "Confirm & Book",
                loading: ctrl.isSubmittingRide,
                onPressed: ctrl.pickup == null || ctrl.dropoff == null
                    ? null
                    : () => _confirm(ctrl),
              ),
              const SizedBox(height: 12),
              Text(
                "By confirming, you agree to pay ${formatMoney(ctrl.estimatedFare)} in cash upon ride completion.",
                textAlign: TextAlign.center,
                style: TextStyle(color: DesignTokens.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile(
      {required this.value, required this.selected, required this.onTap});

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? DesignTokens.accent : DesignTokens.bg2,
      borderRadius: BorderRadius.circular(DesignTokens.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radius),
            border: Border.all(
              color: selected ? DesignTokens.accent : DesignTokens.border2,
              width: 2,
            ),
          ),
          child: Text(
            "$value",
            style: TextStyle(
              color: selected ? DesignTokens.bg : DesignTokens.text,
              fontSize: 20,
              fontWeight: DesignTokens.fw700,
            ),
          ),
        ),
      ),
    );
  }
}
