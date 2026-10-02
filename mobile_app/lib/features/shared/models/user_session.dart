class UserSession {
  UserSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.role,
    this.activeRole,
    this.isDriverAccount = false,
    this.driverApprovalStatus = "none",
  });

  final String accessToken;
  final String refreshToken;
  final int userId;
  final String fullName;
  final String phone;
  final String role;
  final String? activeRole;

  // Dual-role (passenger + driver) accounts: role stays "passenger" forever
  // — admin approval is tracked here instead. Legacy single-role drivers
  // (role == "driver") don't need these to be true.
  final bool isDriverAccount;
  final String driverApprovalStatus;

  bool get canUseDriverMode =>
      role == "driver" ||
      (isDriverAccount && driverApprovalStatus == "approved");

  // Falls back to Passenger Mode if the stored preference says "driver" but
  // this account isn't actually eligible (never approved, or approval was
  // revoked since the choice was saved) — the one place this is enforced
  // client-side, so a normal passenger can never land on Driver Mode UI.
  String get effectiveRole {
    final requested = (activeRole ?? role).trim();
    final resolved = requested.isEmpty ? "passenger" : requested;
    if (resolved == "driver" && !canUseDriverMode) {
      return "passenger";
    }
    return resolved;
  }

  bool get isPassenger => effectiveRole == "passenger";
  bool get isDriver => effectiveRole == "driver";
  bool get isAdmin => role == "admin";

  factory UserSession.fromLoginResponse(Map<String, dynamic> data) {
    final user = data["user"] as Map<String, dynamic>? ?? {};
    final accessToken =
        data["accessToken"]?.toString() ?? data["token"]?.toString() ?? "";
    final refreshToken = data["refreshToken"]?.toString() ?? "";
    final roleValue = user["role"]?.toString() ?? "passenger";
    return UserSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: int.tryParse(user["id"]?.toString() ?? "") ?? 0,
      fullName: user["full_name"]?.toString() ?? "",
      phone: user["phone"]?.toString() ?? "",
      role: roleValue,
      activeRole: user["active_role"]?.toString() ?? roleValue,
      isDriverAccount:
          user["is_driver_account"] == true || user["is_driver_account"] == 1,
      driverApprovalStatus:
          user["driver_approval_status"]?.toString() ?? "none",
    );
  }
}
