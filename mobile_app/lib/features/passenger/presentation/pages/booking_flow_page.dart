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

/// "Plan your ride": the route on the map, and one sheet with pickup and
/// drop-off (search, current location, or tap the map), the passenger
/// count and the fare estimate. "Find a tricycle" creates the booking and
/// hands over to [RideStatusPage], where the passenger picks a rider.
class BookingFlowPage extends StatefulWidget {
  const BookingFlowPage({
    super.key,
    this.startAtDestination = false,
    this.searchDestinationFirst = false,
  });

  /// Map taps set the drop-off first (pickup already chosen).
  final bool startAtDestination;

  /// Opens the destination search right away (Home's search bar).
  final bool searchDestinationFirst;

  @override
  State<BookingFlowPage> createState() => _BookingFlowPageState();
}

class _BookingFlowPageState extends State<BookingFlowPage> {
  /// Which point a tap on the map sets.
  late bool _tapSetsPickup;
  bool _showBreakdown = false;
  bool _handedOff = false;
  final _map = MapHandle();

  @override
  void initState() {
    super.initState();
    // Fresh service hours for the notice on the sheet.
    context.read<AppConfigStore>().refresh();
    final ctrl = context.read<PassengerRideController>();
    if (ctrl.pickup == null && ctrl.currentPosition != null) {
      ctrl.usePickupAtCurrentLocation();
    }
    _tapSetsPickup = ctrl.pickup == null && !widget.startAtDestination;
    if (widget.searchDestinationFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _search(ctrl, isPickup: ctrl.pickup == null);
      });
    }
  }

  Future<void> _search(PassengerRideController ctrl,
      {required bool isPickup}) async {
    setState(() => _tapSetsPickup = isPickup);
    final place = await Navigator.push<PlaceSuggestion?>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceSearchPage(
          title: isPickup ? "Search pickup location" : "Where to?",
          isPickup: isPickup,
          offerCurrentLocation: isPickup && ctrl.currentPosition != null,
        ),
      ),
    );
    if (place == null || !mounted) return;
    if (identical(place, kCurrentLocationChoice)) {
      final dropoff = ctrl.dropoff;
      final dropoffAddress = ctrl.dropoffAddress;
      ctrl.usePickupAtCurrentLocation();
      // Keep the chosen drop-off: "current location" only moves the pickup.
      if (dropoff != null) {
        ctrl.setDestinationFromFavorite(dropoff, address: dropoffAddress);
      }
    } else if (isPickup) {
      await ctrl.setPickupFromSearch(place);
    } else {
      await ctrl.setDropoffFromSearch(place);
    }
    if (!mounted) return;
    if (isPickup && ctrl.pickup != null && ctrl.dropoff == null) {
      // Next: where to.
      setState(() => _tapSetsPickup = false);
      _search(ctrl, isPickup: false);
    } else {
      setState(() => _tapSetsPickup = ctrl.pickup == null);
    }
  }

  Future<void> _useFavorite(Map<String, dynamic> favorite) async {
    final lat = double.tryParse(favorite["lat"]?.toString() ?? "");
    final lng = double.tryParse(favorite["lng"]?.toString() ?? "");
    if (lat == null || lng == null) {
      showSunToast(context, "This saved place has no location.");
      return;
    }
    final id = favorite["id"] as int?;
    final profile = context.read<PassengerProfileController>();
    final ctrl = context.read<PassengerRideController>();
    if (id != null) await profile.useFavorite(id: id);
    if (!mounted) return;
    // Refused (shown in the error box) when it's outside Guiuan.
    ctrl.setDestinationFromFavorite(ll.LatLng(lat, lng),
        address: favorite["address"] as String?);
  }

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
    final favorites = context.watch<PassengerProfileController>().favorites;
    final config = context.watch<AppConfigStore>();
    final top = MediaQuery.paddingOf(context).top;

    // A booking was created (or restored) — it continues on the status
    // screen.
    if (hasOngoingBooking(ctrl) && !ctrl.isSubmittingRide) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showRideStatus());
    }

    final ready = ctrl.pickup != null && ctrl.dropoff != null;
    final km = ctrl.estimatedDistanceKm;
    final minutes = km <= 0 ? 0 : (km / 18 * 60).ceil().clamp(1, 999);

    return Scaffold(
      backgroundColor: DesignTokens.mapLand,
      body: Stack(
        children: [
          Positioned.fill(
            child: PassengerRideMap(
              showControls: false,
              handle: _map,
              fitPadding: EdgeInsets.fromLTRB(40, top + 90, 40, 470),
              onTap: (point) async {
                final setsPickup = _tapSetsPickup;
                await ctrl.selectOnMap(point, asPickup: setsPickup);
                // Pickup placed: the next tap sets the drop-off.
                if (mounted && setsPickup && ctrl.pickup != null) {
                  setState(() => _tapSetsPickup = false);
                }
              },
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
                  const Flexible(child: PrismChip(title: "Plan your ride")),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ready) ...[
                        GlassIconButton(
                          icon: Icons.zoom_out_map_rounded,
                          label: "Show the whole route",
                          square: true,
                          onTap: _map.fit,
                        ),
                        const SizedBox(width: 10),
                      ],
                      GlassIconButton(
                        icon: Icons.my_location_rounded,
                        label: "Center map on my location",
                        square: true,
                        onTap: _map.recenter,
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.7),
                  child: SingleChildScrollView(
                    child: MapSheet(
                      label: "Trip details",
                      children: [
                        RoutePoints(
                          pickup: pickupText(ctrl, empty: "Set your pickup"),
                          dropoff: dropoffText(ctrl, empty: "Where to?"),
                          pickupPlaceholder: ctrl.pickup == null,
                          dropoffPlaceholder: ctrl.dropoff == null,
                          highlightPickup: _tapSetsPickup,
                          highlightDropoff: !_tapSetsPickup,
                          onPickup: () => _search(ctrl, isPickup: true),
                          onDropoff: () => _search(ctrl, isPickup: false),
                          pickupTrailing: ctrl.currentPosition == null
                              ? null
                              : IconButton(
                                  tooltip: "Use my current location",
                                  onPressed: () {
                                    final dropoff = ctrl.dropoff;
                                    final address = ctrl.dropoffAddress;
                                    ctrl.usePickupAtCurrentLocation();
                                    if (dropoff != null) {
                                      ctrl.setDestinationFromFavorite(dropoff,
                                          address: address);
                                    }
                                  },
                                  icon: Icon(Icons.my_location_rounded,
                                      size: 20, color: DesignTokens.lagoonText),
                                ),
                        ),
                        _TapHint(
                          validating: ctrl.isValidatingTap,
                          setsPickup: _tapSetsPickup,
                          onSwitch: () =>
                              setState(() => _tapSetsPickup = !_tapSetsPickup),
                        ),
                        if (ctrl.dropoff == null && favorites.isNotEmpty)
                          SizedBox(
                            height: 44,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              padding: const EdgeInsets.only(bottom: 4),
                              children: [
                                for (final fav in favorites.take(8)) ...[
                                  PlaceChip(
                                    icon: Icons.bookmark_rounded,
                                    label: fav["label"]?.toString() ??
                                        "Saved place",
                                    onTap: () => _useFavorite(fav),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                        if (ctrl.currentPosition == null)
                          LocationStatusBox(ctrl: ctrl),
                        if (ctrl.isOutsideServiceArea)
                          ServiceAreaNotice(ctrl: ctrl),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Passengers",
                                      style: TextStyle(
                                          color: DesignTokens.ink,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                      "Up to ${PassengerRideController.maxPassengers} per tricycle",
                                      style: TextStyle(
                                          color: DesignTokens.ink2,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 136,
                              child: CountStepper(
                                value: ctrl.passengerCount,
                                min: PassengerRideController.minPassengers,
                                max: PassengerRideController.maxPassengers,
                                onChanged: ctrl.setPassengerCount,
                              ),
                            ),
                          ],
                        ),
                        _FareBar(
                          ready: ready,
                          fare: ready ? shortMoney(ctrl.estimatedFare) : "₱—",
                          meta: ready
                              ? "${km.toStringAsFixed(1)} km · $minutes min"
                              : "Cash",
                          open: _showBreakdown,
                          onTap: ready
                              ? () =>
                                  setState(() => _showBreakdown = !_showBreakdown)
                              : null,
                        ),
                        if (_showBreakdown && ready)
                          InfoBox(
                            spacing: 8,
                            children: [
                              InfoRow(
                                  label: "Distance",
                                  value: "${km.toStringAsFixed(2)} km"),
                              InfoRow(
                                  label: "Base fare",
                                  value: formatMoney(ctrl.baseFare)),
                              InfoRow(
                                  label: "Distance fare",
                                  value: formatMoney(ctrl.distanceFare)),
                              if (ctrl.additionalPassengersFare > 0)
                                InfoRow(
                                  label: "Additional passengers",
                                  value: formatMoney(
                                      ctrl.additionalPassengersFare),
                                ),
                              const InfoDivider(),
                              InfoRow(
                                  label: "Total",
                                  value: formatMoney(ctrl.estimatedFare),
                                  bold: true),
                            ],
                          ),
                        // Heads-up only; the server is what actually refuses
                        // the booking.
                        if (config.bookingClosedNow && ctrl.error == null)
                          StatusBanner(
                            label: "Outside service hours",
                            subtitle:
                                "Bookings are only available ${config.operatingHoursLabel}.",
                            color: DesignTokens.primaryBright,
                            icon: Icons.schedule_rounded,
                          ),
                        if (ctrl.error != null) ErrorBox(message: ctrl.error!),
                        SunButton(
                          label: ctrl.isSubmittingRide
                              ? "Booking…"
                              : "Find a tricycle",
                          trailingIcon: Icons.arrow_forward_rounded,
                          loading: ctrl.isSubmittingRide ||
                              (ready && ctrl.isLoadingRoute),
                          onPressed: ready ? () => _confirm(ctrl) : null,
                        ),
                        Text(
                          ready
                              ? "You pay ${formatMoney(ctrl.estimatedFare)} in cash. The final fare is computed at drop-off."
                              : "The final fare is computed at drop-off.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: DesignTokens.ink2,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TapHint extends StatelessWidget {
  const _TapHint({
    required this.validating,
    required this.setsPickup,
    required this.onSwitch,
  });

  final bool validating;
  final bool setsPickup;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        color: DesignTokens.ink2, fontSize: 12, fontWeight: FontWeight.w600);
    if (validating) {
      return Row(
        children: [
          const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text("Checking nearest road…", style: style),
        ],
      );
    }
    return Row(
      children: [
        Icon(Icons.touch_app_outlined, size: 16, color: DesignTokens.ink2),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
              "Or tap the map to set your ${setsPickup ? "pickup" : "drop-off"}.",
              style: style),
        ),
        SunLink(
          label: setsPickup ? "Set drop-off" : "Set pickup",
          onTap: onSwitch,
        ),
      ],
    );
  }
}

/// ".fare": the estimate in an ember-tinted bar; tap it for the breakdown.
class _FareBar extends StatelessWidget {
  const _FareBar({
    required this.ready,
    required this.fare,
    required this.meta,
    required this.open,
    required this.onTap,
  });

  final bool ready;
  final String fare;
  final String meta;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final base =
        DesignTokens.isDark ? const Color(0x8C080918) : const Color(0xA8FFFFFF);
    return Semantics(
      expanded: open,
      child: Pressable(
        onTap: onTap,
        semanticLabel: "Fare breakdown",
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
                DesignTokens.ember.withValues(alpha: .10), base),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: DesignTokens.ember.withValues(alpha: .32)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Overline("Est. fare"),
                    const SizedBox(height: 4),
                    Text(fare,
                        style: TextStyle(
                            color: DesignTokens.ink,
                            fontSize: 24,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.7,
                            fontFeatures: DesignTokens.tabular)),
                  ],
                ),
              ),
              Text(meta,
                  style: TextStyle(color: DesignTokens.ink2, fontSize: 13.5)),
              if (ready) ...[
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: open ? .5 : 0,
                  duration: DesignTokens.quick,
                  child: Icon(Icons.expand_more_rounded,
                      size: 20, color: DesignTokens.ink2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
