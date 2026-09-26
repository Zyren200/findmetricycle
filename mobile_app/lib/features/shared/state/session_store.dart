import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/socket_client.dart";
import "../models/user_session.dart";

class SessionStore extends ChangeNotifier {
  static const _tokenKey = "auth_token";
  static const _refreshTokenKey = "refresh_token";
  static const _userIdKey = "user_id";
  static const _fullNameKey = "full_name";
  static const _phoneKey = "phone";
  static const _roleKey = "role";
  static const _activeRoleKey = "active_role";
  static const _isDriverAccountKey = "is_driver_account";
  static const _driverApprovalStatusKey = "driver_approval_status";

  ApiClient? _apiClient;
  SocketClient? _socketClient;
  FlutterSecureStorage? _storage;

  UserSession? _session;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  UserSession? get session => _session;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _session != null;
  String? get error => _error;

  void bind(ApiClient apiClient, SocketClient socketClient) {
    _apiClient = apiClient;
    _socketClient = socketClient;
    _apiClient!.onUnauthorized = _refreshAccessToken;
  }

  /// Exchanges the stored refresh token for a new access token when a
  /// request comes back 401 — called by ApiClient's interceptor. Clears
  /// the session (and, via AppRouter watching this store, drops the user
  /// back to the login screen) if the refresh token is also no longer
  /// valid, rather than leaving them stuck seeing raw "invalid token"
  /// errors on every subsequent action.
  Future<String?> _refreshAccessToken() async {
    final storage = _storage;
    final refreshToken = _session?.refreshToken;
    if (storage == null || refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await _apiClient!.post(
        "/auth/refresh",
        data: {"refreshToken": refreshToken},
      );

      if (response["success"] != true) {
        await logout(storage);
        return null;
      }

      final data = response["data"] as Map<String, dynamic>? ?? {};
      final newAccessToken = data["token"] as String? ?? data["accessToken"] as String?;
      final newRefreshToken = data["refreshToken"] as String?;
      if (newAccessToken == null || newRefreshToken == null) {
        await logout(storage);
        return null;
      }

      _session = UserSession(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        userId: _session!.userId,
        fullName: _session!.fullName,
        phone: _session!.phone,
        role: _session!.role,
        activeRole: _session!.activeRole,
        isDriverAccount: _session!.isDriverAccount,
        driverApprovalStatus: _session!.driverApprovalStatus,
      );
      await storage.write(key: _tokenKey, value: newAccessToken);
      await storage.write(key: _refreshTokenKey, value: newRefreshToken);
      _apiClient?.setToken(newAccessToken);
      _socketClient?.connect(newAccessToken);
      notifyListeners();
      return newAccessToken;
    } catch (_) {
      await logout(storage);
      return null;
    }
  }

