import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../../../core/utils/ride_format.dart";
import "driver_ride_controller.dart";

/// Earnings tab: today / this week / this month, a 7-day chart, lifetime
/// totals and the latest paid trips. All figures come from GET
/// /driver/earnings, which totals the rider's completed bookings.
class DriverEarningsPage extends StatelessWidget {
  const DriverEarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    final summary = ctrl.earningsSummary ?? {};
    final performance = ctrl.performanceStats ?? {};

    final today = _Period.from(summary["today"]);
    final week = _Period.from(summary["week"]);
    final month = _Period.from(summary["month"]);
    final daily =
        (summary["daily"] is List ? summary["daily"] as List : const [])
            .map((e) => _Period.from(e, withDate: true))
            .toList();

    final totalRides = _int(summary["total_rides"]);
    final totalEarnings = _double(summary["total_earnings"]);
    final ratingAvg = _double(summary["rating_avg"]);
    final cancellationRate = _double(performance["cancellationRate"]);
    final fiveStarRatings = _int(performance["fiveStarRatings"]);
    final completedRides = _int(performance["completedRides"]);
    final recentTrips = ctrl.completedRides.take(10).toList();

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          const AppTopBar(title: "Earnings"),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => Future.wait([
                ctrl.refreshEarnings(),
                ctrl.refreshPerformance(),
                ctrl.refreshProfile(notify: false),
              ]),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _TodayCard(period: today),
                  Padding(
                    padding: const EdgeInsets.all(DesignTokens.spacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: "This Week",
                                caption: "${week.rides} rides",
                                value: _peso(week.earnings),
                                icon: Icons.trending_up_rounded,
                                color: DesignTokens.driverAccent,
                              ),
                            ),
                            const SizedBox(width: DesignTokens.spacing12),
                            Expanded(
                              child: _StatCard(
                                label: "This Month",
                                caption: "${month.rides} rides",
                                value: _peso(month.earnings),
                                icon: Icons.payments_outlined,
                                color: DesignTokens.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spacing16),
                        const _SectionTitle("Last 7 days"),
                        const SizedBox(height: 10),
                        _DailyChart(days: daily),
                        const SizedBox(height: DesignTokens.spacing16),
                        const _SectionTitle("Lifetime"),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: "Total Earnings",
                                value: _peso(totalEarnings),
                                icon: Icons.payments,
                                color: DesignTokens.driverAccent,
                              ),
                            ),
                            const SizedBox(width: DesignTokens.spacing12),
                            Expanded(
                              child: _StatCard(
                                label: "Total Rides",
                                value: "$totalRides",
                                icon: Icons.route,
                                color: DesignTokens.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spacing12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: "Average Rating",
                                value: ratingAvg.toStringAsFixed(2),
                                icon: Icons.star_rounded,
                                color: DesignTokens.warning,
                              ),
                            ),
                            const SizedBox(width: DesignTokens.spacing12),
                            Expanded(
                              child: _StatCard(
                                label: "Average per Ride",
                                value: totalRides > 0
                                    ? _peso(totalEarnings / totalRides)
                                    : "—",
                                icon: Icons.receipt_long_rounded,
                                color: DesignTokens.driverAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spacing16),
                        const _SectionTitle("Performance"),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: "Cancellation Rate",
                                value:
                                    "${cancellationRate.toStringAsFixed(1)}%",
                                icon: Icons.cancel_outlined,
                                color: cancellationRate > 20
                                    ? DesignTokens.red
                                    : DesignTokens.green,
                              ),
                            ),
                            const SizedBox(width: DesignTokens.spacing12),
                            Expanded(
                              child: _StatCard(
                                label: "5-Star Ratings",
                                value: "$fiveStarRatings",
                                icon: Icons.star_rounded,
                                color: DesignTokens.driverAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spacing16),
                        if (completedRides > 0) ...[
                          const _SectionTitle("Milestones"),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (completedRides >= 100)
                                const _MilestoneBadge(
                                    label: "100 Completed Rides"),
                              if (completedRides >= 500)
                                const _MilestoneBadge(
                                    label: "500 Completed Rides"),
                              if (fiveStarRatings >= 50)
                                const _MilestoneBadge(
                                    label: "50 Five-Star Ratings"),
                              if (completedRides < 100)
                                const _MilestoneBadge(
                                  label: "100 Completed Rides",
                                  achieved: false,
                                ),
                            ],
                          ),
                          const SizedBox(height: DesignTokens.spacing16),
                        ],
                        const _SectionTitle("Completed Rides"),
                        if (recentTrips.isEmpty)
                          const EmptyState(
                            icon: Icons.check_circle_outline_rounded,
                            message: "No completed rides yet",
                          )
                        else
                          ...recentTrips
                              .map((ride) => _TripEarningTile(ride: ride)),
                        const SizedBox(height: DesignTokens.spacing16),
                        Text(
                          "Cash payment is collected directly from passengers.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: DesignTokens.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Period {
  const _Period({required this.rides, required this.earnings, this.date});

  final int rides;
  final double earnings;
  final DateTime? date;

  static _Period from(dynamic raw, {bool withDate = false}) {
    final map = raw is Map ? raw : const {};
    return _Period(
      rides: _int(map["rides"]),
      earnings: _double(map["earnings"]),
      date: withDate ? DateTime.tryParse(map["date"]?.toString() ?? "") : null,
    );
  }
}

