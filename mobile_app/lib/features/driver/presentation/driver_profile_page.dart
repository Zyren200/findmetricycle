import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";
import "../../../core/config/app_config.dart";
import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../../shared/presentation/change_password_page.dart";
import "../../shared/presentation/notifications_screen.dart";
import "../../shared/state/notifications_controller.dart";
import "../../shared/state/session_store.dart";
import "driver_edit_profile_page.dart";
import "driver_ride_controller.dart";
import "pages/driver_settings_page.dart";

// Going Offline first (when currently online) before handing control back
// to Passenger Mode — without this, a driver who switches modes (or the
// app that quietly drops them into Driver Mode again later) would keep
// showing up as "online" to the matching engine and to passengers even
// though nothing is tracking their location anymore.
Future<void> _switchToPassenger(
  BuildContext context,
  DriverRideController controller,
) async {
  if (controller.isOnline) {
    await controller.setOnline(false);
  }
  if (!context.mounted) return;

  final storage = context.read<FlutterSecureStorage>();
  final sessionStore = context.read<SessionStore>();
  await sessionStore.setActiveRole(storage, "passenger");
}

Future<void> _changePassword(
  BuildContext context,
  DriverRideController controller,
) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ChangePasswordPage(
        requestOtp: (currentPassword) => controller.requestPasswordChangeOtp(
            currentPassword: currentPassword),
        confirmChange: (currentPassword, newPassword, otp) =>
            controller.confirmPasswordChange(
          currentPassword: currentPassword,
          newPassword: newPassword,
          otp: otp,
          keepRefreshToken:
              context.read<SessionStore>().session?.refreshToken,
        ),
      ),
    ),
  );

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Password updated.")),
    );
  }
}

