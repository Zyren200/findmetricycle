import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../../../core/utils/ride_format.dart";
import "driver_ride_controller.dart";
import "driver_shell_page.dart";

enum _RideFilter { all, completed, cancelled }

/// History tab: the rider's trips — completed and cancelled — with totals,
/// filters, the passenger's rating and comment, and paging.
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
    if (_navIndex?.value == kHistoryTab && mounted) {
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
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: ctrl.loadRideHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
              20, top + 28, 20, DesignTokens.tabBarClearance + 8),
          children: [
            const ScreenTitle("Ride history"),
            const SizedBox(height: 16),
            _SummaryRow(
              completed: toInt(stats["completed"]),
              cancelled: toInt(stats["cancelled"]),
              totalEarned: toDouble(stats["totalEarned"]),
            ),
            const SizedBox(height: 16),
            FilterPills<_RideFilter>(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
              options: const [
                (_RideFilter.all, "All"),
                (_RideFilter.completed, "Completed"),
                (_RideFilter.cancelled, "Cancelled"),
              ],
            ),
            const SizedBox(height: 16),
            if (ctrl.rideHistoryError != null && all.isEmpty)
              ErrorBox(
                message: ctrl.rideHistoryError!,
                onRetry: ctrl.loadRideHistory,
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
              ...Stagger.wrap([for (final ride in rides) _RideCard(ride: ride)],
                  gap: 12),
              if (ctrl.rideHistoryHasMore) ...[
                const SizedBox(height: 16),
                SunButton(
                  label: "Show more",
                  tone: SunTone.outline,
                  height: 48,
                  loading: ctrl.isLoadingMoreRideHistory,
                  onPressed: ctrl.loadMoreRideHistory,
                ),
              ],
            ],
          ],
        ),
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
        stat(peso(totalEarned), "Total earned", bg: DesignTokens.lagoonSoft),
      ],
    );
  }
}

/// One trip: when + status, passenger and route, fare, then the rating
/// and comment (or who cancelled).
class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride});

  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final status = ride["status"]?.toString() ?? "";
    final isCompleted = status == "completed";
    final cancelledBy = ride["cancelled_by"]?.toString();
    final note = cancelledBy == "driver"
        ? "Passenger no-show"
        : "Cancelled by passenger";

    final when = formatRideDateTime(
      ride["completed_at"] ?? ride["cancelled_at"] ?? ride["requested_at"],
    );
    final passenger = ride["passenger_name"]?.toString() ?? "Passenger";
    final passengers = toInt(ride["passenger_count"]);
    final distance = double.tryParse(ride["distance_km"]?.toString() ?? "");
    final fare = toDouble(ride["final_fare"] ?? ride["estimated_fare"]);
    final rating = int.tryParse(ride["passenger_rating"]?.toString() ?? "");
    final feedback = ride["passenger_feedback"]?.toString().trim();
    final from = splitPlaceLabel(placeLabel(ride["pickup_address"])).title;
    final to = placeLabel(ride["dropoff_address"]);

    return SunCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(when ?? "Ride #${ride["id"]}",
                    style: TextStyle(
                        color: DesignTokens.ink2,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              StatusChip(isCompleted ? "Completed" : "Cancelled",
                  tone: isCompleted ? ChipTone.ok : ChipTone.cancel),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ToneAvatar(
                  name: passenger, tone: AvatarTone.sand, size: 40, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(to,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: DesignTokens.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    Text("From $from",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: DesignTokens.ink2,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text(
                      [
                        passenger,
                        if (passengers > 0) "$passengers pax",
                        if (distance != null)
                          "${distance.toStringAsFixed(1)} km",
                      ].join(" · "),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: DesignTokens.ink2,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                Text(peso(fare),
                    style: TextStyle(
                        color: DesignTokens.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFeatures: DesignTokens.tabular)),
            ],
          ),
          const SizedBox(height: 12),
          SoftBox(
            radius: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCompleted)
                  Text(note,
                      style: TextStyle(
                          color: DesignTokens.ink2,
                          fontSize: 13,
                          fontWeight: FontWeight.w600))
                else if (rating == null)
                  Text("No rating yet",
                      style: TextStyle(
                          color: DesignTokens.ink2,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))
                else ...[
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
                      const SizedBox(width: 6),
                      Text("$rating star${rating == 1 ? "" : "s"}",
                          style: TextStyle(
                              color: DesignTokens.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (feedback != null && feedback.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      "“$feedback”",
                      style: TextStyle(
                        color: DesignTokens.ink2,
                        fontSize: 13,
                        height: 18 / 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
