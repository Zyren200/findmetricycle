import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";
import "../../../core/config/app_config.dart";
import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../../shared/presentation/change_password_page.dart";
import "../../shared/state/session_store.dart";
import "driver_edit_profile_page.dart";
import "driver_ride_controller.dart";

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
        requestOtp: (currentPassword) =>
            controller.requestPasswordChangeOtp(currentPassword: currentPassword),
        confirmChange: (currentPassword, newPassword, otp) => controller.confirmPasswordChange(
          currentPassword: currentPassword,
          newPassword: newPassword,
          otp: otp,
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

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    final session = context.watch<SessionStore>().session;
    final profile = ctrl.driverProfile ?? {};
    final summary = ctrl.earningsSummary ?? profile;
    final ratings = ctrl.ratings;
    final completedRides = ctrl.completedRides;

    final fullName =
        _text(profile["full_name"]) ?? session?.fullName ?? "Driver";
    final email = _text(profile["email"]) ?? "-";
    final tricycleNumber = _text(profile["tricycle_number"]) ?? "-";
    final approvalStatus = _text(profile["approval_status"]) ?? "unknown";
    final totalRides =
        _text(summary["total_rides"] ?? profile["total_rides"]) ?? "0";
    final totalEarnings =
        _number(summary["total_earnings"] ?? profile["total_earnings"]) ?? 0;
    final profileImagePath = _text(profile["profile_image_url"]);
    final profileImageUrl = profileImagePath == null
        ? null
        : AppConfig.resolveAssetUrl(profileImagePath);

    return Scaffold(
      appBar: AppAppBar(
        title: "Driver Profile",
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: "Edit Profile",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: ctrl,
                  child: const DriverEditProfilePage(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: DesignTokens.bg,
        child: RefreshIndicator(
          onRefresh: () async {
            await ctrl.refreshEarnings(notify: false);
            await ctrl.refreshProfile();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DesignTokens.bg2,
                  border: Border.all(color: DesignTokens.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [DesignTokens.driverAccent, DesignTokens.driverAccent2],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: profileImageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.network(
                                    profileImageUrl,
                                    width: 66,
                                    height: 66,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Text(
                                  _initials(fullName),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: DesignTokens.text,
                                      fontSize: 22,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Driver · $tricycleNumber",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: DesignTokens.muted),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _StatusChip(
                                    label: approvalStatus.toUpperCase(),
                                    tone: _approvalTone(approvalStatus),
                                  ),
                                  _StatusChip(
                                    label: ctrl.isOnline ? "ONLINE" : "OFFLINE",
                                    tone: ctrl.isOnline ? "success" : "warning",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (email != "-")
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          email,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: DesignTokens.muted),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spacing16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: "Total Trips",
                      value: totalRides,
                      icon: Icons.route,
                      color: DesignTokens.green,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing12),
                  Expanded(
                    child: _StatCard(
                      label: "Total Earnings",
                      value: "PHP ${totalEarnings.toStringAsFixed(2)}",
                      icon: Icons.payments,
                      color: DesignTokens.driverAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacing16),
              const Text(
                "Documents",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.text,
                ),
              ),
              const SizedBox(height: 10),
              _DocumentStatusRow(
                label: "Driver's License",
                status: _text(profile["license_expiry_status"]),
                expiresAt: _text(profile["license_expires_at"]),
              ),
              const SizedBox(height: 8),
              _DocumentStatusRow(
                label: "Business Permit",
                status: _text(profile["business_permit_expiry_status"]),
                expiresAt: _text(profile["business_permit_expires_at"]),
              ),
              if (const {"expired", "expiring_soon"}.contains(
                    _text(profile["license_expiry_status"]),
                  ) ||
                  const {"expired", "expiring_soon"}.contains(
                    _text(profile["business_permit_expiry_status"]),
                  )) ...[
                const SizedBox(height: 10),
                AppButton(
                  label: "Update Documents",
                  style: AppButtonStyle.ghost,
                  onPressed: () async {
                    final uri = Uri.parse(AppConfig.driverApplyUrl);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ],
              const SizedBox(height: DesignTokens.spacing16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Completed Trips",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: DesignTokens.text,
                      ),
                    ),
                  ),
                  if (ctrl.isProfileLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (approvalStatus.toLowerCase() != "approved")
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: DesignTokens.warning.withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DesignTokens.warning.withAlpha(60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pending Approval",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: DesignTokens.warning),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Your account is under review. You will be notified once approved.",
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: DesignTokens.text),
                      ),
                    ],
                  ),
                ),
              if (approvalStatus.toLowerCase() != "approved")
                const SizedBox(height: DesignTokens.spacing16),
              if (ctrl.error != null && ctrl.driverProfile == null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: DesignTokens.spacing16),
                  decoration: BoxDecoration(
                    color: DesignTokens.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DesignTokens.red.withAlpha(60)),
                  ),
                  child: Text(
                    ctrl.error!,
                    style: const TextStyle(color: DesignTokens.red),
                  ),
                ),
              if (!ctrl.isProfileLoading && completedRides.isEmpty)
                const AppCard(
                  child: Text(
                    "Wala pang completed trips.",
                    style: TextStyle(color: DesignTokens.muted),
                  ),
                ),
              ...completedRides.map((ride) => _CompletedRideCard(ride: ride)),
              const SizedBox(height: 16),
              const Text(
                "Passenger Ratings",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.text,
                ),
              ),
              const SizedBox(height: 10),
              if (!ctrl.isProfileLoading && ratings.isEmpty)
                const AppCard(
                  child: Text(
                    "Wala pang ratings mula sa mga passenger.",
                    style: TextStyle(color: DesignTokens.muted),
                  ),
                ),
              ...ratings.map((rating) => _RatingCard(rating: rating)),
              const SizedBox(height: DesignTokens.spacing24),
              AppButton(
                label: "Change Password",
                style: AppButtonStyle.ghost,
                onPressed: () => _changePassword(context, ctrl),
              ),
              const SizedBox(height: DesignTokens.spacing12),
              AppButton(
                label: "Switch to Passenger Mode",
                style: AppButtonStyle.ghost,
                onPressed: () => _switchToPassenger(context, ctrl),
              ),
              const SizedBox(height: DesignTokens.spacing12),
              AppButton(
                label: "Logout",
                style: AppButtonStyle.destructive,
                onPressed: () => _logout(context, ctrl),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _approvalTone(String status) {
  final lower = status.toLowerCase();
  if (lower.contains("approved")) return "success";
  if (lower.contains("pending")) return "warning";
  if (lower.contains("suspend")) return "error";
  return "warning";
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.tone,
  });

  final String label;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      "success" => DesignTokens.green,
      "error" => DesignTokens.red,
      _ => DesignTokens.driverAccent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
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
      _ => ("PENDING REVIEW", DesignTokens.muted),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.text,
                  ),
                ),
                if (expiresAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    "Expires: ${_formatDate(expiresAt) ?? expiresAt}",
                    style: const TextStyle(
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.bg2,
        border: Border.all(color: DesignTokens.border),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: DesignTokens.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: DesignTokens.muted),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.text,
                  ),
                ),
              ),
              Text(
                "PHP ${finalFare.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.driverAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Pickup: $pickup", style: const TextStyle(color: DesignTokens.text)),
          const SizedBox(height: 4),
          Text("Drop-off: $dropoff", style: const TextStyle(color: DesignTokens.text)),
          const SizedBox(height: 8),
          Text(
            "Distance: ${distance.toStringAsFixed(2)} km",
            style: const TextStyle(color: DesignTokens.muted),
          ),
          if (completedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              "Completed: $completedAt",
              style: const TextStyle(color: DesignTokens.muted),
            ),
          ],
          if (passengerRating != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
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
            Text(passengerFeedback, style: const TextStyle(color: DesignTokens.text)),
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
                  style: const TextStyle(
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
            Text(feedback, style: const TextStyle(color: DesignTokens.text)),
          ],
          if (createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              createdAt,
              style: const TextStyle(fontSize: 12, color: DesignTokens.muted),
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
