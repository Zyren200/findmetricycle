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
import "../passenger_profile_controller.dart";
import "../passenger_ride_controller.dart";

/// Index of this page in the passenger shell's bottom navigation.
const int _historyTabIndex = 1;

enum _HistoryFilter { all, completed, cancelled }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Walang naka-save na destinasyon ang biyaheng ito.")),
      );
      return;
    }

    final controller = TextEditingController(
      text: dropoffAddress == kPinnedPlaceLabel ? "" : dropoffAddress,
    );
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("I-save sa Favorites"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Pangalan",
            hintText: "hal. Bahay, Trabaho, Palengke",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? "Na-save sa Favorites."
              : (profileController.favoritesError ??
                  "Hindi na-save ang favorite."),
        ),
      ),
    );
  }

  void _bookAgain(Map<String, dynamic> ride) {
    final lat = double.tryParse(ride["dropoff_lat"]?.toString() ?? "");
    final lng = double.tryParse(ride["dropoff_lng"]?.toString() ?? "");

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Walang naka-save na destinasyon ang biyaheng ito.")),
      );
      return;
    }

    final address = ride["dropoff_address"]?.toString();
    final rideController = context.read<PassengerRideController>();
    if (!rideController.setDestinationFromFavorite(
      ll.LatLng(lat, lng),
      // Coordinate-only addresses get re-geocoded on the map.
      address: looksLikeCoordinates(address) ? null : address,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(rideController.error ?? "")),
      );
      return;
    }
    context.read<ValueNotifier<int>>().value = 0;
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

  /// The ride open in the details view (Figma "Ride Details"), by id so
  /// it stays current across history reloads.
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

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          const AppTopBar(title: "My Rides"),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadBookingHistory,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _SummaryRow(
                      completed: toInt(stats["completed"]),
                      cancelled: toInt(stats["cancelled"]),
                      totalSpent: toDouble(stats["totalSpent"]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final (filter, label) in const [
                          (_HistoryFilter.all, "All"),
                          (_HistoryFilter.completed, "Completed"),
                          (_HistoryFilter.cancelled, "Cancelled"),
                        ])
                          ChoiceChip(
                            label: Text(label),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (ctrl.historyError != null && allRides.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ErrorBox(
                        message: ctrl.historyError!,
                        onRetry: ctrl.loadBookingHistory,
                      ),
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
                        _HistoryFilter.all => "No ride history yet",
                        _HistoryFilter.completed => "No completed rides yet",
                        _HistoryFilter.cancelled => "No cancelled rides",
                      },
                    )
                  else ...[
                    for (final ride in rides)
                      _RideRow(
                        ride: ride,
                        onTap: () => setState(() => _selectedId = ride["id"]),
                      ),
                    if (ctrl.historyHasMore)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton(
                          onPressed: ctrl.isLoadingMoreHistory
                              ? null
                              : ctrl.loadMoreHistory,
                          child: ctrl.isLoadingMoreHistory
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text("Show more"),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── helpers ─────────────────────────────────────────────────────────────

(String, Color) _statusStyle(String status) => switch (status) {
      "completed" => ("COMPLETED", DesignTokens.green),
      "cancelled" => ("CANCELLED", DesignTokens.red),
      "ongoing" || "on_ride" => ("IN PROGRESS", DesignTokens.blue),
      "accepted" || "assigned" || "arriving" => (
          "DRIVER ON THE WAY",
          DesignTokens.blue
        ),
      _ => ("SEARCHING", DesignTokens.warning),
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
    Widget stat(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DesignTokens.bg2,
              borderRadius: BorderRadius.circular(DesignTokens.radius),
              border: Border.all(color: DesignTokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: DesignTokens.muted, fontSize: 11)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: DesignTokens.text,
                      fontSize: 18,
                      fontWeight: DesignTokens.fw700,
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
        stat(peso(totalSpent), "Total spent"),
      ],
    );
  }
}

/// One ride in the list: status icon, destination, fare, pickup, meta.
class _RideRow extends StatelessWidget {
  const _RideRow({required this.ride, required this.onTap});

  final Map<String, dynamic> ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = ride["status"]?.toString() ?? "";
    final (statusLabel, statusColor) = _statusStyle(status);
    final fare = _rideFare(ride);
    final pax = int.tryParse(ride["passenger_count"]?.toString() ?? "");
    final icon = switch (status) {
      "completed" => Icons.check_circle_outline_rounded,
      "cancelled" => Icons.close_rounded,
      _ => Icons.schedule_rounded,
    };

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: DesignTokens.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 20, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          placeLabel(ride["dropoff_address"]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: DesignTokens.text,
                            fontSize: 14,
                            fontWeight: DesignTokens.fw600,
                          ),
                        ),
                      ),
                      if (fare != null && status != "cancelled") ...[
                        const SizedBox(width: 8),
                        Text(
                          peso(fare),
                          style: TextStyle(
                            color: DesignTokens.text,
                            fontSize: 14,
                            fontWeight: DesignTokens.fw700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: DesignTokens.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          placeLabel(ride["pickup_address"]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: DesignTokens.muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(color: DesignTokens.muted, fontSize: 11),
                      children: [
                        TextSpan(
                            text: _rideWhen(ride) ?? "Ride #${ride["id"]}"),
                        if (pax != null) TextSpan(text: "  ·  $pax pax"),
                        const TextSpan(text: "  ·  "),
                        TextSpan(
                            text: statusLabel,
                            style: TextStyle(color: statusColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma "Ride Details": status chip, details box, and the ride's actions.
class _RideDetails extends StatelessWidget {
  const _RideDetails({
    required this.ride,
    required this.onBack,
    required this.onSaveFavorite,
    required this.onBookAgain,
    required this.onRate,
  });

  final Map<String, dynamic> ride;
  final VoidCallback onBack;
  final VoidCallback onSaveFavorite;
  final VoidCallback onBookAgain;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final status = ride["status"]?.toString() ?? "";
    final (statusLabel, statusColor) = _statusStyle(status);
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
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          AppTopBar(title: "Ride Details", showBack: true, onBack: onBack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 13,
                        fontWeight: DesignTokens.fw600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InfoBox(
                  children: [
                    InfoRow(label: "Date", value: _rideWhen(ride) ?? "-"),
                    InfoRow(
                        label: "Pickup",
                        value: placeLabel(ride["pickup_address"])),
                    InfoRow(
                        label: "Destination",
                        value: placeLabel(ride["dropoff_address"])),
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
                    ),
                    InfoRow(label: "Ride #", value: "${ride["id"]}"),
                    if (riderName != null) ...[
                      const InfoDivider(),
                      InfoRow(label: "Driver", value: riderName),
                      if (tricycle != null)
                        InfoRow(label: "Tricycle", value: tricycle),
                    ],
                    if (rating != null) ...[
                      const InfoDivider(),
                      Row(
                        children: [
                          Text("Your Rating:",
                              style: TextStyle(
                                  color: DesignTokens.muted, fontSize: 13)),
                          const SizedBox(width: 8),
                          for (var i = 1; i <= 5; i++)
                            Icon(
                              i <= rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 16,
                              color: i <= rating
                                  ? Colors.amber
                                  : DesignTokens.muted,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
                if (isCompleted && rating == null) ...[
                  const SizedBox(height: 16),
                  PrimaryActionButton(
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
                          child: OutlinedButton.icon(
                            onPressed: onSaveFavorite,
                            icon:
                                const Icon(Icons.star_border_rounded, size: 18),
                            label: const Text("Save to Favorites"),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onBookAgain,
                          icon: const Icon(Icons.replay_rounded, size: 18),
                          label: const Text("Book Again"),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
