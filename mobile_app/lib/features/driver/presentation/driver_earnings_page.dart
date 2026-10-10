import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../../../core/utils/ride_format.dart";
import "driver_ride_controller.dart";

enum _Period { today, week, month }

/// Earnings tab: Today / This week / This month, a tappable 7-day chart,
/// cancellation rate, lifetime totals, the next milestone and the latest
/// paid trips. All figures come from GET /driver/earnings, which totals
/// the rider's completed bookings.
class DriverEarningsPage extends StatefulWidget {
  const DriverEarningsPage({super.key});

  @override
  State<DriverEarningsPage> createState() => _DriverEarningsPageState();
}

class _DriverEarningsPageState extends State<DriverEarningsPage> {
  _Period _period = _Period.week;
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    final summary = ctrl.earningsSummary ?? {};
    final performance = ctrl.performanceStats ?? {};
    final top = MediaQuery.paddingOf(context).top;

    final today = _Totals.from(summary["today"]);
    final week = _Totals.from(summary["week"]);
    final month = _Totals.from(summary["month"]);
    final daily =
        (summary["daily"] is List ? summary["daily"] as List : const [])
            .map((e) => _Totals.from(e, withDate: true))
            .toList();

    final totalRides = toInt(summary["total_rides"]);
    final totalEarnings = toDouble(summary["total_earnings"]);
    final ratingAvg = toDouble(summary["rating_avg"]);
    final cancellationRate = toDouble(performance["cancellationRate"]);
    final fiveStarRatings = toInt(performance["fiveStarRatings"]);
    final completedRides = toInt(performance["completedRides"]);
    final recentTrips = ctrl.completedRides.take(10).toList();

    final (label, period) = switch (_period) {
      _Period.today => ("Today", today),
      _Period.week => ("This week", week),
      _Period.month => ("This month", month),
    };

    // Next milestone: the first one above the rider's completed trips.
    final done = completedRides > totalRides ? completedRides : totalRides;
    const milestones = [10, 50, 100, 150, 250, 500, 1000, 2000, 5000];
    final next = milestones.firstWhere((m) => m > done,
        orElse: () => ((done ~/ 1000) + 1) * 1000);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          ctrl.refreshEarnings(),
          ctrl.refreshPerformance(),
          ctrl.refreshProfile(notify: false),
        ]),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
              20, top + 28, 20, DesignTokens.tabBarClearance + 8),
          children: [
            const ScreenTitle("Earnings"),
            const SizedBox(height: 16),
            Segmented<_Period>(
              semanticLabel: "Period",
              height: 40,
              value: _period,
              onChanged: (p) => setState(() => _period = p),
              options: const [
                (_Period.today, "Today", null),
                (_Period.week, "This week", null),
                (_Period.month, "This month", null),
              ],
            ),
            const SizedBox(height: 16),
            ...Stagger.wrap([
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Overline("$label · cash"),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: DesignTokens.quick,
                      child: Text(
                        peso(period.earnings),
                        key: ValueKey(_period),
                        style: TextStyle(
                          color: DesignTokens.ink,
                          fontSize: 42,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2.1,
                          fontFeatures: DesignTokens.tabular,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      period.rides == 1
                          ? "1 ride completed"
                          : "${period.rides} rides completed",
                      style: TextStyle(
                          color: DesignTokens.ink2, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              _DailyChart(
                days: daily,
                selected: _selectedDay,
                onSelect: (i) => setState(() => _selectedDay = i),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Tile(
                      label: "Cancellation rate",
                      value:
                          "${cancellationRate.toStringAsFixed(cancellationRate == cancellationRate.roundToDouble() ? 0 : 1)}%",
                      caption: "Lower is better",
                      tinted: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Tile(
                      label: "Lifetime",
                      value: peso(totalEarnings),
                      caption: "$totalRides trips",
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      label: "Average rating",
                      value: ratingAvg == 0
                          ? "—"
                          : "★ ${ratingAvg.toStringAsFixed(2)}",
                      caption: "$fiveStarRatings five-star",
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Tile(
                      label: "Average per ride",
                      value: totalRides > 0
                          ? peso(totalEarnings / totalRides)
                          : "—",
                      caption: "Cash",
                    ),
                  ),
                ],
              ),
              SunCard(
                radius: 20,
                shadow: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text("Next milestone: $next trips",
                              style: TextStyle(
                                  color: DesignTokens.ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Text("$done / $next",
                            style: TextStyle(
                                color: DesignTokens.ink2,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFeatures: DesignTokens.tabular)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      label: "Milestone progress",
                      value: "$done of $next",
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 8,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                  child:
                                      ColoredBox(color: DesignTokens.surface2)),
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                    end: next == 0
                                        ? 0
                                        : (done / next).clamp(0.0, 1.0)),
                                duration: const Duration(milliseconds: 700),
                                curve: DesignTokens.easeOut,
                                builder: (_, v, __) => FractionallySizedBox(
                                  widthFactor: v,
                                  child: Container(
                                      decoration: const BoxDecoration(
                                          gradient: DesignTokens.hot)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ], gap: 14),
            const SizedBox(height: 24),
            const SectionLabel("Completed rides"),
            if (recentTrips.isEmpty)
              const EmptyState(
                icon: Icons.check_circle_outline_rounded,
                message: "No completed rides yet",
              )
            else
              SunListCard(children: [
                for (final ride in recentTrips) _TripEarningTile(ride: ride),
              ]),
            const SizedBox(height: 16),
            Text(
              "Cash payment is collected directly from passengers.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: DesignTokens.ink2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _Totals {
  const _Totals({required this.rides, required this.earnings, this.date});

  final int rides;
  final double earnings;
  final DateTime? date;

  static _Totals from(dynamic raw, {bool withDate = false}) {
    final map = raw is Map ? raw : const {};
    return _Totals(
      rides: toInt(map["rides"]),
      earnings: toDouble(map["earnings"]),
      date: withDate ? DateTime.tryParse(map["date"]?.toString() ?? "") : null,
    );
  }
}

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

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.caption,
    this.tinted = false,
  });

  final String label;
  final String value;
  final String caption;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    color: tinted ? DesignTokens.lagoonText : DesignTokens.ink,
                    fontSize: 18,
                    height: 1.2,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: DesignTokens.tabular)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: DesignTokens.ink2, fontSize: 11.5)),
          Text(caption,
              style: TextStyle(
                  color: DesignTokens.ink2.withValues(alpha: .8),
                  fontSize: 11)),
        ],
      ),
    );
  }
}

