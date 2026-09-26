import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "driver_ride_controller.dart";

/// Earnings tab. The backend currently only exposes a lifetime summary
/// (GET /driver/earnings: total_rides, total_earnings, rating_avg) — daily
/// / weekly / monthly breakdowns are Phase 7 scope, so this stays a
/// simple summary for now rather than fabricating numbers the API doesn't
/// provide.
class DriverEarningsPage extends StatelessWidget {
  const DriverEarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    final summary = ctrl.earningsSummary ?? {};
    final performance = ctrl.performanceStats ?? {};
    final totalRides = summary["total_rides"]?.toString() ?? "0";
    final totalEarnings =
        double.tryParse(summary["total_earnings"]?.toString() ?? "") ?? 0;
    final ratingAvg =
        double.tryParse(summary["rating_avg"]?.toString() ?? "") ?? 0;
    final cancellationRate =
        double.tryParse(performance["cancellationRate"]?.toString() ?? "") ?? 0;
    final fiveStarRatings =
        int.tryParse(performance["fiveStarRatings"]?.toString() ?? "") ?? 0;
    final completedRides =
        int.tryParse(performance["completedRides"]?.toString() ?? "0") ?? 0;

    return Scaffold(
      appBar: const AppAppBar(title: "Earnings"),
      body: Container(
        color: DesignTokens.bg,
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            ctrl.refreshEarnings(),
            ctrl.refreshPerformance(),
          ]),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: "Total Earnings",
                      value: "PHP ${totalEarnings.toStringAsFixed(2)}",
                      icon: Icons.payments,
                      color: DesignTokens.driverAccent,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing12),
                  Expanded(
                    child: _StatCard(
                      label: "Total Rides",
                      value: totalRides,
                      icon: Icons.route,
                      color: DesignTokens.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacing12),
              _StatCard(
                label: "Average Rating",
                value: ratingAvg.toStringAsFixed(2),
                icon: Icons.star_rounded,
                color: DesignTokens.warning,
              ),
              const SizedBox(height: DesignTokens.spacing16),
              const Text(
                "Performance",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.text,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: "Cancellation Rate",
                      value: "${cancellationRate.toStringAsFixed(1)}%",
                      icon: Icons.cancel_outlined,
                      color: cancellationRate > 20 ? DesignTokens.red : DesignTokens.green,
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
                const Text(
                  "Milestones",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.text,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (completedRides >= 100)
                      const _MilestoneBadge(label: "100 Completed Rides"),
                    if (completedRides >= 500)
                      const _MilestoneBadge(label: "500 Completed Rides"),
                    if (fiveStarRatings >= 50)
                      const _MilestoneBadge(label: "50 Five-Star Ratings"),
                    if (completedRides < 100)
                      const _MilestoneBadge(
                        label: "100 Completed Rides",
                        achieved: false,
                      ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spacing16),
              ],
              const AppCard(
                child: Text(
                  "Daily, weekly, and monthly earnings breakdowns are coming soon.",
                  style: TextStyle(color: DesignTokens.muted),
                ),
              ),
            ],
          ),
        ),
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
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
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
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.bg2,
        border: Border.all(color: DesignTokens.border),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: DesignTokens.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: DesignTokens.muted),
          ),
        ],
      ),
    );
  }
}
