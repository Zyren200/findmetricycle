import "package:flutter/material.dart";
import "package:latlong2/latlong.dart" as ll;
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/network/api_client.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../../core/utils/ride_format.dart";
import "../../../booking/presentation/rating_page.dart";
import "../../../booking/repositories/booking_repository.dart";
import "../../repositories/passenger_repository.dart";
import "../passenger_navigation.dart";
import "../passenger_profile_controller.dart";
import "../passenger_ride_controller.dart";
import "../widgets/passenger_ride_widgets.dart";
import "booking_flow_page.dart";

/// Index of this page in the passenger shell's bottom navigation.
const int _historyTabIndex = 1;

enum _HistoryFilter { all, completed, cancelled }

/// "Your rides": totals, All / Completed / Cancelled, and one card per
/// trip with "Book again". Tapping a trip opens its details.
class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});

  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}

class _RideHistoryPageState extends State<RideHistoryPage> {
  ValueNotifier<int>? _navIndex;
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PassengerRideController>().loadBookingHistory();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navIndex = context.read<ValueNotifier<int>>();
    if (navIndex == _navIndex) return;
    _navIndex?.removeListener(_onTabChanged);
    _navIndex = navIndex..addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _navIndex?.removeListener(_onTabChanged);
    super.dispose();
  }

  // The shell keeps every tab alive (IndexedStack), so initState only runs
  // once — reload whenever the passenger opens this tab so a ride they
  // just finished or cancelled shows up.
  void _onTabChanged() {
    if (_navIndex?.value == _historyTabIndex && mounted) {
      context.read<PassengerRideController>().loadBookingHistory();
    }
  }

  Future<void> _saveAsFavorite(Map<String, dynamic> ride) async {
    final dropoffAddress = placeLabel(ride["dropoff_address"]);
    final lat = double.tryParse(ride["dropoff_lat"]?.toString() ?? "");
    final lng = double.tryParse(ride["dropoff_lng"]?.toString() ?? "");

    if (lat == null || lng == null) {
      showSunToast(
          context, "Walang naka-save na destinasyon ang biyaheng ito.");
      return;
    }

    final label = await promptPlaceLabel(
      context,
      title: "I-save sa Favorites",
      initial: dropoffAddress == kPinnedPlaceLabel ? "" : dropoffAddress,
    );
    if (label == null || label.isEmpty || !mounted) return;

    final profileController = context.read<PassengerProfileController>();
    final success = await profileController.createFavorite(
      label: label,
      address: ride["dropoff_address"]?.toString() ?? label,
      lat: lat,
      lng: lng,
    );

    if (!mounted) return;
    showSunToast(
      context,
      success
          ? "Na-save sa Favorites."
          : (profileController.favoritesError ?? "Hindi na-save ang favorite."),
    );
  }

  void _bookAgain(Map<String, dynamic> ride) {
    final lat = double.tryParse(ride["dropoff_lat"]?.toString() ?? "");
    final lng = double.tryParse(ride["dropoff_lng"]?.toString() ?? "");

    if (lat == null || lng == null) {
      showSunToast(
          context, "Walang naka-save na destinasyon ang biyaheng ito.");
      return;
    }

    final address = ride["dropoff_address"]?.toString();
    final rideController = context.read<PassengerRideController>();
    if (rideController.currentPosition != null) {
      rideController.usePickupAtCurrentLocation();
    }
    if (!rideController.setDestinationFromFavorite(
      ll.LatLng(lat, lng),
      // Coordinate-only addresses get re-geocoded on the map.
      address: looksLikeCoordinates(address) ? null : address,
    )) {
      showSunToast(context, rideController.error ?? "");
      return;
    }
    context.read<ValueNotifier<int>>().value = 0;
    pushPassengerPage(context, const BookingFlowPage(startAtDestination: true));
  }

  Future<void> _rate(Map<String, dynamic> ride) async {
    final bookingId = int.tryParse(ride["id"]?.toString() ?? "");
    if (bookingId == null) return;
    final apiClient = context.read<ApiClient>();
    final controller = context.read<PassengerRideController>();
    final rated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => Provider<BookingRepository>(
          create: (_) => BookingRepository(PassengerRepository(apiClient)),
          child: RatingPage(
            bookingId: bookingId,
            driverName: ride["driver_name"]?.toString(),
            vehicle: ride["tricycle_number"] == null
                ? null
                : "Tricycle ${ride["tricycle_number"]}",
          ),
        ),
      ),
    );
    if (rated == true) {
      await controller.loadBookingHistory();
      if (mounted) setState(() => _selectedId = null);
    }
  }

  /// The ride open in the details view, by id so it stays current across
  /// history reloads.
  dynamic _selectedId;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PassengerRideController>();
    final allRides = ctrl.bookingHistory;

    final selected = _selectedId == null
        ? null
        : allRides.where((r) => r["id"] == _selectedId).firstOrNull;
    if (selected != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _selectedId = null);
        },
        child: _RideDetails(
          ride: selected,
          onBack: () => setState(() => _selectedId = null),
          onSaveFavorite: () => _saveAsFavorite(selected),
          onBookAgain: () {
            setState(() => _selectedId = null);
            _bookAgain(selected);
          },
          onRate: () => _rate(selected),
          onReport: () => reportPassengerProblem(
            context,
            context.read<PassengerRideController>(),
            bookingId: int.tryParse(selected["id"]?.toString() ?? ""),
          ),
        ),
      );
    }

    final rides = switch (_filter) {
      _HistoryFilter.all => allRides,
      _HistoryFilter.completed =>
        allRides.where((r) => r["status"] == "completed").toList(),
      _HistoryFilter.cancelled =>
        allRides.where((r) => r["status"] == "cancelled").toList(),
    };
    final stats = ctrl.historyStats;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: ctrl.loadBookingHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
              20, top + 28, 20, DesignTokens.tabBarClearance + 8),
          children: [
            const FadeRise(
              child: ScreenTitle("Your rides",
                  subtitle: "Trips you've booked in Guiuan."),
            ),
            const SizedBox(height: 18),
            _SummaryRow(
              completed: toInt(stats["completed"]),
              cancelled: toInt(stats["cancelled"]),
              totalSpent: toDouble(stats["totalSpent"]),
            ),
            const SizedBox(height: 16),
            FilterPills<_HistoryFilter>(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
              options: const [
                (_HistoryFilter.all, "All"),
                (_HistoryFilter.completed, "Completed"),
                (_HistoryFilter.cancelled, "Cancelled"),
              ],
            ),
            const SizedBox(height: 16),
            if (ctrl.historyError != null && allRides.isEmpty)
              ErrorBox(
                message: ctrl.historyError!,
                onRetry: ctrl.loadBookingHistory,
              )
            else if (ctrl.isLoadingHistory && allRides.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (rides.isEmpty)
              EmptyState(
                icon: Icons.schedule_rounded,
                message: switch (_filter) {
                  _HistoryFilter.all => "No rides here yet.",
                  _HistoryFilter.completed => "No completed rides yet.",
                  _HistoryFilter.cancelled => "No cancelled rides.",
                },
              )
            else ...[
              ...Stagger.wrap([
                for (final ride in rides)
                  _RideCard(
                    ride: ride,
                    onTap: () => setState(() => _selectedId = ride["id"]),
                    onBookAgain: () => _bookAgain(ride),
                  ),
              ], gap: 12),
              if (ctrl.historyHasMore) ...[
                const SizedBox(height: 16),
                SunButton(
                  label: "Show more",
                  tone: SunTone.outline,
                  height: 48,
                  loading: ctrl.isLoadingMoreHistory,
                  onPressed: ctrl.loadMoreHistory,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Asks for a saved place's name ("Home", "Work"…). Null when cancelled.
Future<String?> promptPlaceLabel(BuildContext context,
    {required String title, String initial = ""}) {
  return showSunSheet<String>(
    context,
    builder: (dialogContext) => _PlaceLabelCard(title: title, initial: initial),
  );
}

class _PlaceLabelCard extends StatefulWidget {
  const _PlaceLabelCard({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_PlaceLabelCard> createState() => _PlaceLabelCardState();
}

class _PlaceLabelCardState extends State<_PlaceLabelCard> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SunSheetCard(
      title: widget.title,
      align: CrossAxisAlignment.stretch,
      content: [
        SunField(
          label: "Name",
          controller: _controller,
          hint: "hal. Bahay, Trabaho, Palengke",
          icon: Icons.bookmark_border_rounded,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
      ],
      actions: [
        SunButton(
          label: "Save",
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
        ),
        SunButton(
          label: "Cancel",
          tone: SunTone.quiet,
          height: 48,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

// ── helpers ─────────────────────────────────────────────────────────────

(String, ChipTone) _statusStyle(String status) => switch (status) {
      "completed" => ("Completed", ChipTone.ok),
      "cancelled" => ("Cancelled", ChipTone.cancel),
      "ongoing" || "on_ride" => ("On trip", ChipTone.primary),
      "accepted" || "assigned" || "arriving" => (
          "Rider on the way",
          ChipTone.primary
        ),
      _ => ("Searching", ChipTone.primary),
    };

double? _rideFare(Map<String, dynamic> ride) =>
    double.tryParse(ride["final_fare"]?.toString() ?? "") ??
    double.tryParse(ride["estimated_fare"]?.toString() ?? "");

String? _rideWhen(Map<String, dynamic> ride) => formatRideDateTime(
      ride["status"] == "completed"
          ? ride["completed_at"] ?? ride["requested_at"]
          : ride["requested_at"],
    );

// ── widgets ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.completed,
    required this.cancelled,
    required this.totalSpent,
  });

  final int completed;
  final int cancelled;
  final double totalSpent;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label, {Color? bg}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg ?? DesignTokens.surface2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: DesignTokens.ink2,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: DesignTokens.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFeatures: DesignTokens.tabular,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    return Row(
      children: [
        stat("$completed", "Completed"),
        const SizedBox(width: 8),
        stat("$cancelled", "Cancelled"),
        const SizedBox(width: 8),
        stat(peso(totalSpent), "Total spent", bg: DesignTokens.primarySoft),
      ],
    );
  }
}

/// One trip: when + status chip, from → to, fare and "Book again".
class _RideCard extends StatelessWidget {
  const _RideCard(
      {required this.ride, required this.onTap, required this.onBookAgain});

  final Map<String, dynamic> ride;
  final VoidCallback onTap;
  final VoidCallback onBookAgain;

  @override
  Widget build(BuildContext context) {
    final status = ride["status"]?.toString() ?? "";
    final (statusLabel, tone) = _statusStyle(status);
    final fare = _rideFare(ride);
    final cancelled = status == "cancelled";
    final finished = status == "completed" || cancelled;

    return SunCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_rideWhen(ride) ?? "Ride #${ride["id"]}",
                    style: TextStyle(
                        color: DesignTokens.ink2,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              StatusChip(statusLabel, tone: tone),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const _Marker(pickup: true),
              const SizedBox(width: 12),
              Expanded(
                child: Text(placeLabel(ride["pickup_address"]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: DesignTokens.ink2,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const _Marker(pickup: false),
              const SizedBox(width: 12),
              Expanded(
                child: Text(placeLabel(ride["dropoff_address"]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: DesignTokens.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: DesignTokens.line))),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    cancelled ? "No charge" : peso(fare ?? 0),
                    style: TextStyle(
                        color: DesignTokens.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFeatures: DesignTokens.tabular),
                  ),
                ),
                if (finished)
                  SunButton(
                    label: "Book again",
                    tone: SunTone.soft,
                    height: 36,
                    radius: 12,
                    fontSize: 13,
                    expand: false,
                    onPressed: onBookAgain,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.pickup});

  final bool pickup;

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: pickup ? DesignTokens.lagoon : DesignTokens.primaryBright,
          shape: pickup ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: pickup ? null : BorderRadius.circular(3),
        ),
      );
}

/// Ride details: status, route, fare, rider, your rating and actions.
class _RideDetails extends StatelessWidget {
  const _RideDetails({
    required this.ride,
    required this.onBack,
    required this.onSaveFavorite,
    required this.onBookAgain,
    required this.onRate,
    required this.onReport,
  });

  final Map<String, dynamic> ride;
  final VoidCallback onBack;
  final VoidCallback onSaveFavorite;
  final VoidCallback onBookAgain;
  final VoidCallback onRate;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final status = ride["status"]?.toString() ?? "";
    final (statusLabel, tone) = _statusStyle(status);
    final isCompleted = status == "completed";
    final isCancelled = status == "cancelled";
    final fare = _rideFare(ride);
    final distance = double.tryParse(ride["distance_km"]?.toString() ?? "");
    final pax = ride["passenger_count"]?.toString();
    final riderName = ride["driver_name"]?.toString();
    final tricycle = ride["tricycle_number"]?.toString();
    final rating = int.tryParse(ride["rating"]?.toString() ?? "");
    final cancelledBy = ride["cancelled_by"]?.toString();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          AppTopBar(title: "Ride Details", showBack: true, onBack: onBack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  20, 8, 20, DesignTokens.tabBarClearance + 8),
              children: [
                Row(
                  children: [
                    StatusChip(statusLabel, tone: tone),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_rideWhen(ride) ?? "",
                          style: TextStyle(
                              color: DesignTokens.ink2,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                RoutePoints(
                  pickup: placeLabel(ride["pickup_address"]),
                  dropoff: placeLabel(ride["dropoff_address"]),
                ),
                const SizedBox(height: 14),
                InfoBox(
                  children: [
                    if (pax != null) InfoRow(label: "Passengers", value: pax),
                    if (distance != null)
                      InfoRow(
                          label: "Distance",
                          value: "${distance.toStringAsFixed(1)} km"),
                    InfoRow(
                      label: "Fare",
                      value: isCancelled
                          ? (cancelledBy == "driver"
                              ? "Cancelled by rider"
                              : "No charge")
                          : "${peso(fare ?? 0)} (Cash)",
                      bold: true,
                    ),
                    InfoRow(label: "Ride #", value: "${ride["id"]}"),
                  ],
                ),
                if (riderName != null) ...[
                  const SizedBox(height: 14),
                  SoftBox(
                    child: Row(
                      children: [
                        ToneAvatar(name: riderName, tone: toneFor(riderName)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(riderName,
                                  style: TextStyle(
                                      color: DesignTokens.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              if (tricycle != null)
                                Text(tricycle,
                                    style: TextStyle(
                                        color: DesignTokens.ink2,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        if (rating != null)
                          Row(
                            children: [
                              for (var i = 1; i <= 5; i++)
                                Icon(
                                  i <= rating
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 16,
                                  color: i <= rating
                                      ? DesignTokens.star
                                      : DesignTokens.ink2,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
                if (isCompleted && rating == null) ...[
                  const SizedBox(height: 16),
                  SunButton(
                    label: "Rate Driver",
                    icon: Icons.star_outline_rounded,
                    onPressed: onRate,
                  ),
                ],
                if (isCompleted || isCancelled) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (isCompleted) ...[
                        Expanded(
                          child: SunButton(
                            label: "Save to Favorites",
                            icon: Icons.bookmark_border_rounded,
                            tone: SunTone.outline,
                            height: 48,
                            fontSize: 14,
                            onPressed: onSaveFavorite,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: SunButton(
                          label: "Book Again",
                          icon: Icons.replay_rounded,
                          tone: SunTone.soft,
                          height: 48,
                          fontSize: 14,
                          onPressed: onBookAgain,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Center(
                  child: SunLink(
                    label: "Report a problem with this ride",
                    color: DesignTokens.ink2,
                    onTap: onReport,
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
