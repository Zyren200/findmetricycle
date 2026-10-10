import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";
import "../../../core/config/app_config.dart";
import "../../../core/components/index.dart";
import "../../../core/state/app_preferences.dart";
import "../../../core/theme/design_tokens.dart";
import "../../shared/presentation/change_password_page.dart";
import "../../shared/presentation/notifications_screen.dart";
import "../../shared/state/notifications_controller.dart";
import "../../shared/state/session_store.dart";
import "driver_edit_profile_page.dart";
import "driver_ride_controller.dart";
import "pages/driver_settings_page.dart";
import "widgets/driver_ride_actions.dart";

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
          keepRefreshToken: context.read<SessionStore>().session?.refreshToken,
        ),
      ),
    ),
  );

  if (saved == true && context.mounted) {
    showSunToast(context, "Password updated.");
  }
}

Future<void> _logout(
  BuildContext context,
  DriverRideController controller,
) async {
  final confirmed = await confirmSun(
    context,
    title: "Log out?",
    message: "You'll go offline and stop getting ride requests.",
    confirmLabel: "Log out",
    destructive: true,
    icon: Icons.logout_rounded,
  );
  if (!confirmed || !context.mounted) return;
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
    final prefs = context.watch<AppPreferences>();
    final session = context.watch<SessionStore>().session;
    final profile = ctrl.driverProfile ?? {};
    final summary = ctrl.earningsSummary ?? profile;
    final top = MediaQuery.paddingOf(context).top;

    final fullName =
        _text(profile["full_name"]) ?? session?.fullName ?? "Driver";
    final email = _text(profile["email"]);
    final phone = _text(profile["phone"]) ?? session?.phone;
    final tricycleNumber = _text(profile["tricycle_number"]);
    final approvalStatus = _text(profile["approval_status"]) ?? "unknown";
    final (String, String)? approvalNotice =
        switch (approvalStatus.toLowerCase()) {
      "pending" => (
          "Pending approval",
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
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          await ctrl.refreshEarnings(notify: false);
          await ctrl.refreshProfile();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
              18, top + 24, 18, DesignTokens.tabBarClearance + 8),
          children: [
            ...Stagger.wrap([
              // Who and what they drive
              ProfileHeader(
                name: fullName,
                tone: AvatarTone.primary,
                imageUrl: profileImageUrl,
                subtitle: [
                  tricycleNumber == null
                      ? (phone ?? "")
                      : "Tricycle $tricycleNumber",
                  if (rating != null && rating > 0)
                    "★ ${rating.toStringAsFixed(1)}",
                ].where((p) => p.isNotEmpty).join(" · "),
                trailing: StatusChip(
                  approvalStatus == "approved"
                      ? "Approved"
                      : approvalStatus.replaceAll("_", " "),
                  tone: approvalStatus == "approved"
                      ? ChipTone.ok
                      : ChipTone.primary,
                ),
              ),

              // License and franchise validity (".valid").
              Column(
                children: [
                  _DocTile(
                    label: "Driver's license",
                    status: _text(profile["license_expiry_status"]),
                    expiresAt: _text(profile["license_expires_at"]),
                  ),
                  const SizedBox(height: 8),
                  _DocTile(
                    label: "Franchise",
                    status: _text(profile["business_permit_expiry_status"]),
                    expiresAt: _text(profile["business_permit_expires_at"]),
                  ),
                  if (docsNeedUpdate) ...[
                    const SizedBox(height: 10),
                    SunButton(
                      label: "Update documents",
                      icon: Icons.open_in_new_rounded,
                      tone: SunTone.quiet,
                      height: 44,
                      onPressed: () async {
                        final uri = Uri.parse(AppConfig.driverApplyUrl);
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      },
                    ),
                  ],
                ],
              ),

              MetaStats(items: [
                (
                  rating == null || rating == 0
                      ? "—"
                      : "★ ${rating.toStringAsFixed(2)}",
                  "Rating"
                ),
                (totalRides, "Trips"),
                ("₱${totalEarnings.toStringAsFixed(0)}", "Earned"),
              ]),

              if (approvalNotice != null)
                StatusBanner(
                  label: approvalNotice.$1,
                  subtitle: approvalNotice.$2,
                  color: DesignTokens.primaryBright,
                  icon: Icons.info_outline_rounded,
                ),
              if (ctrl.error != null && ctrl.driverProfile == null)
                ErrorBox(message: ctrl.error!, onRetry: ctrl.refreshProfile),

              // Back to Passenger Mode
              PrismCard(
                lagoon: true,
                icon: Icons.person_outline_rounded,
                title: "Switch to Passenger Mode",
                subtitle: "Same account, same history",
                onTap: () => _switchToPassenger(context, ctrl),
              ),

              // Preferences
              SunListCard(children: [
                SunListRow(
                  icon: Icons.gps_fixed_rounded,
                  label: "Auto-online",
                  subtitle: "Go online when you open Driver Mode",
                  trailing: SunSwitch(
                    label: "Auto-online",
                    value: prefs.driverAutoOnline,
                    onChanged: (v) async {
                      await prefs.setDriverAutoOnline(v);
                      // Turning it on also takes effect right away.
                      if (v && !ctrl.isOnline && ctrl.activeBooking == null) {
                        await ctrl.setOnline(true);
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text("Appearance",
                          style: TextStyle(
                              color: DesignTokens.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Segmented<ThemeMode>(
                        semanticLabel: "Theme",
                        height: 40,
                        value: prefs.themeMode,
                        onChanged: prefs.setThemeMode,
                        options: const [
                          (ThemeMode.light, "Light", null),
                          (ThemeMode.dark, "Dark", null),
                          (ThemeMode.system, "System", null),
                        ],
                      ),
                    ],
                  ),
                ),
                SunListRow(
                  label: "Report a problem",
                  icon: Icons.flag_outlined,
                  onTap: () => showDriverReportDialog(context, ctrl),
                ),
              ]),

              SunListCard(children: [
                SunListRow(
                  icon: Icons.edit_outlined,
                  label: "Edit profile",
                  onTap: () => _push(context, const DriverEditProfilePage()),
                ),
                SunListRow(
                  icon: Icons.star_outline_rounded,
                  label: "My ratings",
                  subtitle: "${ctrl.ratings.length} from passengers",
                  onTap: () => _push(context, const _MyRatingsPage()),
                ),
                SunListRow(
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
                SunListRow(
                  icon: Icons.lock_outline_rounded,
                  label: "Change password",
                  onTap: () => _changePassword(context, ctrl),
                ),
                SunListRow(
                  icon: Icons.tune_rounded,
                  label: "Settings",
                  subtitle: email,
                  onTap: () => _push(context, const DriverSettingsPage()),
                ),
                SunListRow(
                  icon: Icons.logout_rounded,
                  label: "Log out",
                  labelColor: DesignTokens.danger,
                  trailing: const SizedBox.shrink(),
                  onTap: () => _logout(context, ctrl),
                ),
              ]),
            ], gap: 18),
          ],
        ),
      ),
    );
  }
}

/// License / franchise: "Valid · Mar 2027".
class _DocTile extends StatelessWidget {
  const _DocTile(
      {required this.label, required this.status, required this.expiresAt});

  final String label;
  final String? status;
  final String? expiresAt;

  @override
  Widget build(BuildContext context) {
    final (state, color) = switch (status ?? "") {
      "valid" => ("Valid", DesignTokens.lagoonText),
      "expiring_soon" => ("Expiring soon", DesignTokens.primaryText),
      "expired" => ("Expired", DesignTokens.sosText),
      // No expiry date on file — not a review state; the account can be
      // fully approved with this.
      _ => ("Walang expiry", DesignTokens.ink2),
    };
    final date = _shortDate(expiresAt);
    final tone = switch (status ?? "") {
      "valid" => ChipTone.ok,
      "expiring_soon" => ChipTone.primary,
      "expired" => ChipTone.sos,
      _ => ChipTone.neutral,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(color: DesignTokens.ink, fontSize: 13.5)),
                Text(date == null ? state : "Valid until $date",
                    style:
                        TextStyle(color: DesignTokens.ink2, fontSize: 12)),
              ],
            ),
          ),
          StatusChip(
              status == "expiring_soon" ? "Renew soon" : state,
              tone: tone),
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
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const AppTopBar(title: "My ratings", showBack: true),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.refreshProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
                    const SectionLabel("Completed trips"),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SunCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(passengerName,
                      style: TextStyle(
                          color: DesignTokens.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
                Text("₱${finalFare.toStringAsFixed(2)}",
                    style: TextStyle(
                        color: DesignTokens.primaryText,
                        fontWeight: FontWeight.w700,
                        fontFeatures: DesignTokens.tabular)),
              ],
            ),
            const SizedBox(height: 10),
            RoutePoints(pickup: pickup, dropoff: dropoff, showLabels: false),
            const SizedBox(height: 8),
            Text(
              [
                "${distance.toStringAsFixed(2)} km",
                if (completedAt != null) completedAt,
              ].join(" · "),
              style: TextStyle(
                  color: DesignTokens.ink2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            if (passengerRating != null) ...[
              const SizedBox(height: 8),
              _StarRow(stars: passengerRating),
            ],
            if (passengerFeedback != null && passengerFeedback.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(passengerFeedback,
                  style: TextStyle(
                      color: DesignTokens.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SunCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ToneAvatar(
                    name: passengerName,
                    tone: AvatarTone.sand,
                    size: 36,
                    radius: 11),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(passengerName,
                      style: TextStyle(
                          color: DesignTokens.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
                _StarRow(stars: stars),
              ],
            ),
            if (feedback != null && feedback.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text("“$feedback”",
                  style: TextStyle(
                      color: DesignTokens.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
            if (createdAt != null) ...[
              const SizedBox(height: 8),
              Text(createdAt,
                  style: TextStyle(
                      fontSize: 12,
                      color: DesignTokens.ink2,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
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
          index < stars ? Icons.star_rounded : Icons.star_border_rounded,
          color: index < stars ? DesignTokens.star : DesignTokens.ink2,
          size: 18,
        ),
      ),
    );
  }
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

const _monthNames = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
];

/// "Mar 2027" for a document's expiry.
String? _shortDate(String? raw) {
  final date = raw == null ? null : DateTime.tryParse(raw);
  if (date == null) return null;
  return "${_monthNames[date.month - 1]} ${date.year}";
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
