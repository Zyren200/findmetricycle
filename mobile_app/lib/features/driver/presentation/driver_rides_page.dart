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
      _RideFilter.completed => all.where((r) => r["status"] == "completed").toList(),
      _RideFilter.cancelled => all.where((r) => r["status"] == "cancelled").toList(),
    };
    final stats = ctrl.rideHistoryStats;

    return Scaffold(
      appBar: const AppAppBar(title: "My Rides"),
      body: Container(
        color: DesignTokens.bg,
        child: RefreshIndicator(
          onRefresh: ctrl.loadRideHistory,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            children: [
              _SummaryCard(
                completed: toInt(stats["completed"]),
                cancelled: toInt(stats["cancelled"]),
                totalEarned: toDouble(stats["totalEarned"]),
              ),
              const SizedBox(height: DesignTokens.spacing12),
              Wrap(
                spacing: 8,
                children: [
                  for (final (filter, label) in const [
                    (_RideFilter.all, "Lahat"),
                    (_RideFilter.completed, "Natapos"),
                    (_RideFilter.cancelled, "Kinansela"),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacing12),
              if (ctrl.rideHistoryError != null && all.isEmpty)
                AppCard(
                  child: Column(
                    children: [
                      Text(
                        ctrl.rideHistoryError!,
                        style: const TextStyle(color: DesignTokens.text),
                      ),
                      const SizedBox(height: DesignTokens.spacing8),
                      AppButton(label: "Subukan ulit", onPressed: ctrl.loadRideHistory),
                    ],
                  ),
                )
              else if (ctrl.isLoadingRideHistory && all.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (rides.isEmpty)
                AppCard(
                  child: Text(
                    switch (_filter) {
                      _RideFilter.all =>
                        "Wala ka pang biyahe. Mag-online para makatanggap ng ride requests.",
                      _RideFilter.completed => "Wala pang natapos na biyahe.",
                      _RideFilter.cancelled => "Walang kinanselang biyahe.",
                    },
                    style: const TextStyle(color: DesignTokens.muted),
                  ),
                )
              else ...[
                ...rides.map((ride) => _RideCard(ride: ride)),
                if (ctrl.rideHistoryHasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton(
                      onPressed:
                          ctrl.isLoadingMoreRideHistory ? null : ctrl.loadMoreRideHistory,
                      child: ctrl.isLoadingMoreRideHistory
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: DesignTokens.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: DesignTokens.muted, fontSize: 12)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.driverAccent.withAlpha(28),
        border: Border.all(color: DesignTokens.driverAccent.withAlpha(70)),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Row(
        children: [
          stat("$completed", "Natapos"),
          stat("$cancelled", "Kinansela"),
          stat(peso(totalEarned), "Kabuuang kita"),
        ],
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride});

  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final status = ride["status"]?.toString() ?? "";
    final isCompleted = status == "completed";
    final cancelledBy = ride["cancelled_by"]?.toString();
    final (statusLabel, statusColor) = isCompleted
        ? ("NATAPOS", DesignTokens.green)
        : cancelledBy == "driver"
            ? ("NO-SHOW", DesignTokens.warning)
            : ("KINANSELA", DesignTokens.red);

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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.bg2,
        border: Border.all(color: DesignTokens.border),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
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
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 16, color: DesignTokens.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  passengers > 1 ? "$passenger (+${passengers - 1} kasama)" : passenger,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DesignTokens.text, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _RoutePoint(
            icon: Icons.trip_origin_rounded,
            color: DesignTokens.green,
            text: placeLabel(ride["pickup_address"]),
          ),
          const SizedBox(height: 4),
          _RoutePoint(
            icon: Icons.location_on_rounded,
            color: DesignTokens.red,
            text: placeLabel(ride["dropoff_address"]),
          ),
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
                  "+${peso(fare)}",
                  style: const TextStyle(
                    color: DesignTokens.green,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                )
              else
                Flexible(
                  child: Text(
                    cancelledBy == "driver"
                        ? "Walang dumating na pasahero"
                        : "Kinansela ng pasahero",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: DesignTokens.muted, fontSize: 12),
                  ),
                ),
            ],
          ),
          if (isCompleted) ...[
            const SizedBox(height: 8),
            if (rating != null) ...[
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
                      "Rating ng pasahero",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: DesignTokens.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (feedback != null && feedback.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  "“$feedback”",
                  style: const TextStyle(
                    color: DesignTokens.text,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ],
            ] else
              const Text(
                "Wala pang rating mula sa pasahero",
                style: TextStyle(color: DesignTokens.muted, fontSize: 12),
              ),
          ],
        ],
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
              color: text == kPinnedPlaceLabel ? DesignTokens.muted : DesignTokens.text,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