Future<void> _logout(
  BuildContext context,
  DriverRideController controller,
) async {
  if (controller.isOnline) {
    await controller.setOnline(false);
  }
  if (!context.mounted) return;

  final storage = context.read<FlutterSecureStorage>();
  final sessionStore = context.read<SessionStore>();
  await sessionStore.logout(storage);
}

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DriverRideController>().refreshProfile();
    });
  }

  void _push(BuildContext context, Widget page) {
    final ctrl = context.read<DriverRideController>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(value: ctrl, child: page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    final session = context.watch<SessionStore>().session;
    final profile = ctrl.driverProfile ?? {};
    final summary = ctrl.earningsSummary ?? profile;

    final fullName =
        _text(profile["full_name"]) ?? session?.fullName ?? "Driver";
    final email = _text(profile["email"]);
    final phone = _text(profile["phone"]) ?? session?.phone;
    final tricycleNumber = _text(profile["tricycle_number"]) ?? "-";
    final approvalStatus = _text(profile["approval_status"]) ?? "unknown";
    final (String, String)? approvalNotice =
        switch (approvalStatus.toLowerCase()) {
      "pending" => (
          "Pending Approval",
          "Your account is still being reviewed by the admin. You'll be notified once approved.",
        ),
      "suspended" => (
          "Suspended",
          "Your driver account is suspended. Please contact the admin.",
        ),
      "license_expired" => (
          "License expired",
          "Update your license to go online again.",
        ),
      "rejected" => (
          "Not approved",
          "Your application was not approved. You can apply again.",
        ),
      _ => null,
    };
    final rating = _number(summary["rating_avg"]);
    final totalRides =
        _text(summary["total_rides"] ?? profile["total_rides"]) ?? "0";
    final totalEarnings =
        _number(summary["total_earnings"] ?? profile["total_earnings"]) ?? 0;
    final profileImagePath = _text(profile["profile_image_url"]);
    final profileImageUrl = profileImagePath == null
        ? null
        : AppConfig.resolveAssetUrl(profileImagePath);
    final docsNeedUpdate = const {"expired", "expiring_soon"}
            .contains(_text(profile["license_expiry_status"])) ||
        const {"expired", "expiring_soon"}
            .contains(_text(profile["business_permit_expiry_status"]));

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          AppTopBar(
            title: "Driver Profile",
            trailing: IconButton(
              icon: Icon(Icons.edit_outlined, color: DesignTokens.text),
              tooltip: "Edit Profile",
              onPressed: () => _push(context, const DriverEditProfilePage()),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ctrl.refreshEarnings(notify: false);
                await ctrl.refreshProfile();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // Profile card
                  Container(
                    color: DesignTokens.bg2,
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: DesignTokens.driverAccent,
                              backgroundImage: profileImageUrl == null
                                  ? null
                                  : NetworkImage(profileImageUrl),
                              child: profileImageUrl != null
                                  ? null
                                  : Text(
                                      _initials(fullName),
                                      style: TextStyle(
                                        color: DesignTokens.bg,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(fullName,
                                      style: TextStyle(
                                          color: DesignTokens.text,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700)),
                                  if (phone != null)
                                    Text(phone,
                                        style: TextStyle(
                                            color: DesignTokens.muted,
                                            fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          size: 16, color: Colors.amber),
                                      const SizedBox(width: 3),
                                      Text(
                                          rating == null
                                              ? "N/A"
                                              : rating.toStringAsFixed(2),
                                          style: TextStyle(
                                              color: DesignTokens.text,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 4),
                                      Text("(${ctrl.ratings.length} ratings)",
                                          style: TextStyle(
                                              color: DesignTokens.muted,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _VehicleInfo(
                                label: "Tricycle", value: tricycleNumber),
                            const SizedBox(width: 12),
                            _VehicleInfo(
                                label: "Status",
                                value: approvalStatus.toUpperCase()),
                            const SizedBox(width: 12),
                            _VehicleInfo(
                                label: "Mode",
                                value: ctrl.isOnline ? "ONLINE" : "OFFLINE"),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (approvalNotice != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: StatusBanner(
                        label: approvalNotice.$1,
                        subtitle: approvalNotice.$2,
                        color: DesignTokens.warning,
                        icon: Icons.info_outline_rounded,
                      ),
                    ),
                  if (ctrl.error != null && ctrl.driverProfile == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: ErrorBox(
                          message: ctrl.error!, onRetry: ctrl.refreshProfile),
                    ),

                  // Account details
                  _Section(
                    title: "Account",
                    children: [
                      _DetailRow(
                          label: "Tricycle Number", value: tricycleNumber),
                      if (email != null)
                        _DetailRow(label: "Email", value: email),
                      _DetailRow(label: "Total Trips", value: totalRides),
                      _DetailRow(
                          label: "Total Earnings",
                          value: "₱${totalEarnings.toStringAsFixed(2)}"),
                    ],
                  ),

                  // Documents
                  _Section(
                    title: "Documents",
                    children: [
                      _DocumentStatusRow(
                        label: "Driver's License",
                        status: _text(profile["license_expiry_status"]),
                        expiresAt: _text(profile["license_expires_at"]),
                      ),
                      _DocumentStatusRow(
                        label: "Business Permit",
                        status: _text(profile["business_permit_expiry_status"]),
                        expiresAt: _text(profile["business_permit_expires_at"]),
                      ),
                      if (docsNeedUpdate)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(AppConfig.driverApplyUrl);
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            },
                            icon:
                                const Icon(Icons.open_in_new_rounded, size: 16),
                            label: const Text("Update Documents"),
                          ),
                        ),
                    ],
                  ),

                  // Navigation
                  _Section(
                    children: [
                      NavListItem(
                        icon: Icons.star_border_rounded,
                        label: "My Ratings",
                        onTap: () => _push(context, const _MyRatingsPage()),
                      ),
                      NavListItem(
                        icon: Icons.description_outlined,
                        label: "Ride History",
                        onTap: () =>
                            context.read<ValueNotifier<int>>().value = 1,
                      ),
                      NavListItem(
                        icon: Icons.notifications_none_rounded,
                        label: "Notifications",
                        onTap: () {
                          final notifications =
                              context.read<NotificationsController>();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                NotificationsScreen(controller: notifications),
                          ));
                        },
                      ),
                      NavListItem(
                        icon: Icons.lock_outline_rounded,
                        label: "Change Password",
                        onTap: () => _changePassword(context, ctrl),
                      ),
                      NavListItem(
                        icon: Icons.settings_outlined,
                        label: "Settings",
                        onTap: () => _push(context, const DriverSettingsPage()),
                      ),
                    ],
                  ),

                  // Mode switch
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radius),
                        onTap: () => _switchToPassenger(context, ctrl),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radius),
                            border: Border.all(color: DesignTokens.border2),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text("Switch to Passenger Mode",
                                    style: TextStyle(
                                        color: DesignTokens.text,
                                        fontSize: 14)),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: DesignTokens.muted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Logout
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border:
                          Border(top: BorderSide(color: DesignTokens.border)),
                    ),
                    child: InkWell(
                      onTap: () => _logout(context, ctrl),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded,
                                size: 20, color: DesignTokens.red),
                            const SizedBox(width: 12),
                            Text("Sign Out",
                                style: TextStyle(
                                    color: DesignTokens.red,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: DesignTokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) SectionLabel(title!),
          ...children,
        ],
      ),
    );
  }
}

