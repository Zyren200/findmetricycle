import "package:flutter/material.dart";
import "package:latlong2/latlong.dart" as ll;
import "package:provider/provider.dart";
import "../../../../core/components/index.dart";
import "../../../../core/theme/design_tokens.dart";
import "../passenger_profile_controller.dart";
import "../passenger_ride_controller.dart";

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PassengerProfileController>().loadFavorites();
      }
    });
  }

  Future<void> _addFavorite() async {
    final rideController = context.read<PassengerRideController>();
    final dropoff = rideController.dropoff;
    final dropoffAddress = rideController.dropoffAddress;

    if (dropoff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Pick a destination on the map first, or save a completed ride from Ride History.",
          ),
        ),
      );
      context.read<ValueNotifier<int>>().value = 0;
      return;
    }

    final controller = TextEditingController(text: dropoffAddress ?? "");
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Add Favorite"),
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
      address: dropoffAddress ?? "Saved location",
      lat: dropoff.latitude,
      lng: dropoff.longitude,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? "Favorite saved."
              : (profileController.favoritesError ??
                  "Failed to save favorite."),
        ),
      ),
    );
  }

  void _deleteFavorite(int id) async {
    final ctrl = context.read<PassengerProfileController>();
    await ctrl.deleteFavorite(id: id);
  }

  void _useFavorite(Map<String, dynamic> favorite) async {
    final id = favorite["id"] as int?;
    final lat = double.tryParse(favorite["lat"]?.toString() ?? "");
    final lng = double.tryParse(favorite["lng"]?.toString() ?? "");
    final address = favorite["address"] as String?;

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This favorite has no saved location.")),
      );
      return;
    }

    final profileController = context.read<PassengerProfileController>();
    if (id != null) await profileController.useFavorite(id: id);
    if (!mounted) return;

    context.read<PassengerRideController>().setDestinationFromFavorite(
          ll.LatLng(lat, lng),
          address: address,
        );
    context.read<ValueNotifier<int>>().value = 0;
    // Opened from Profile / Settings: go back to Home, where the trip is.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PassengerProfileController>();
    final isLoading = ctrl.isLoadingFavorites;
    final favorites = ctrl.favorites;

    return Scaffold(
      appBar: AppBar(title: const Text("Favorites")),
      body: Container(
        color: DesignTokens.bg,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spacing16,
                DesignTokens.spacing16,
                DesignTokens.spacing16,
                DesignTokens.spacing8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Quick Routes",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Save your frequent trips for quick booking",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : favorites.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_outline_rounded,
                                  size: 48, color: DesignTokens.muted),
                              const SizedBox(height: 16),
                              Text(
                                "No favorites yet",
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  "Add your frequent routes to save time booking",
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 24),
                              AppButton(
                                label: "Add Favorite",
                                onPressed: _addFavorite,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: favorites.length,
                          itemBuilder: (context, index) {
                            final fav = favorites[index];
                            final label = fav["label"] as String? ?? "Favorite";
                            final address = fav["address"] as String? ?? "";
                            final id = fav["id"] as int?;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DesignTokens.spacing16,
                                vertical: DesignTokens.spacing8,
                              ),
                              child: AppCard(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _useFavorite(fav),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              label,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              address,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: id != null
                                          ? () {
                                              _deleteFavorite(id);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        "Favorite deleted")),
                                              );
                                            }
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(Icons.close_rounded,
                                            color: DesignTokens.muted,
                                            size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFavorite,
        backgroundColor: DesignTokens.accent,
        child: Icon(Icons.add, color: DesignTokens.bg),
      ),
    );
  }
}