  Future<void> initialize(FlutterSecureStorage storage) async {
    if (_isInitialized) return;
    _isLoading = true;
    _storage = storage;
    notifyListeners();

    final token = await storage.read(key: _tokenKey);
    final refreshToken = await storage.read(key: _refreshTokenKey);
    final userId = await storage.read(key: _userIdKey);
    final fullName = await storage.read(key: _fullNameKey);
    final phone = await storage.read(key: _phoneKey);
    final role = await storage.read(key: _roleKey);
    final activeRole = await storage.read(key: _activeRoleKey);
    final isDriverAccount = await storage.read(key: _isDriverAccountKey);
    final driverApprovalStatus = await storage.read(key: _driverApprovalStatusKey);

    if (token != null &&
        refreshToken != null &&
        userId != null &&
        fullName != null &&
        phone != null &&
        role != null) {
      _session = UserSession(
        accessToken: token,
        refreshToken: refreshToken,
        userId: int.tryParse(userId) ?? 0,
        fullName: fullName,
        phone: phone,
        role: role,
        activeRole: activeRole ?? role,
        isDriverAccount: isDriverAccount == "1",
        driverApprovalStatus: driverApprovalStatus ?? "none",
      );
      _apiClient?.setToken(token);
      _socketClient?.connect(token);
    }

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> login({
    required FlutterSecureStorage storage,
    required String emailOrPhone,
    required String password,
  }) async {
    _error = null;
    _isLoading = true;
    _storage = storage;
    notifyListeners();

    try {
      final identity = emailOrPhone.trim();
      final payload = identity.contains("@")
          ? {"email": identity, "password": password}
          : {"phone": identity, "password": password};

      final response = await _apiClient!.post("/auth/login", data: payload);

      final success = response["success"] == true;
      if (!success) {
        _error = response["message"]?.toString() ?? "Login failed.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final data = response["data"] as Map<String, dynamic>? ?? {};
      _session = UserSession.fromLoginResponse(data);

      final effectiveRole = _session!.effectiveRole;
      await storage.write(key: _tokenKey, value: _session!.accessToken);
      await storage.write(key: _refreshTokenKey, value: _session!.refreshToken);
      await storage.write(key: _userIdKey, value: _session!.userId.toString());
      await storage.write(key: _fullNameKey, value: _session!.fullName);
      await storage.write(key: _phoneKey, value: _session!.phone);
      await storage.write(key: _roleKey, value: _session!.role);
      await storage.write(key: _activeRoleKey, value: effectiveRole);
      await storage.write(
        key: _isDriverAccountKey,
        value: _session!.isDriverAccount ? "1" : "0",
      );
      await storage.write(
        key: _driverApprovalStatusKey,
        value: _session!.driverApprovalStatus,
      );

      _apiClient?.setToken(_session!.accessToken);
      _socketClient?.connect(_session!.accessToken);

      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = "Unexpected error during login.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Switches Passenger Mode ↔ Driver Mode. [knownApproved] lets a caller
  /// that just re-checked driver-application status with the backend
  /// (e.g. the passenger profile page, right before showing the "Switch to
  /// Driver" button) pass that fresher answer along — otherwise this falls
  /// back to whatever driver-approval fields were cached at login, which
  /// would still say "not approved" for a driver approved earlier in the
  /// same session and wrongly block the switch.
  Future<void> setActiveRole(
    FlutterSecureStorage storage,
    String role, {
    bool? knownApproved,
  }) async {
    if (_session == null) return;

    var sanitizedRole = role == "driver" ? "driver" : "passenger";
    final isDriverAccount = knownApproved ?? _session!.isDriverAccount;
    final driverApprovalStatus =
        knownApproved == true ? "approved" : _session!.driverApprovalStatus;

    final eligible = _session!.role == "driver" ||
        (isDriverAccount && driverApprovalStatus == "approved");
    // A passenger who was never approved as a driver (or lost approval
    // since) can never switch into Driver Mode, no matter what called this.
    if (sanitizedRole == "driver" && !eligible) {
      sanitizedRole = "passenger";
    }

    _session = UserSession(
      accessToken: _session!.accessToken,
      refreshToken: _session!.refreshToken,
      userId: _session!.userId,
      fullName: _session!.fullName,
      phone: _session!.phone,
      role: _session!.role,
      activeRole: sanitizedRole,
      isDriverAccount: isDriverAccount,
      driverApprovalStatus: driverApprovalStatus,
    );

    await storage.write(key: _activeRoleKey, value: sanitizedRole);
    await storage.write(
      key: _isDriverAccountKey,
      value: isDriverAccount ? "1" : "0",
    );
    await storage.write(
      key: _driverApprovalStatusKey,
      value: driverApprovalStatus,
    );
    notifyListeners();
  }

  Future<void> logout(FlutterSecureStorage storage) async {
    final refreshToken = _session?.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _apiClient?.post(
          "/auth/logout",
          data: {"refreshToken": refreshToken},
        );
      } catch (_) {}
    }

    _session = null;
    _apiClient?.setToken(null);
    _socketClient?.disconnect();
    await storage.deleteAll();
    notifyListeners();
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data["message"] != null) {
      return data["message"].toString();
    }
    return "Request failed. Please try again.";
  }
}
