import "package:flutter/material.dart";
import "package:latlong2/latlong.dart" as ll;
import "../../../../core/components/index.dart";
import "../../../../core/theme/design_tokens.dart";
import "../passenger_ride_controller.dart";
import "../passenger_profile_controller.dart";
import "package:provider/provider.dart";

class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});

  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}

class _RideHistoryPageState extends State<RideHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PassengerRideController>().loadBookingHistory();
      }
    });
  }

  Future<void> _saveAsFavorite(Map<String, dynamic> ride) async {
    final dropoffAddress = ride["dropoff_address"]?.toString();
    final lat = double.tryParse(ride["dropoff_lat"]?.toString() ?? "");
    final lng = double.tryParse(ride["dropoff_lng"]?.toString() ?? "");

    if (dropoffAddress == null || lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This ride has no saved destination to favorite.")),
      );
      return;
    }

    final controller = TextEditingController(text: dropoffAddress);
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Save as Favorite"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Label",
            hintText: "e.g. Home, Work, Mom's House",
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
      address: dropoffAddress,
      lat: lat,
      lng: lng,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? "Saved to Favorites." : (profileController.favoritesError ?? "Failed to save favorite."),
        ),
      ),
    );
  }

  void _bookAgain(Map<String, dynamic> ride) {
    final dropoffAddress = ride["dropoff_address"]?.toString();
    final lat = double.tryParse(ride["dropoff_lat"]?.toString() ?? "");
    final lng = double.tryParse(ride["dropoff_lng"]?.toString() ?? "");

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This ride has no saved destination to rebook.")),
      );
      return;
    }

    context.read<PassengerRideController>().setDestinationFromFavorite(
          ll.LatLng(lat, lng),
          address: dropoffAddress,
        );
    context.read<ValueNotifier<int>>().value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PassengerRideController>();
    final rides = ctrl.bookingHistory;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: ctrl.loadBookingHistory,
        child: Container(
          color: DesignTokens.bg,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Ride History",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: DesignTokens.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacing12),
              Container(
                padding: const EdgeInsets.all(14),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "MY RIDES",
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: DesignTokens.text,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${rides.length}",
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: DesignTokens.text,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Tracked rides in your account",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: DesignTokens.text,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spacing16),
              if (ctrl.isLoadingHistory)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (ctrl.historyError != null)
                AppCard(
                  child: Column(
                    children: [
                      Text(ctrl.historyError!, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: DesignTokens.spacing8),
                      AppButton(label: "Retry", onPressed: ctrl.loadBookingHistory),
                    ],
                  ),
                )
              else if (rides.isEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_rounded, size: 42, color: DesignTokens.muted),
                      const SizedBox(height: DesignTokens.spacing12),
                      Text(
                        "No rides yet.",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: DesignTokens.spacing8),
                      Text(
                        "Start a new trip from the map to see ride history here.",
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...rides.map((ride) => _RideHistoryCard(
                      ride: ride,
                      onSaveFavorite: () => _saveAsFavorite(ride),
                      onBookAgain: () => _bookAgain(ride),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideHistoryCard extends StatelessWidget {
  const _RideHistoryCard({
    required this.ride,
    required this.onSaveFavorite,
    required this.onBookAgain,
  });

  final Map<String, dynamic> ride;
  final VoidCallback onSaveFavorite;
  final VoidCallback onBookAgain;

  @override
  Widget build(BuildContext context) {
    final status = ride["status"]?.toString() ?? "";
    final isCompleted = status == "completed";
    final fare = ride["final_fare"] ?? ride["estimated_fare"];
    final requestedAt = ride["requested_at"]?.toString();

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
                    "Booking #${ride["id"]}",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DesignTokens.text),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFFE1F5E7) : DesignTokens.bg3,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isCompleted ? const Color(0xFF0E8C46) : DesignTokens.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (ride["pickup_address"] != null)
              Text(
                "From: ${ride["pickup_address"]}",
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (ride["dropoff_address"] != null)
              Text(
                "To: ${ride["dropoff_address"]}",
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${ride["distance_km"] ?? "--"} km",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  "PHP ${fare ?? "--"}",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF0E8C46),
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            if (requestedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                requestedAt,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.muted),
              ),
            ],
            if (isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSaveFavorite,
                      icon: const Icon(Icons.star_border_rounded, size: 18),
                      label: const Text("Save as Favorite"),
                    ),
                  ),
                  const SizedBox(width: 8),
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
