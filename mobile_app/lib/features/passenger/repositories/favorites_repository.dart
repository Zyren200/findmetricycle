import "../../../core/network/api_client.dart";

class FavoritesRepository {
  FavoritesRepository(this._apiClient);

  final ApiClient _apiClient;

  /// GET /passenger/favorites
  /// List all favorite places
  Future<Map<String, dynamic>> getFavorites() {
    return _apiClient.get("/passenger/favorites");
  }

  /// POST /passenger/favorites
  /// Create a new favorite place
  Future<Map<String, dynamic>> createFavorite({
    required String label,
    required String address,
    required double lat,
    required double lng,
  }) {
    return _apiClient.post(
      "/passenger/favorites",
      data: {
        "label": label.trim(),
        "address": address.trim(),
        "lat": lat,
        "lng": lng,
      },
    );
  }

  /// PUT /passenger/favorites/:id
  /// Update a favorite place
  Future<Map<String, dynamic>> updateFavorite({
    required int id,
    String? label,
    String? address,
    double? lat,
    double? lng,
  }) {
    final data = <String, dynamic>{};
    if (label != null) data["label"] = label.trim();
    if (address != null) data["address"] = address.trim();
    if (lat != null) data["lat"] = lat;
    if (lng != null) data["lng"] = lng;

    return _apiClient.put("/passenger/favorites/$id", data: data);
  }

  /// DELETE /passenger/favorites/:id
  /// Soft-delete a favorite place
  Future<Map<String, dynamic>> deleteFavorite({required int id}) {
    return _apiClient.delete("/passenger/favorites/$id");
  }

  /// POST /passenger/favorites/:id/use
  /// Record usage of a favorite for analytics
  Future<Map<String, dynamic>> useFavorite({required int id}) {
    return _apiClient.post("/passenger/favorites/$id/use");
  }
}
