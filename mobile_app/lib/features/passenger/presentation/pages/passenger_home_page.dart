import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../shared/state/session_store.dart";
import "../passenger_navigation.dart";
import "../passenger_ride_controller.dart";
import "../widgets/passenger_ride_map.dart";
import "../widgets/passenger_ride_widgets.dart";
import "booking_flow_page.dart";
import "ride_status_page.dart";

/// Passenger Home: greeting, live map, the active ride (if any) and the
/// entry point into the booking flow.
class PassengerHomePage extends StatefulWidget {
  const PassengerHomePage({super.key});

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from Settings (after turning on GPS or granting
  // permission): try again right away instead of waiting for a tap.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final ctrl = context.read<PassengerRideController>();
    if (ctrl.currentPosition == null && !ctrl.isResolvingLocation) {
      ctrl.refreshCurrentLocation();
    }
  }

  void _book({bool toDestination = false}) {
    pushPassengerPage(
        context, BookingFlowPage(startAtDestination: toDestination));
  }

  void _viewRide() => pushPassengerPage(context, const RideStatusPage());

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PassengerRideController>();
    final name = context.watch<SessionStore>().session?.fullName ?? "Passenger";
    final ongoing = hasOngoingBooking(ctrl);

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ctrl.refreshCurrentLocation(),
              ctrl.restoreActiveBooking(),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text("Welcome back,",
                  style: TextStyle(color: DesignTokens.muted, fontSize: 13)),
              Text(
                name,
                style: TextStyle(
                  color: DesignTokens.text,
                  fontSize: 18,
                  fontWeight: DesignTokens.fw700,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(
                height: 200,
                child:
                    PassengerRideMap(borderRadius: DesignTokens.radiusSm + 2),
              ),
              if (ctrl.currentPosition == null) ...[
                const SizedBox(height: 8),
                LocationStatusBox(ctrl: ctrl),
              ],
              const SizedBox(height: 12),
              if (ongoing)
                _ActiveRideCard(
                  status: rideStatusHeadline(ctrl),
                  destination: dropoffText(ctrl, empty: ""),
                  pin: ctrl.shouldShowPickupPin ? ctrl.pickupPin : null,
                  onView: _viewRide,
                )
              else ...[
                InfoBox(
                  children: [
                    Text("Where are you going?",
                        style: TextStyle(
                            color: DesignTokens.text,
                            fontSize: 14,
                            fontWeight: DesignTokens.fw500)),
                    LocationField(
                      icon: Icons.location_on_rounded,
                      iconColor: kPickupColor,
                      text: pickupText(ctrl),
                      isPlaceholder: ctrl.pickup == null,
                      onTap: _book,
                    ),
                    LocationField(
                      icon: Icons.navigation_rounded,
                      iconColor: kDropoffColor,
                      text: dropoffText(ctrl),
                      isPlaceholder: ctrl.dropoff == null,
                      onTap: () => _book(toDestination: true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PrimaryActionButton(
                  label: "Book a Tricycle",
                  onPressed: () => _book(toDestination: ctrl.pickup != null),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveRideCard extends StatelessWidget {
  const _ActiveRideCard({
    required this.status,
    required this.destination,
    required this.pin,
    required this.onView,
  });

  final String status;
  final String destination;
  final String? pin;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final muted = DesignTokens.bg.withAlpha(190);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.accent,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm + 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Active Ride",
                    style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: DesignTokens.fw500)),
                Text(status,
                    style: TextStyle(
                        color: DesignTokens.bg,
                        fontWeight: DesignTokens.fw600)),
                if (destination.isNotEmpty)
                  Text(destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12)),
                if (pin != null)
                  Text("PIN: $pin",
                      style: TextStyle(
                          color: DesignTokens.bg,
                          fontWeight: DesignTokens.fw700,
                          letterSpacing: 2)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onView,
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.bg,
              foregroundColor: DesignTokens.accent,
              minimumSize: const Size(0, 40),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
            ),
            child: const Text("View"),
          ),
        ],
      ),
    );
  }
}
