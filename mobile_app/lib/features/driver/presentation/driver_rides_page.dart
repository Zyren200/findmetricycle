import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../../../core/utils/ride_format.dart";
import "driver_ride_controller.dart";

/// Index of this page in the driver shell's bottom navigation.
const int _ridesTabIndex = 1;

enum _RideFilter { all, completed, cancelled }

/// Rides tab: the rider's trip history — completed and cancelled — with
/// totals, filters, the passenger's rating and paging.
class DriverRidesPage extends StatefulWidget {
  const DriverRidesPage({super.key});

  @override
  State<DriverRidesPage> createState() => _DriverRidesPageState();
}

class _DriverRidesPageState extends State<DriverRidesPage> {
  ValueNotifier<int>? _navIndex;
  _RideFilter _filter = _RideFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DriverRideController>().loadRideHistory();
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

  // Tabs stay alive in the shell's IndexedStack — reload on open so the
  // latest trip is always there.
  void _onTabChanged() {
    if (_navIndex?.value == _ridesTabIndex && mounted) {
      context.read<DriverRideController>().loadRideHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    final all = ctrl.rideHistory;
    final rides = switch (_filter) {
      _RideFilter.all => all,
      _RideFilter.completed =>
        all.where((r) => r["status"] == "completed").toList(),
      _RideFilter.cancelled =>
        all.where((r) => r["status"] == "cancelled").toList(),
    };
    final stats = ctrl.rideHistoryStats;

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          const AppTopBar(title: "Ride History"),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadRideHistory,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _SummaryRow(
                      completed: toInt(stats["completed"]),
                      cancelled: toInt(stats["cancelled"]),
                      totalEarned: toDouble(stats["totalEarned"]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final (filter, label) in const [
                          (_RideFilter.all, "All"),
                          (_RideFilter.completed, "Completed"),
                          (_RideFilter.cancelled, "Cancelled"),
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
                  if (ctrl.rideHistoryError != null && all.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ErrorBox(
                        message: ctrl.rideHistoryError!,
                        onRetry: ctrl.loadRideHistory,
                      ),
                    )
                  else if (ctrl.isLoadingRideHistory && all.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (rides.isEmpty)
                    EmptyState(
                      icon: Icons.schedule_rounded,
                      message: switch (_filter) {
                        _RideFilter.all => "No ride history yet",
                        _RideFilter.completed => "No completed rides yet",
                        _RideFilter.cancelled => "No cancelled rides",
                      },
                    )
                  else ...[
                    for (final ride in rides) _RideRow(ride: ride),
                    if (ctrl.rideHistoryHasMore)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton(
                          onPressed: ctrl.isLoadingMoreRideHistory
                              ? null
                              : ctrl.loadMoreRideHistory,
                          child: ctrl.isLoadingMoreRideHistory
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.completed,
    required this.cancelled,
    required this.totalEarned,
  });

  final int completed;
  final int cancelled;
  final double totalEarned;

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
        stat(peso(totalEarned), "Total earned"),
      ],
    );
  }
}

/// One trip: status icon, destination and fare, pickup, then passenger,
/// count, date and the passenger's rating.
class _RideRow extends StatelessWidget {
  const _RideRow({required this.ride});

  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final status = ride["status"]?.toString() ?? "";
    final isCompleted = status == "completed";
    final cancelledBy = ride["cancelled_by"]?.toString();
    final (IconData icon, Color color, String note) = isCompleted
        ? (Icons.check_circle_outline_rounded, DesignTokens.green, "")
        : cancelledBy == "driver"
            ? (
                Icons.person_off_outlined,
                DesignTokens.warning,
                "Passenger no-show"
              )
            : (Icons.close_rounded, DesignTokens.red, "Cancelled by passenger");

    final when = formatRideDateTime(
      ride["completed_at"] ?? ride["cancelled_at"] ?? ride["requested_at"],
    );
    final passenger = ride["passenger_name"]?.toString() ?? "Passenger";
    final passengers = toInt(ride["passenger_count"]);
    final distance = double.tryParse(ride["distance_km"]?.toString() ?? "");
    final fare = toDouble(ride["final_fare"] ?? ride["estimated_fare"]);
    final rating = int.tryParse(ride["passenger_rating"]?.toString() ?? "");
    final feedback = ride["passenger_feedback"]?.toString().trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: DesignTokens.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: color),
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
                    const SizedBox(width: 8),
                    Text(
                      isCompleted ? peso(fare) : note,
                      style: TextStyle(
                        color: isCompleted
                            ? DesignTokens.green
                            : DesignTokens.muted,
                        fontSize: isCompleted ? 14 : 11,
                        fontWeight: isCompleted
                            ? DesignTokens.fw700
                            : DesignTokens.fw500,
                      ),
                    ),
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
                        style:
                            TextStyle(color: DesignTokens.muted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    passenger,
                    if (passengers > 0) "$passengers pax",
                    if (distance != null) "${distance.toStringAsFixed(1)} km",
                    if (when != null) when,
                  ].join(" · "),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: DesignTokens.muted, fontSize: 11),
                ),
                if (isCompleted && rating != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 14,
                          color:
                              i <= rating ? Colors.amber : DesignTokens.muted,
                        ),
                    ],
                  ),
                  if (feedback != null && feedback.isNotEmpty)
                    Text(
                      "“$feedback”",
                      style: TextStyle(
                        color: DesignTokens.text,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
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
