import "package:flutter/material.dart";
import "package:latlong2/latlong.dart" as ll;
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/network/api_client.dart";
import "../../../../core/theme/design_tokens.dart";
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
    final dropoffAddress = _placeLabel(ride["dropoff_address"]);
    final lat = double.tryParse(ride["dropoff_lat"]?.toString() ?? "");
    final lng = double.tryParse(ride["dropoff_lng"]?.toString() ?? "");

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Walang naka-save na destinasyon ang biyaheng ito.")),
      );
      return;
    }

    final controller = TextEditingController(
      text: dropoffAddress == _pinnedLabel ? "" : dropoffAddress,
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
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
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
              : (profileController.favoritesError ?? "Hindi na-save ang favorite."),
        ),
      ),
    );
  }

  void _bookAgain(Map<String, dynamic> ride) {
    final lat = double.tryParse(ride["dropoff_lat"]?.toString() ?? "");
    final lng = double.tryParse(ride["dropoff_lng"]?.toString() ?? "");

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Walang naka-save na destinasyon ang biyaheng ito.")),
      );
      return;
    }

    final address = ride["dropoff_address"]?.toString();
    context.read<PassengerRideController>().setDestinationFromFavorite(
          ll.LatLng(lat, lng),
          // Coordinate-only addresses get re-geocoded on the map.
          address: _looksLikeCoordinates(address) ? null : address,
        );
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
          child: RatingPage(bookingId: bookingId),
        ),
      ),
    );
    if (rated == true) await controller.loadBookingHistory();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PassengerRideController>();
    final allRides = ctrl.bookingHistory;
    final rides = switch (_filter) {
      _HistoryFilter.all => allRides,
      _HistoryFilter.completed =>
        allRides.where((r) => r["status"] == "completed").toList(),
      _HistoryFilter.cancelled =>
        allRides.where((r) => r["status"] == "cancelled").toList(),
    };
    final stats = ctrl.historyStats;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: ctrl.loadBookingHistory,
        child: Container(
          color: DesignTokens.bg,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            children: [
              Text(
                "Ride History",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: DesignTokens.text),
              ),
              const SizedBox(height: DesignTokens.spacing12),
              _SummaryCard(
                completed: _int(stats["completed"]),
                cancelled: _int(stats["cancelled"]),
                totalSpent: _double(stats["totalSpent"]),
              ),
              const SizedBox(height: DesignTokens.spacing12),
              Wrap(
                spacing: 8,
                children: [
                  for (final (filter, label) in const [
                    (_HistoryFilter.all, "Lahat"),
                    (_HistoryFilter.completed, "Natapos"),
                    (_HistoryFilter.cancelled, "Kinansela"),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacing12),
              if (ctrl.historyError != null && allRides.isEmpty)
                AppCard(
                  child: Column(
                    children: [
                      Text(ctrl.historyError!, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: DesignTokens.spacing8),
                      AppButton(label: "Subukan ulit", onPressed: ctrl.loadBookingHistory),
                    ],
                  ),
                )
              else if (ctrl.isLoadingHistory && allRides.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (rides.isEmpty)
                _EmptyState(filter: _filter)
              else ...[
                ...rides.map((ride) => _RideHistoryCard(
                      ride: ride,
                      onSaveFavorite: () => _saveAsFavorite(ride),
                      onBookAgain: () => _bookAgain(ride),
                      onRate: () => _rate(ride),
                    )),
                if (ctrl.historyHasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton(
                      onPressed: ctrl.isLoadingMoreHistory ? null : ctrl.loadMoreHistory,
                      child: ctrl.isLoadingMoreHistory
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Ipakita pa"),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── helpers ─────────────────────────────────────────────────────────────

int _int(dynamic v) => int.tryParse(v?.toString() ?? "") ?? 0;
double _double(dynamic v) => double.tryParse(v?.toString() ?? "") ?? 0;
String _peso(double v) => "₱${v.toStringAsFixed(2)}";

const _pinnedLabel = "Naka-pin sa mapa";
final _coordinatePattern = RegExp(r"^\s*-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+\s*$");

bool _looksLikeCoordinates(String? text) =>
    text != null && _coordinatePattern.hasMatch(text);

/// Older bookings stored raw coordinates as the address; show those as a
/// pinned spot instead of a string of numbers.
String _placeLabel(dynamic raw) {
  final text = raw?.toString().trim();
  if (text == null || text.isEmpty || _looksLikeCoordinates(text)) return _pinnedLabel;
  return text;
}

const _months = [
  "Ene", "Peb", "Mar", "Abr", "May", "Hun",
  "Hul", "Ago", "Set", "Okt", "Nob", "Dis",
];

String? _formatDateTime(dynamic raw) {
  final date = DateTime.tryParse(raw?.toString() ?? "")?.toLocal();
  if (date == null) return null;
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, "0");
  final period = date.hour < 12 ? "AM" : "PM";
  return "${_months[date.month - 1]} ${date.day}, ${date.year} • $hour:$minute $period";
}

(String, Color) _statusStyle(String status) => switch (status) {
      "completed" => ("NATAPOS", DesignTokens.green),
      "cancelled" => ("KINANSELA", DesignTokens.red),
      "ongoing" || "on_ride" => ("NASA BIYAHE", DesignTokens.blue),
      "accepted" || "assigned" || "arriving" => ("PAPUNTA ANG RIDER", DesignTokens.blue),
      _ => ("NAGHAHANAP", DesignTokens.warning),
    };

// ── widgets ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E8C46), Color(0xFF136F3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Row(
        children: [
          stat("$completed", "Natapos"),
          stat("$cancelled", "Kinansela"),
          stat(_peso(totalSpent), "Kabuuang gastos"),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final _HistoryFilter filter;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      _HistoryFilter.all => "Wala ka pang biyahe. Mag-book mula sa mapa para makita ito rito.",
      _HistoryFilter.completed => "Wala pang natapos na biyahe.",
      _HistoryFilter.cancelled => "Walang kinanselang biyahe.",
    };
    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.history_rounded, size: 42, color: DesignTokens.muted),
          const SizedBox(height: DesignTokens.spacing12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RideHistoryCard extends StatelessWidget {
  const _RideHistoryCard({
    required this.ride,
    required this.onSaveFavorite,
    required this.onBookAgain,
    required this.onRate,
  });

  final Map<String, dynamic> ride;
  final VoidCallback onSaveFavorite;
  final VoidCallback onBookAgain;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final status = ride["status"]?.toString() ?? "";
    final isCompleted = status == "completed";
    final isCancelled = status == "cancelled";
    final (statusLabel, statusColor) = _statusStyle(status);

    final when = _formatDateTime(
      isCompleted ? ride["completed_at"] ?? ride["requested_at"] : ride["requested_at"],
    );
    final distance = double.tryParse(ride["distance_km"]?.toString() ?? "");
    final finalFare = double.tryParse(ride["final_fare"]?.toString() ?? "");
    final estimate = double.tryParse(ride["estimated_fare"]?.toString() ?? "");
    final riderName = ride["driver_name"]?.toString();
    final tricycle = ride["tricycle_number"]?.toString();
    final rating = int.tryParse(ride["rating"]?.toString() ?? "");
    final cancelledBy = ride["cancelled_by"]?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spacing12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    when ?? "Ride #${ride["id"]}",
                    style: const TextStyle(
                      color: DesignTokens.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _RoutePoint(
              icon: Icons.trip_origin_rounded,
              color: DesignTokens.green,
              text: _placeLabel(ride["pickup_address"]),
            ),
            const SizedBox(height: 4),
            _RoutePoint(
              icon: Icons.location_on_rounded,
              color: DesignTokens.red,
              text: _placeLabel(ride["dropoff_address"]),
            ),
            if (riderName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.pedal_bike_rounded, size: 16, color: DesignTokens.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tricycle == null ? riderName : "$riderName • $tricycle",
                      style: const TextStyle(color: DesignTokens.muted, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      if (distance != null) "${distance.toStringAsFixed(1)} km",
                      "Ride #${ride["id"]}",
                    ].join(" • "),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: DesignTokens.muted, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                if (isCompleted)
                  Text(
                    _peso(finalFare ?? estimate ?? 0),
                    style: const TextStyle(
                      color: Color(0xFF0E8C46),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                else if (isCancelled)
                  Text(
                    // Nothing was charged for a cancelled ride.
                    cancelledBy == "driver" ? "Kinansela ng rider" : "Walang bayad",
                    style: const TextStyle(color: DesignTokens.muted, fontSize: 12),
                  )
                else if (estimate != null)
                  Text(
                    "Tantiya ${_peso(estimate)}",
                    style: const TextStyle(color: DesignTokens.muted, fontSize: 12),
                  ),
              ],
            ),
            if (isCompleted) ...[
              const SizedBox(height: 8),
              if (rating != null)
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(
                        i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 18,
                        color: Colors.amber,
                      ),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        "Na-rate mo na",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: DesignTokens.muted, fontSize: 12),
                      ),
                    ),
                  ],
                )
              else
                TextButton.icon(
                  onPressed: onRate,
                  icon: const Icon(Icons.star_outline_rounded, color: Colors.amber),
                  label: const Text("I-rate ang rider"),
                ),
            ],
            if (isCompleted || isCancelled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (isCompleted) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSaveFavorite,
                        icon: const Icon(Icons.star_border_rounded, size: 18),
                        label: const Text("Favorite"),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: AppButton(label: "Book Again", onPressed: onBookAgain),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: text == _pinnedLabel ? DesignTokens.muted : DesignTokens.text,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
