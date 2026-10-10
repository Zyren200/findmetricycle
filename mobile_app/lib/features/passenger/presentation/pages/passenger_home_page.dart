import "package:flutter/material.dart";
import "package:latlong2/latlong.dart" as ll;
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/config/app_config.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../shared/state/notifications_controller.dart";
import "../../../shared/state/session_store.dart";
import "../passenger_navigation.dart";
import "../passenger_profile_controller.dart";
import "../passenger_ride_controller.dart";
import "../widgets/passenger_ride_map.dart";
import "../widgets/passenger_ride_widgets.dart";
import "booking_flow_page.dart";
import "favorites_page.dart";
import "ride_status_page.dart";

/// Passenger Home: the live map with nearby riders, a glass greeting and
/// alerts button on top, and the "Where to?" sheet (or the active ride)
/// at the bottom.
class PassengerHomePage extends StatefulWidget {
  const PassengerHomePage({super.key});

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage>
    with WidgetsBindingObserver {
  final _map = MapHandle();

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

  void _searchDestination() {
    pushPassengerPage(
        context, const BookingFlowPage(searchDestinationFirst: true));
  }

  void _viewRide() => pushPassengerPage(context, const RideStatusPage());

  /// A saved place chip: pickup here (when it isn't set yet), drop-off at
  /// the place, then plan the ride.
  Future<void> _useFavorite(Map<String, dynamic> favorite) async {
    final lat = double.tryParse(favorite["lat"]?.toString() ?? "");
    final lng = double.tryParse(favorite["lng"]?.toString() ?? "");
    if (lat == null || lng == null) {
      showSunToast(context, "This saved place has no location.");
      return;
    }
    final ctrl = context.read<PassengerRideController>();
    final profile = context.read<PassengerProfileController>();
    final id = favorite["id"] as int?;
    if (id != null) profile.useFavorite(id: id);
    if (ctrl.pickup == null && ctrl.currentPosition != null) {
      ctrl.usePickupAtCurrentLocation();
    }
    if (!ctrl.setDestinationFromFavorite(ll.LatLng(lat, lng),
        address: favorite["address"] as String?)) {
      showSunToast(context, ctrl.error ?? "Couldn't use this place.");
      return;
    }
    pushPassengerPage(context, const BookingFlowPage());
  }

  void _openSavedPlaces() => pushPassengerPage(context, const FavoritesPage());

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 18) return "Good afternoon";
    return "Good evening";
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PassengerRideController>();
    final profile = context.watch<PassengerProfileController>();
    final notifications = context.watch<NotificationsController>();
    final name = context.watch<SessionStore>().session?.fullName ?? "Passenger";
    final first = firstName(name, fallback: "there");
    final ongoing = hasOngoingBooking(ctrl);
    final imagePath = profile.userProfile?["profile_image_url"] as String?;
    final top = MediaQuery.paddingOf(context).top;
    final online = ctrl.liveDrivers.length;

