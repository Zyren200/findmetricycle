import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "driver_ride_controller.dart";

/// Rides tab: completed-ride history. Kept intentionally simple for
/// Phase 1 (no pagination/filters yet — see Phase 7) since it reuses
/// whatever DriverRideController already fetched via refreshProfile().
class DriverRidesPage extends StatelessWidget {
  const DriverRidesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    final rides = ctrl.completedRides;

    return Scaffold(
      appBar: const AppAppBar(title: "My Rides"),
      body: Container(
        color: DesignTokens.bg,
        child: RefreshIndicator(
          onRefresh: () => ctrl.refreshProfile(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            children: [
              if (!ctrl.isProfileLoading && rides.isEmpty)
                const AppCard(
                  child: Text(
                    "Wala ka pang completed rides.",
                    style: TextStyle(color: DesignTokens.muted),
                  ),
                ),
              ...rides.map((ride) => _RideHistoryCard(ride: ride)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideHistoryCard extends StatelessWidget {
  const _RideHistoryCard({required this.ride});

  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final passengerName = _text(ride["passenger_name"]) ?? "Passenger";
    final pickup = _text(ride["pickup_address"]) ?? "Pickup not provided";
    final dropoff = _text(ride["dropoff_address"]) ?? "Drop-off not provided";
    final finalFare = _number(ride["final_fare"] ?? ride["estimated_fare"]) ?? 0;
    final completedAt = _formatDate(ride["completed_at"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                  passengerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.text,
                  ),
                ),
              ),
              Text(
                "PHP ${finalFare.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.driverAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Pickup: $pickup", style: const TextStyle(color: DesignTokens.text)),
          const SizedBox(height: 4),
          Text("Drop-off: $dropoff", style: const TextStyle(color: DesignTokens.text)),
          if (completedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              "Completed: $completedAt",
              style: const TextStyle(color: DesignTokens.muted),
            ),
          ],
        ],
      ),
    );
  }
}

String? _text(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _number(dynamic value) {
  if (value == null) return null;
  return double.tryParse(value.toString());
}

String? _formatDate(dynamic value) {
  final raw = _text(value);
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  final month = local.month.toString().padLeft(2, "0");
  final day = local.day.toString().padLeft(2, "0");
  final hour = local.hour.toString().padLeft(2, "0");
  final minute = local.minute.toString().padLeft(2, "0");
  return "${local.year}-$month-$day $hour:$minute";
}
