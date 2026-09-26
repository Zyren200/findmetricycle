import "package:dio/dio.dart";
import "package:image_picker/image_picker.dart";
import "../../../core/network/api_client.dart";

class DriverRepository {
  DriverRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Lightweight reachability check for the "Internet" status pill — hits
  /// the public, unauthenticated health endpoint. Deliberately not a raw
  /// DNS/socket check (dart:io's InternetAddress.lookup isn't available on
  /// Flutter Web at all), and this doubles as a check that our own backend
  /// specifically is reachable, not just "the internet" in the abstract.
  Future<bool> checkConnectivity() async {
    try {
      final response = await _apiClient.get("/health");
      return response["success"] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> setOnline(bool isOnline) {
    return _apiClient.patch(
      "/driver/status",
      data: {"isOnline": isOnline},
    );
  }

  Future<Map<String, dynamic>> updateLocation({
    required double lat,
    required double lng,
  }) {
    return _apiClient.patch(
      "/driver/location",
      data: {
        "lat": lat,
        "lng": lng,
      },
    );
  }

  Future<Map<String, dynamic>> respondBooking({
    required int bookingId,
    required String action,
    String? reason,
  }) {
    return _apiClient.post(
      "/driver/bookings/$bookingId/respond",
      data: {
        "action": action,
        "reason": reason,
      },
    );
  }

  /// The ride request currently waiting on this rider (or null data).
  Future<Map<String, dynamic>> getIncomingBooking() {
    return _apiClient.get("/driver/bookings/incoming");
  }

  Future<Map<String, dynamic>> arriveAtPickup(int bookingId) {
    return _apiClient.post("/driver/bookings/$bookingId/arrive");
  }

  Future<Map<String, dynamic>> startRide(int bookingId, {required String pin}) {
    return _apiClient.post(
      "/driver/bookings/$bookingId/start",
      data: {"pin": pin},
    );
  }

  Future<Map<String, dynamic>> markNoShow(int bookingId, {String? note}) {
    return _apiClient.post(
      "/driver/bookings/$bookingId/no-show",
      data: {if (note != null) "note": note},
    );
  }

  Future<Map<String, dynamic>> completeRide({
    required int bookingId,
    double? actualDistanceKm,
  }) {
    return _apiClient.post(
      "/driver/bookings/$bookingId/complete",
      data: {"actualDistanceKm": actualDistanceKm},
    );
  }

  Future<Map<String, dynamic>> getEarnings() {
    return _apiClient.get("/driver/earnings");
  }

  Future<Map<String, dynamic>> getProfile() {
    return _apiClient.get("/driver/profile");
  }

  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phone,
    String? email,
    String? tricycleNumber,
    XFile? profileImage,
  }) async {
    final formData = FormData();

    if (fullName != null) {
      formData.fields.add(MapEntry("fullName", fullName));
    }
    if (phone != null) {
      formData.fields.add(MapEntry("phone", phone));
    }
    if (email != null) {
      formData.fields.add(MapEntry("email", email));
    }
    if (tricycleNumber != null) {
      formData.fields.add(MapEntry("tricycleNumber", tricycleNumber));
    }
    if (profileImage != null) {
      formData.files.add(
        MapEntry("profileImage", await _toMultipartFile(profileImage)),
      );
    }

    return _apiClient.patchForm("/driver/profile", data: formData);
  }

  Future<Map<String, dynamic>> getCompletedRides() {
    return _apiClient.get("/driver/bookings/completed");
  }

  Future<Map<String, dynamic>> getRatings() {
    return _apiClient.get("/driver/ratings");
  }

  Future<Map<String, dynamic>> getNotifications() {
    return _apiClient.get("/driver/notifications");
  }

  Future<Map<String, dynamic>> requestPasswordChangeOtp({
    required String currentPassword,
  }) {
    return _apiClient.post(
      "/driver/change-password/request-otp",
      data: {"currentPassword": currentPassword},
    );
  }

  Future<Map<String, dynamic>> confirmPasswordChange({
    required String currentPassword,
    required String newPassword,
    required String otp,
  }) {
    return _apiClient.post(
      "/driver/change-password/confirm",
      data: {
        "currentPassword": currentPassword,
        "newPassword": newPassword,
        "otp": otp,
      },
    );
  }

  Future<Map<String, dynamic>> getPerformance() {
    return _apiClient.get("/driver/performance");
  }

  Future<Map<String, dynamic>> triggerSos({
    required int bookingId,
    double? lat,
    double? lng,
    String? message,
  }) {
    return _apiClient.post(
      "/driver/sos",
      data: {
        "bookingId": bookingId,
        if (lat != null) "lat": lat,
        if (lng != null) "lng": lng,
        if (message != null) "message": message,
      },
    );
  }

  Future<Map<String, dynamic>> reportIssue({
    int? bookingId,
    required String category,
    required String description,
  }) {
    return _apiClient.post(
      "/driver/report",
      data: {
        if (bookingId != null) "bookingId": bookingId,
        "category": category,
        "description": description,
      },
    );
  }

  Future<MultipartFile> _toMultipartFile(XFile file) async {
    final filename = file.name.isNotEmpty ? file.name : "upload.jpg";
    return MultipartFile.fromBytes(
      await file.readAsBytes(),
      filename: filename,
    );
  }
}
