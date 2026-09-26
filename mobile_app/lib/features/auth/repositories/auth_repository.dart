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

  Future<Map<String, dynamic>> registerPassenger({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) {
    return _apiClient.post(
      "/auth/passenger/register",
      data: {
        "fullName": fullName,
        "phone": phone,
        "email": email.isEmpty ? null : email,
        "password": password,
      },
    );
  }

  Future<Map<String, dynamic>> registerDriver({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String tricycleNumber,
    required XFile licenseImage,
    required XFile businessPermitImage,
  }) async {
    final formData = FormData.fromMap({
      "fullName": fullName,
      "phone": phone,
      "email": email.isEmpty ? null : email,
      "password": password,
      "tricycleNumber": tricycleNumber,
      "licenseImage": await _toMultipartFile(licenseImage),
      "businessPermitImage": await _toMultipartFile(businessPermitImage),
    });

    return _apiClient.postForm("/auth/driver/register", data: formData);
  }

  Future<Map<String, dynamic>> getDriverStatus() {
    return _apiClient.get("/auth/v2/driver-status");
  }

  Future<Map<String, dynamic>> applyAsDriver({
    required String plateNumber,
    required XFile licenseImage,
    required XFile businessPermitImage,
    String? licenseOcrText,
    XFile? selfieImage,
    String? livenessStatus,
    String? confirmedFullName,
    String? confirmedLicenseNumber,
    String? confirmedBirthDate,
    String? confirmedExpiryDate,
  }) async {
    final formData = FormData.fromMap({
      "plateNumber": plateNumber.trim(),
      if (licenseOcrText != null) "licenseOcrText": licenseOcrText,
      if (livenessStatus != null) "livenessStatus": livenessStatus,
      if (confirmedFullName != null) "confirmedFullName": confirmedFullName,
      if (confirmedLicenseNumber != null) "confirmedLicenseNumber": confirmedLicenseNumber,
      if (confirmedBirthDate != null) "confirmedBirthDate": confirmedBirthDate,
      if (confirmedExpiryDate != null) "confirmedExpiryDate": confirmedExpiryDate,
      "licenseImage": await _toMultipartFile(licenseImage),
      "businessPermitImage": await _toMultipartFile(businessPermitImage),
      if (selfieImage != null)
        "selfieImage": await _toMultipartFile(selfieImage),
    });

    return _apiClient.postForm("/auth/v2/apply-driver", data: formData);
  }

  Future<Map<String, dynamic>> resubmitDriverApplication({
    required XFile licenseImage,
    required XFile businessPermitImage,
    String? licenseOcrText,
    XFile? selfieImage,
    String? livenessStatus,
    String? confirmedFullName,
    String? confirmedLicenseNumber,
    String? confirmedBirthDate,
    String? confirmedExpiryDate,
  }) async {
    final formData = FormData.fromMap({
      if (licenseOcrText != null) "licenseOcrText": licenseOcrText,
      if (livenessStatus != null) "livenessStatus": livenessStatus,
      if (confirmedFullName != null) "confirmedFullName": confirmedFullName,
      if (confirmedLicenseNumber != null) "confirmedLicenseNumber": confirmedLicenseNumber,
      if (confirmedBirthDate != null) "confirmedBirthDate": confirmedBirthDate,
      if (confirmedExpiryDate != null) "confirmedExpiryDate": confirmedExpiryDate,
      "licenseImage": await _toMultipartFile(licenseImage),
      "businessPermitImage": await _toMultipartFile(businessPermitImage),
      if (selfieImage != null)
        "selfieImage": await _toMultipartFile(selfieImage),
    });

    return _apiClient.postForm("/auth/v2/resubmit-driver-application",
        data: formData);
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

  Future<Map<String, dynamic>> confirmPasswordChange({
    required String currentPassword,
    required String newPassword,
    required String otp,
  }) {
    return _apiClient.post(
      "/passenger/change-password/confirm",
      data: {
        "currentPassword": currentPassword,
        "newPassword": newPassword,
        "otp": otp,
      },
    );
  }

  Future<Map<String, dynamic>> deleteAccount({required String password}) {
    return _apiClient.delete("/passenger/account", data: {"password": password});
  }

  Future<MultipartFile> _toMultipartFile(XFile file) async {
    final filename = file.name.isNotEmpty ? file.name : "upload.jpg";
    return MultipartFile.fromBytes(
      await file.readAsBytes(),
      filename: filename,
    );
  }
}