class _VehicleInfo extends StatelessWidget {
  const _VehicleInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: DesignTokens.bg3,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(color: DesignTokens.muted, fontSize: 11)),
            FittedBox(
              child: Text(value,
                  style: TextStyle(
                      color: DesignTokens.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: DesignTokens.border)),
      ),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(color: DesignTokens.muted, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: DesignTokens.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// Passenger ratings and recent completed trips with their feedback.
class _MyRatingsPage extends StatelessWidget {
  const _MyRatingsPage();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          const AppTopBar(title: "My Ratings", showBack: true),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.refreshProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (ctrl.isProfileLoading && ctrl.ratings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (ctrl.ratings.isEmpty)
                    const EmptyState(
                      icon: Icons.star_border_rounded,
                      message: "No ratings from passengers yet",
                    ),
                  ...ctrl.ratings.map((rating) => _RatingCard(rating: rating)),
                  if (ctrl.completedRides.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const SectionLabel("Completed Trips"),
                    ...ctrl.completedRides
                        .map((ride) => _CompletedRideCard(ride: ride)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentStatusRow extends StatelessWidget {
  const _DocumentStatusRow({
    required this.label,
    required this.status,
    required this.expiresAt,
  });

  final String label;
  final String? status;
  final String? expiresAt;

  @override
  Widget build(BuildContext context) {
    final normalized = status ?? "unable_to_determine";
    final (badgeLabel, color) = switch (normalized) {
      "valid" => ("VALID", DesignTokens.green),
      "expiring_soon" => ("EXPIRING SOON", DesignTokens.warning),
      "expired" => ("EXPIRED", DesignTokens.red),
      // No expiry date on file — not a review state; the account can be
      // fully approved with this.
      _ => ("WALANG EXPIRY", DesignTokens.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DesignTokens.bg2,
        border: Border.all(color: DesignTokens.border),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.text,
                  ),
                ),
                if (expiresAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    "Expires: ${_formatDate(expiresAt) ?? expiresAt}",
                    style: TextStyle(
                      color: DesignTokens.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withAlpha(24),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withAlpha(50)),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedRideCard extends StatelessWidget {
  const _CompletedRideCard({required this.ride});

  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final passengerName = _text(ride["passenger_name"]) ?? "Passenger";
    final pickup = _text(ride["pickup_address"]) ?? "Pickup not provided";
    final dropoff = _text(ride["dropoff_address"]) ?? "Drop-off not provided";
    final finalFare =
        _number(ride["final_fare"] ?? ride["estimated_fare"]) ?? 0;
    final distance = _number(ride["distance_km"]) ?? 0;
    final completedAt = _formatDate(ride["completed_at"]);
    final passengerRating =
        int.tryParse(ride["passenger_rating"]?.toString() ?? "");
    final passengerFeedback = _text(ride["passenger_feedback"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.bg2,
        border: Border.all(color: DesignTokens.border),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  passengerName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.text,
                  ),
                ),
              ),
              Text(
                "PHP ${finalFare.toStringAsFixed(2)}",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.driverAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Pickup: $pickup", style: TextStyle(color: DesignTokens.text)),
          const SizedBox(height: 4),
          Text("Drop-off: $dropoff",
              style: TextStyle(color: DesignTokens.text)),
          const SizedBox(height: 8),
          Text(
            "Distance: ${distance.toStringAsFixed(2)} km",
            style: TextStyle(color: DesignTokens.muted),
          ),
          if (completedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              "Completed: $completedAt",
              style: TextStyle(color: DesignTokens.muted),
            ),
          ],
          if (passengerRating != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  "Passenger rating:",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.text,
                  ),
                ),
                const SizedBox(width: 8),
                _StarRow(stars: passengerRating),
              ],
            ),
          ],
          if (passengerFeedback != null && passengerFeedback.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(passengerFeedback, style: TextStyle(color: DesignTokens.text)),
          ],
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.rating});

  final Map<String, dynamic> rating;

  @override
  Widget build(BuildContext context) {
    final passengerName = _text(rating["passenger_name"]) ?? "Passenger";
    final feedback = _text(rating["feedback"]);
    final stars = int.tryParse(rating["stars"]?.toString() ?? "") ?? 0;
    final createdAt = _formatDate(rating["created_at"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.bg2,
        border: Border.all(color: DesignTokens.border),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  passengerName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.text,
                  ),
                ),
              ),
              _StarRow(stars: stars),
            ],
          ),
          if (feedback != null && feedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(feedback, style: TextStyle(color: DesignTokens.text)),
          ],
          if (createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              createdAt,
              style: TextStyle(fontSize: 12, color: DesignTokens.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < stars ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 18,
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .split(" ")
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList();
  if (parts.isEmpty) return "D";
  return parts.map((part) => part[0].toUpperCase()).join();
}

String? _text(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _number(dynamic value) {
  if (value == null) return null;
  return double.tryParse(value.toString());
}

String? _formatDate(dynamic value) {
  final raw = _text(value);
  if (raw == null) return null;

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  final local = parsed.toLocal();
  final month = local.month.toString().padLeft(2, "0");
  final day = local.day.toString().padLeft(2, "0");
  final hour = local.hour.toString().padLeft(2, "0");
  final minute = local.minute.toString().padLeft(2, "0");
  return "${local.year}-$month-$day $hour:$minute";
}