    return Scaffold(
      backgroundColor: DesignTokens.mapLand,
      body: Stack(
        children: [
          Positioned.fill(
            child: PassengerRideMap(
              showControls: false,
              handle: _map,
              fitPadding: EdgeInsets.fromLTRB(40, top + 140, 40, 400),
            ),
          ),

          // Greeting and alerts
          Positioned(
            top: top + 6,
            left: 12,
            right: 12,
            child: FadeRise(
              child: Row(
                children: [
                  Flexible(
                    child: PrismChip(
                      leading: ToneAvatar(
                        name: name,
                        tone: AvatarTone.lagoon,
                        size: 34,
                        circle: true,
                        imageUrl: imagePath == null
                            ? null
                            : AppConfig.resolveAssetUrl(imagePath),
                      ),
                      overline: _greeting(),
                      title: first,
                    ),
                  ),
                  const Spacer(),
                  GlassIconButton(
                    icon: Icons.notifications_none_rounded,
                    label: notifications.unread > 0
                        ? "Alerts, ${notifications.unread} unread"
                        : "Alerts",
                    dot: notifications.unread > 0,
                    onTap: () => context.read<ValueNotifier<int>>().value = 2,
                  ),
                ],
              ),
            ),
          ),

          // Riders online
          Positioned(
            top: top + 62,
            left: 12,
            right: 12,
            child: Center(
              child: FadeRise(
                delay: const Duration(milliseconds: 200),
                child: LivePill(
                  active: online > 0,
                  text: online == 0
                      ? "Looking for riders nearby"
                      : online == 1
                          ? "1 rider online nearby"
                          : "$online riders online nearby",
                ),
              ),
            ),
          ),

          // Locate button and the sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 12),
                  child: FadeRise(
                    delay: const Duration(milliseconds: 200),
                    child: GlassIconButton(
                      icon: Icons.my_location_rounded,
                      label: "Center map on my location",
                      square: true,
                      onTap: _map.recenter,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.62),
                  child: SingleChildScrollView(
                    child: ongoing
                        ? _ActiveRideSheet(ctrl: ctrl, onView: _viewRide)
                        : _WhereToSheet(
                            ctrl: ctrl,
                            firstName: first,
                            favorites: profile.favorites,
                            onSearch: _searchDestination,
                            onFavorite: _useFavorite,
                            onSavedPlaces: _openSavedPlaces,
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

class _WhereToSheet extends StatelessWidget {
  const _WhereToSheet({
    required this.ctrl,
    required this.firstName,
    required this.favorites,
    required this.onSearch,
    required this.onFavorite,
    required this.onSavedPlaces,
  });

  final PassengerRideController ctrl;
  final String firstName;
  final List<Map<String, dynamic>> favorites;
  final VoidCallback onSearch;
  final void Function(Map<String, dynamic>) onFavorite;
  final VoidCallback onSavedPlaces;

  @override
  Widget build(BuildContext context) {
    return MapSheet(
      overTabs: true,
      label: "Book a ride",
      children: [
        if (ctrl.currentPosition == null) LocationStatusBox(ctrl: ctrl),
        if (ctrl.isOutsideServiceArea) ServiceAreaNotice(ctrl: ctrl),
        const Overline("Where to?"),
        SearchWell(label: "Search destination", onTap: onSearch),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(bottom: 2),
            children: [
              for (final fav in favorites.take(8)) ...[
                PlaceChip(
                  icon: placeIcon(fav["label"]?.toString()),
                  label: fav["label"]?.toString() ?? "Saved place",
                  onTap: () => onFavorite(fav),
                ),
                const SizedBox(width: 8),
              ],
              PlaceChip(
                icon: favorites.isEmpty
                    ? Icons.bookmark_add_outlined
                    : Icons.bookmarks_outlined,
                label: favorites.isEmpty ? "Save a place" : "Saved places",
                onTap: onSavedPlaces,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// An icon that fits a saved place's name.
IconData placeIcon(String? label) {
  final l = (label ?? "").toLowerCase();
  if (l.contains("home") || l.contains("bahay")) return Icons.home_outlined;
  if (l.contains("church") || l.contains("simbahan")) {
    return Icons.church_outlined;
  }
  if (l.contains("market") || l.contains("palengke")) {
    return Icons.storefront_outlined;
  }
  if (l.contains("work") || l.contains("trabaho") || l.contains("office")) {
    return Icons.work_outline_rounded;
  }
  if (l.contains("school") || l.contains("eskwela")) {
    return Icons.school_outlined;
  }
  return Icons.place_outlined;
}

/// The ride in progress, front and centre on Home.
class _ActiveRideSheet extends StatelessWidget {
  const _ActiveRideSheet({required this.ctrl, required this.onView});

  final PassengerRideController ctrl;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final detail = rideStatusDetail(ctrl);
    return MapSheet(
      overTabs: true,
      label: "Your ride",
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Overline("Ride in progress"),
                  const SizedBox(height: 4),
                  Text(rideStatusHeadline(ctrl), style: DesignTokens.title),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(detail,
                        style: TextStyle(
                            color: DesignTokens.ink2, fontSize: 13.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            const StatusChip("Live", tone: ChipTone.primary),
          ],
        ),
        if (ctrl.shouldShowPickupPin)
          PinBlock(pin: ctrl.pickupPin!, label: "Your PIN"),
        SunButton(
          label: ctrl.isChoosingDriver ? "Choose your rider" : "View ride",
          trailingIcon: Icons.chevron_right_rounded,
          onPressed: onView,
        ),
      ],
    );
  }
}
