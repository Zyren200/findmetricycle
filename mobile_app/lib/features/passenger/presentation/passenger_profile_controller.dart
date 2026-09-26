import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "../repositories/favorites_repository.dart";
import "../../auth/repositories/auth_repository.dart";

/// Controller for managing passenger profile, driver status, and favorites
class PassengerProfileController extends ChangeNotifier {
  PassengerProfileController(
    this._authRepository,
    this._favoritesRepository,
  );

  final AuthRepository _authRepository;
  final FavoritesRepository _favoritesRepository;

  // Driver status
  String? _driverStatus; // none, pending, approved, rejected, needs_correction
  String? _driverRejectionReason;
  String? _driverCorrectionNote;
  bool _isLoadingDriverStatus = false;
  String? _driverError;

  // Favorites
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoadingFavorites = false;
  String? _favoritesError;

  // Full user profile (fullName/phone come from the session already;
  // email/address/profile image only live in the backend user record).
  Map<String, dynamic>? _userProfile;
  bool _isLoadingProfile = false;
  bool _isSavingProfile = false;
  String? _profileError;

  // Getters
  String? get driverStatus => _driverStatus;
  String? get driverRejectionReason => _driverRejectionReason;
  String? get driverCorrectionNote => _driverCorrectionNote;
  bool get isLoadingDriverStatus => _isLoadingDriverStatus;
  String? get driverError => _driverError;

  List<Map<String, dynamic>> get favorites => _favorites;
  bool get isLoadingFavorites => _isLoadingFavorites;
  String? get favoritesError => _favoritesError;

  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoadingProfile => _isLoadingProfile;
  bool get isSavingProfile => _isSavingProfile;
  String? get profileError => _profileError;

  /// Load driver status from API
  Future<void> loadDriverStatus() async {
    _isLoadingDriverStatus = true;
    _driverError = null;
    notifyListeners();

    try {
      final result = await _authRepository.getDriverStatus();
      if (result["success"] == true) {
        final data = result["data"] as Map<String, dynamic>?;
        _driverStatus = data?["status"] as String? ?? "none";
        _driverRejectionReason = data?["rejection_reason"] as String?;
        _driverCorrectionNote = data?["correction_note"] as String?;
      } else {
        _driverError =
            result["message"] as String? ?? "Failed to load driver status";
      }
    } catch (e) {
      _driverError = "Error loading driver status: $e";
    } finally {
      _isLoadingDriverStatus = false;
      notifyListeners();
    }
  }