/// Last 7 days as bars; tap a bar to read its amount.
class _DailyChart extends StatelessWidget {
  const _DailyChart(
      {required this.days, required this.selected, required this.onSelect});

  final List<_Totals> days;
  final int? selected;
  final ValueChanged<int> onSelect;

  static const double _maxBarHeight = 140;

  @override
  Widget build(BuildContext context) {
    final maxEarning =
        days.fold<double>(0, (m, d) => d.earnings > m ? d.earnings : m);
    final total = days.fold<double>(0, (sum, d) => sum + d.earnings);
    final sel = days.isEmpty
        ? null
        : (selected ?? days.length - 1).clamp(0, days.length - 1);

    String dayLabel(int i) {
      final date = days[i].date;
      if (i == days.length - 1) return "Today";
      return date == null ? "" : _weekdays[date.weekday - 1];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("Last 7 days",
                    style: TextStyle(
                        color: DesignTokens.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              if (sel != null)
                Text("${dayLabel(sel)} · ${peso(days[sel].earnings)}",
                    style: TextStyle(
                        color: DesignTokens.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: DesignTokens.tabular)),
            ],
          ),
          const SizedBox(height: 2),
          Text("Kabuuan: ${peso(total)}",
              style: TextStyle(
                  color: DesignTokens.ink2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: _maxBarHeight + 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == sel,
                      label: "${dayLabel(i)}, ${peso(days[i].earnings)}",
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(i),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: maxEarning > 0
                                  ? (days[i].earnings / maxEarning) *
                                      _maxBarHeight
                                  : 0,
                            ),
                            duration: Duration(milliseconds: 700 + i * 50),
                            curve: DesignTokens.easeOut,
                            builder: (_, h, __) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedOpacity(
                                  duration: DesignTokens.quick,
                                  opacity: i == sel ? 1 : 0,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: DesignTokens.pillBg,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: DesignTokens.shadow1,
                                    ),
                                    child: FittedBox(
                                      child: Text(
                                          "₱${days[i].earnings.toStringAsFixed(0)}",
                                          style: DesignTokens.mono
                                              .copyWith(fontSize: 11)),
                                    ),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: DesignTokens.quick,
                                  // A sliver even on empty days so the axis
                                  // reads as a chart.
                                  height: h < 4 ? 4 : h,
                                  decoration: BoxDecoration(
                                    color: i == sel && days[i].earnings > 0
                                        ? null
                                        : DesignTokens.surface3,
                                    gradient: i == sel && days[i].earnings > 0
                                        ? DesignTokens.hot
                                        : null,
                                    border: i == sel
                                        ? null
                                        : Border.all(color: DesignTokens.line),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(9),
                                        bottom: Radius.circular(5)),
                                    boxShadow: i == sel
                                        ? [
                                            BoxShadow(
                                                color: DesignTokens.glowEmber,
                                                blurRadius: 22,
                                                spreadRadius: -8,
                                                offset: const Offset(0, 10)),
                                          ]
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dayLabel(i),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: DesignTokens.fontMono,
                      fontSize: 10,
                      letterSpacing: .6,
                      color: i == sel ? DesignTokens.ink : DesignTokens.ink2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
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
    final fare = toDouble(ride["final_fare"] ?? ride["estimated_fare"]);
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconTile(
            icon: Icons.payments_outlined,
            size: 40,
            radius: 12,
            iconSize: 18,
            background: DesignTokens.lagoonSoft,
            foreground: DesignTokens.lagoonText,
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
                    color: DesignTokens.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
                  style: TextStyle(
                      color: DesignTokens.ink2,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            peso(fare),
            style: TextStyle(
              color: DesignTokens.lagoonText,
              fontWeight: FontWeight.w700,
              fontFeatures: DesignTokens.tabular,
            ),
          ),
        ],
      ),
    );
  }
}