int _int(dynamic v) => int.tryParse(v?.toString() ?? "") ?? 0;
double _double(dynamic v) => double.tryParse(v?.toString() ?? "") ?? 0;
String _peso(double v) => "₱${v.toStringAsFixed(2)}";

const _weekdays = ["Lun", "Mar", "Miy", "Huw", "Biy", "Sab", "Lin"];
const _months = [
  "Ene",
  "Peb",
  "Mar",
  "Abr",
  "May",
  "Hun",
  "Hul",
  "Ago",
  "Set",
  "Okt",
  "Nob",
  "Dis",
];

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SectionLabel(text);
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.period});

  final _Period period;

  @override
  Widget build(BuildContext context) {
    final muted = DesignTokens.bg.withAlpha(190);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      color: DesignTokens.driverAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Earnings",
              style: TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            _peso(period.earnings),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: DesignTokens.bg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            period.rides == 1
                ? "1 ride completed"
                : "${period.rides} rides completed",
            style: TextStyle(color: muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Simple bar chart of the last 7 days' earnings (no chart dependency).
class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.days});

  final List<_Period> days;

  static const double _maxBarHeight = 110;

  @override
  Widget build(BuildContext context) {
    final maxEarning =
        days.fold<double>(0, (m, d) => d.earnings > m ? d.earnings : m);
    final total = days.fold<double>(0, (sum, d) => sum + d.earnings);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: DesignTokens.bg2,
        border: Border.all(color: DesignTokens.border),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Kabuuan: ${_peso(total)}",
            style: TextStyle(color: DesignTokens.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _maxBarHeight + 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (index, day) in days.indexed)
                  Expanded(
                    child: _DayBar(
                      day: day,
                      height: maxEarning > 0
                          ? (day.earnings / maxEarning) * _maxBarHeight
                          : 0,
                      isToday: index == days.length - 1,
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

class _DayBar extends StatelessWidget {
  const _DayBar(
      {required this.day, required this.height, required this.isToday});

  final _Period day;
  final double height;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final color = isToday ? DesignTokens.driverAccent : DesignTokens.green;
    final amount = day.earnings >= 1000
        ? "${(day.earnings / 1000).toStringAsFixed(1)}k"
        : day.earnings.toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (day.earnings > 0)
            FittedBox(
              child: Text(
                amount,
                style: TextStyle(fontSize: 10, color: DesignTokens.text),
              ),
            ),
          const SizedBox(height: 2),
          Container(
            // A sliver even on empty days so the axis reads as a chart.
            height: height < 3 ? 3 : height,
            decoration: BoxDecoration(
              color: day.earnings > 0 ? color : DesignTokens.border,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            day.date == null ? "" : _weekdays[day.date!.weekday - 1],
            style: TextStyle(
              fontSize: 11,
              color: isToday ? DesignTokens.text : DesignTokens.muted,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripEarningTile extends StatelessWidget {
  const _TripEarningTile({required this.ride});

  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final fare = _double(ride["final_fare"] ?? ride["estimated_fare"]);
    final pickup = placeLabel(ride["pickup_address"]);
    final dropoff = placeLabel(ride["dropoff_address"]);
    final distance = double.tryParse(ride["distance_km"]?.toString() ?? "");
    final completed =
        DateTime.tryParse(ride["completed_at"]?.toString() ?? "")?.toLocal();
    final when = completed == null
        ? ""
        : "${_months[completed.month - 1]} ${completed.day}, "
            "${completed.hour.toString().padLeft(2, "0")}:${completed.minute.toString().padLeft(2, "0")}";
    final pax = ride["passenger_count"]?.toString();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: DesignTokens.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DesignTokens.green.withAlpha(36),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payments_outlined,
                size: 18, color: DesignTokens.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dropoff,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: DesignTokens.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  [
                    "From $pickup",
                    if (pax != null) "$pax pax",
                    if (distance != null) "${distance.toStringAsFixed(1)} km",
                    if (when.isNotEmpty) when,
                  ].join(" · "),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: DesignTokens.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _peso(fare),
            style: TextStyle(
              color: DesignTokens.green,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneBadge extends StatelessWidget {
  const _MilestoneBadge({required this.label, this.achieved = true});

  final String label;
  final bool achieved;

  @override
  Widget build(BuildContext context) {
    final color = achieved ? DesignTokens.driverAccent : DesignTokens.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            achieved ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.bg2,
        border: Border.all(color: DesignTokens.border),
        borderRadius: BorderRadius.circular(DesignTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: TextStyle(color: DesignTokens.muted, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: DesignTokens.text,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!,
                style: TextStyle(color: DesignTokens.muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