  /// Load favorites from API
  Future<void> loadFavorites() async {
    _isLoadingFavorites = true;
    _favoritesError = null;
    notifyListeners();

    try {
      final result = await _favoritesRepository.getFavorites();
      if (result["success"] == true) {
        final data = result["data"] as List?;
        _favorites = (data ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _favoritesError =
            result["message"] as String? ?? "Failed to load favorites";
      }
    } catch (e) {
      _favoritesError = "Error loading favorites: $e";
    } finally {
      _isLoadingFavorites = false;
      notifyListeners();
    }
  }

  /// Create a favorite
  Future<bool> createFavorite({
    required String label,
    required String address,
    required double lat,
    required double lng,
  }) async {
    try {
      final result = await _favoritesRepository.createFavorite(
        label: label,
        address: address,
        lat: lat,
        lng: lng,
      );

      if (result["success"] == true) {
        await loadFavorites();
        return true;
      } else {
        _favoritesError =
            result["message"] as String? ?? "Failed to create favorite";
        return false;
      }
    } catch (e) {
      _favoritesError = "Error creating favorite: $e";
      return false;
    }
  }

  /// Update a favorite
  Future<bool> updateFavorite({
    required int id,
    String? label,
    String? address,
    double? lat,
    double? lng,
  }) async {
    try {
      final result = await _favoritesRepository.updateFavorite(
        id: id,
        label: label,
        address: address,
        lat: lat,
        lng: lng,
      );

      if (result["success"] == true) {
        await loadFavorites();
        return true;
      } else {
        _favoritesError =
            result["message"] as String? ?? "Failed to update favorite";
        return false;
      }
    } catch (e) {
      _favoritesError = "Error updating favorite: $e";
      return false;
    }
  }

  /// Delete a favorite
  Future<bool> deleteFavorite({required int id}) async {
    try {
      final result = await _favoritesRepository.deleteFavorite(id: id);

      if (result["success"] == true) {
        await loadFavorites();
        return true;
      } else {
        _favoritesError =
            result["message"] as String? ?? "Failed to delete favorite";
        return false;
      }
    } catch (e) {
      _favoritesError = "Error deleting favorite: $e";
      return false;
    }
  }

  /// Use a favorite (for analytics)
  Future<void> useFavorite({required int id}) async {
    try {
      await _favoritesRepository.useFavorite(id: id);
    } catch (e) {
      // Log silently
      debugPrint("Error using favorite: $e");
    }
  }

  /// Load the full user profile (email/address/profile image) from the
  /// backend — the session only carries fullName/phone.
  Future<void> loadUserProfile() async {
    _isLoadingProfile = true;
    _profileError = null;
    notifyListeners();

    try {
      final result = await _authRepository.getMe();
      if (result["success"] == true) {
        _userProfile = Map<String, dynamic>.from(result["data"] as Map);
      } else {
        _profileError = result["message"] as String? ?? "Failed to load profile";
      }
    } catch (e) {
      _profileError = "Error loading profile: $e";
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? email,
    String? address,
    XFile? profileImage,
  }) async {
    _isSavingProfile = true;
    _profileError = null;
    notifyListeners();

    try {
      final result = await _authRepository.updateProfile(
        fullName: fullName,
        phone: phone,
        email: email,
        address: address,
        profileImage: profileImage,
      );
      if (result["success"] == true) {
        _userProfile = Map<String, dynamic>.from(result["data"] as Map);
        return true;
      }
      _profileError = result["message"] as String? ?? "Failed to update profile";
      return false;
    } catch (e) {
      _profileError = "Error updating profile: $e";
      return false;
    } finally {
      _isSavingProfile = false;
      notifyListeners();
    }
  }

  /// Step 1 of the password-change flow: confirms the current password and
  /// emails a one-time code. Returns the raw response (including the
  /// masked email on success) so the UI can show "code sent to ab***@..."
  /// and throws only on transport-level failure — a wrong current password
  /// comes back as `success: false` with a message, same as before.
  Future<Map<String, dynamic>> requestPasswordChangeOtp({
    required String currentPassword,
  }) async {
    try {
      final result =
          await _authRepository.requestPasswordChangeOtp(currentPassword: currentPassword);
      if (result["success"] != true) {
        _profileError = result["message"] as String? ?? "Failed to send verification code.";
        notifyListeners();
      }
      return result;
    } catch (e) {
      _profileError = "Error requesting verification code: $e";
      notifyListeners();
      return {"success": false, "message": _profileError};
    }
  }

  /// Step 2: the OTP is the hard gate here — a wrong/expired code returns
  /// success:false and the password is left untouched (enforced
  /// server-side, not just in this UI).
  Future<bool> confirmPasswordChange({
    required String currentPassword,
    required String newPassword,
    required String otp,
  }) async {
    try {
      final result = await _authRepository.confirmPasswordChange(
        currentPassword: currentPassword,
        newPassword: newPassword,
        otp: otp,
      );
      if (result["success"] == true) return true;
      _profileError = result["message"] as String? ?? "Failed to change password";
      notifyListeners();
      return false;
    } catch (e) {
      _profileError = "Error changing password: $e";
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount({required String password}) async {
    try {
      final result = await _authRepository.deleteAccount(password: password);
      if (result["success"] == true) return true;
      _profileError = result["message"] as String? ?? "Failed to delete account";
      notifyListeners();
      return false;
    } catch (e) {
      _profileError = "Error deleting account: $e";
      notifyListeners();
      return false;
    }
  }

  /// Clear errors
  void clearDriverError() {
    _driverError = null;
    notifyListeners();
  }

  void clearFavoritesError() {
    _favoritesError = null;
    notifyListeners();
  }
}
