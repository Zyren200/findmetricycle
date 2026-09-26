import "../../../core/network/api_client.dart";

class PassengerRepository {
  PassengerRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> findRide({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    int passengerCount = 1,
    bool autoAssign = true,
  }) {
    return _apiClient.post(
      "/passenger/bookings/find-ride",
      data: {
        "pickupAddress": pickupAddress,
        "pickupLat": pickupLat,
        "pickupLng": pickupLng,
        "dropoffAddress": dropoffAddress,
        "dropoffLat": dropoffLat,
        "dropoffLng": dropoffLng,
        "passengerCount": passengerCount,
        "autoAssign": autoAssign,
      },
    );
  }

  Future<Map<String, dynamic>> getBooking(int bookingId) {
    return _apiClient.get("/passenger/bookings/$bookingId");
  }

  Future<Map<String, dynamic>> getBookingHistory({int limit = 50}) {
    return _apiClient.get(
      "/passenger/bookings/history",
      queryParameters: {"limit": limit},
    );
  }

  Future<Map<String, dynamic>> getFareSettings() {
    return _apiClient.get("/passenger/fare");
  }

  Future<Map<String, dynamic>> getNotifications({int limit = 50}) {
    return _apiClient.get(
      "/passenger/notifications",
      queryParameters: {"limit": limit},
    );
  }

  Future<Map<String, dynamic>> cancelBooking(int bookingId) {
    return _apiClient.post("/passenger/bookings/$bookingId/cancel");
  }

  /// Nearest online riders the passenger can still pick for this booking.
  Future<Map<String, dynamic>> getNearbyDrivers(int bookingId) {
    return _apiClient.get("/passenger/bookings/$bookingId/nearby-drivers");
  }

  Future<Map<String, dynamic>> chooseDriver({
    required int bookingId,
    required int driverId,
  }) {
    return _apiClient.post(
      "/passenger/bookings/$bookingId/choose-driver",
      data: {"driverId": driverId},
    );
  }

  Future<Map<String, dynamic>> triggerSos({
    int? bookingId,
    double? lat,
    double? lng,
    String? message,
  }) {
    return _apiClient.post(
      "/passenger/sos",
      data: {
        if (bookingId != null) "bookingId": bookingId,
        if (lat != null) "lat": lat,
        if (lng != null) "lng": lng,
        if (message != null && message.isNotEmpty) "message": message,
      },
    );
  }

  Future<Map<String, dynamic>> submitRating({
    required int bookingId,
    required int stars,
    required String feedback,
  }) {
    return _apiClient.post(
      "/passenger/bookings/$bookingId/rate",
      data: {
        "stars": stars,
        "feedback": feedback,
      },
    );
  }
}
