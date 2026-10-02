import "package:dio/dio.dart";
import "package:image_picker/image_picker.dart";
import "../../../core/network/api_client.dart";

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> sendOtp({required String email}) {
    return _apiClient.post(
      "/auth/v2/send-otp",
      data: {"email": email.trim()},
    );
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String code,
  }) {
    return _apiClient.post(
      "/auth/v2/verify-otp",
      data: {
        "email": email.trim(),
        "code": code.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> registerPassengerV2({
    required String firstName,
    required String middleName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
  }) {
    return _apiClient.post(
      "/auth/v2/register",
      data: {
        "firstName": firstName.trim(),
        "middleName": middleName.trim().isEmpty ? null : middleName.trim(),
        "lastName": lastName.trim(),
        "phone": phone.trim(),
        "email": email.trim(),
        "password": password,
      },
    );
  }

  Future<Map<String, dynamic>> requestPasswordReset({required String email}) {
    return _apiClient.post(
      "/auth/v2/forgot-password/request",
      data: {"email": email.trim()},
    );
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _apiClient.post(
      "/auth/v2/forgot-password/reset",
      data: {
        "email": email.trim(),
        "code": code.trim(),
        "newPassword": newPassword,
      },
    );
  }

  Future<Map<String, dynamic>> getDriverStatus() {
    return _apiClient.get("/auth/v2/driver-status");
  }

  Future<Map<String, dynamic>> getMe() {
    return _apiClient.get("/auth/me");
  }

  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phone,
    String? email,
    String? address,
    XFile? profileImage,
  }) async {
    final formData = FormData.fromMap({
      if (fullName != null) "fullName": fullName.trim(),
      if (phone != null) "phone": phone.trim(),
      if (email != null) "email": email.trim(),
      if (address != null) "address": address.trim(),
      if (profileImage != null)
        "profileImage": await _toMultipartFile(profileImage),
    });
    return _apiClient.patchForm("/passenger/profile", data: formData);
  }

  Future<Map<String, dynamic>> requestPasswordChangeOtp({
    required String currentPassword,
  }) {
    return _apiClient.post(
      "/passenger/change-password/request-otp",
      data: {"currentPassword": currentPassword},
    );
  }

  /// [keepRefreshToken] is this device's session: the backend signs every
  /// other device out after the change, but keeps this one signed in.
  Future<Map<String, dynamic>> confirmPasswordChange({
    required String currentPassword,
    required String newPassword,
    required String otp,
    String? keepRefreshToken,
  }) {
    return _apiClient.post(
      "/passenger/change-password/confirm",
      data: {
        "currentPassword": currentPassword,
        "newPassword": newPassword,
        "otp": otp,
        if (keepRefreshToken != null) "keepRefreshToken": keepRefreshToken,
      },
    );
  }

  Future<Map<String, dynamic>> deleteAccount({required String password}) {
    return _apiClient
        .delete("/passenger/account", data: {"password": password});
  }

  Future<MultipartFile> _toMultipartFile(XFile file) async {
    final filename = file.name.isNotEmpty ? file.name : "upload.jpg";
    return MultipartFile.fromBytes(
      await file.readAsBytes(),
      filename: filename,
    );
  }
}
