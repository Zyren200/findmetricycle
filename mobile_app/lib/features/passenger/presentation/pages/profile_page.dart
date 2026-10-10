import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";
import "../../../../core/components/index.dart";
import "../../../../core/config/app_config.dart";
import "../../../../core/state/app_preferences.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../shared/presentation/contact_support_sheet.dart";
import "../../../shared/state/session_store.dart";
import "../passenger_navigation.dart";
import "../passenger_profile_controller.dart";
import "edit_profile_page.dart";
import "favorites_page.dart";
import "safety_page.dart";
import "settings_page.dart";

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PassengerProfileController>().loadUserProfile();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the driver application website: re-check the status
  // so a just-submitted application shows up without restarting the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<PassengerProfileController>().loadDriverStatus();
    }
  }

  Future<void> _refresh() async {
    final ctrl = context.read<PassengerProfileController>();
    await Future.wait([ctrl.loadDriverStatus(), ctrl.loadUserProfile()]);
  }

  void _editProfile() {
    final profileController = context.read<PassengerProfileController>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: profileController,
          child: const EditProfilePage(),
        ),
      ),
    );
  }

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;

    final ctrl = context.read<PassengerProfileController>();
    final ok = await ctrl.updateProfile(profileImage: file);
    if (!mounted) return;
    showSunToast(
        context,
        ok
            ? "Profile picture updated."
            : (ctrl.profileError ?? "Failed to update photo."));
  }

  Future<void> _openDriverApplicationWebsite() async {
    final uri = Uri.parse(AppConfig.driverApplyUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      showSunToast(context, "Could not open the driver application website.");
    }
  }

  Future<void> _switchToDriver() async {
    final storage = context.read<FlutterSecureStorage>();
    final sessionStore = context.read<SessionStore>();
    final profileCtrl = context.read<PassengerProfileController>();
    await sessionStore.setActiveRole(
      storage,
      "driver",
      knownApproved: profileCtrl.driverStatus == "approved",
    );
  }

  Future<void> _logout() async {
    final confirmed = await confirmSun(
      context,
      title: "Log out?",
      message: "You can log back in anytime with your email or mobile number.",
      confirmLabel: "Log out",
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !mounted) return;
    // AppRouter watches the session and shows the welcome screen.
    await context
        .read<SessionStore>()
        .logout(context.read<FlutterSecureStorage>());
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>().session;
    final profileCtrl = context.watch<PassengerProfileController>();
    final prefs = context.watch<AppPreferences>();
    final profile = profileCtrl.userProfile;
    final profileImagePath = profile?["profile_image_url"] as String?;
    final profileImageUrl = profileImagePath == null
        ? null
        : AppConfig.resolveAssetUrl(profileImagePath);
    final name = session?.fullName ?? "Passenger";
    final email = profile?["email"]?.toString();
    final phone = session?.phone;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
              18, top + 24, 18, DesignTokens.tabBarClearance + 8),
          children: [
            ...Stagger.wrap([
              // You
              ProfileHeader(
                name: name,
                subtitle: email ?? phone ?? "",
                imageUrl: profileImageUrl,
                onAvatarTap: _changeProfilePicture,
                trailing: SunButton(
                  label: "Edit profile",
                  tone: SunTone.quiet,
                  height: 36,
                  expand: false,
                  onPressed: _editProfile,
                ),
              ),

              // Driver Mode
              _DriverSection(
                profileCtrl: profileCtrl,
                onSwitchToDriver: _switchToDriver,
                onOpenWebsite: _openDriverApplicationWebsite,
              ),

              // Appearance
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel("Appearance"),
                  Segmented<ThemeMode>(
                    semanticLabel: "Theme",
                    value: prefs.themeMode,
                    onChanged: prefs.setThemeMode,
                    options: const [
                      (ThemeMode.light, "Light", Icons.light_mode_outlined),
                      (ThemeMode.dark, "Dark", Icons.dark_mode_outlined),
                      (ThemeMode.system, "System", Icons.smartphone_rounded),
                    ],
                  ),
                ],
              ),

              SunListCard(children: [
                SunListRow(
                  icon: Icons.bookmark_border_rounded,
                  label: "Saved places",
                  onTap: () =>
                      pushPassengerPage(context, const FavoritesPage()),
                ),
                SunListRow(
                  icon: Icons.notifications_none_rounded,
                  label: "Notifications",
                  onTap: () => context.read<ValueNotifier<int>>().value = 2,
                ),
                SunListRow(
                  icon: Icons.shield_outlined,
                  label: "Safety and SOS",
                  onTap: () => pushPassengerPage(context, const SafetyPage()),
                ),
                SunListRow(
                  icon: Icons.tune_rounded,
                  label: "Settings",
                  onTap: () => pushPassengerPage(context, const SettingsPage()),
                ),
                SunListRow(
                  icon: Icons.help_outline_rounded,
                  label: "Help center",
                  onTap: () => showContactSupport(context),
                ),
                SunListRow(
                  icon: Icons.logout_rounded,
                  label: "Log out",
                  labelColor: DesignTokens.danger,
                  trailing: const SizedBox.shrink(),
                  onTap: _logout,
                ),
              ]),
            ], gap: 18),
          ],
        ),
      ),
    );
  }
}

/// Driver Mode: switch when approved, otherwise the application status
/// and a link to the driver website.
class _DriverSection extends StatelessWidget {
  const _DriverSection({
    required this.profileCtrl,
    required this.onSwitchToDriver,
    required this.onOpenWebsite,
  });

  final PassengerProfileController profileCtrl;
  final VoidCallback onSwitchToDriver;
  final VoidCallback onOpenWebsite;

  @override
  Widget build(BuildContext context) {
    final status = profileCtrl.driverStatus;

    // Only spin while there is nothing to show yet; a background refresh
    // keeps the last known status on screen.
    if (profileCtrl.isLoadingDriverStatus && status == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (status == null && profileCtrl.driverError != null) {
      return ErrorBox(
        message:
            "Couldn't load your driver status. Check your internet or server connection.",
        onRetry: profileCtrl.loadDriverStatus,
      );
    }

    if (status == "approved") {
      return PrismCard(
        icon: Icons.electric_rickshaw_rounded,
        title: "Switch to Driver Mode",
        subtitle: "Approved · go online to get ride requests",
        onTap: onSwitchToDriver,
      );
    }

    final (String title, String subtitle) = switch (status) {
      "pending" => (
          "Application submitted",
          "Pending review. We'll notify you once you're approved."
        ),
      "rejected" => (
          "Application not approved",
          "Reason: ${profileCtrl.driverRejectionReason ?? "Not specified"}. You can resubmit."
        ),
      "needs_correction" => (
          "Action required",
          profileCtrl.driverCorrectionNote ??
              "Please update your documents and resubmit."
        ),
      _ => (
          "Become a Driver",
          "Drive a tricycle in Guiuan and earn with FindMeTricycle."
        ),
    };
    final buttonLabel = switch (status) {
      "rejected" => "Resubmit application",
      "needs_correction" => "Update application",
      "pending" => "Application website",
      _ => "Apply on the website",
    };
    final attention = status == "rejected" || status == "needs_correction";

    return SunCard(
      radius: DesignTokens.radiusCard,
      color: attention ? DesignTokens.sosSoft : DesignTokens.primarySoft,
      border: false,
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(
                icon: status == "pending"
                    ? Icons.hourglass_bottom_rounded
                    : attention
                        ? Icons.error_outline_rounded
                        : Icons.electric_rickshaw_rounded,
                size: 46,
                radius: 15,
                background: attention ? DesignTokens.sos : DesignTokens.primary,
                foreground:
                    attention ? DesignTokens.sosInk : DesignTokens.primaryInk,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: DesignTokens.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: DesignTokens.ink2,
                            fontSize: 13,
                            height: 18 / 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Refresh status",
                onPressed: profileCtrl.isLoadingDriverStatus
                    ? null
                    : profileCtrl.loadDriverStatus,
                icon: profileCtrl.isLoadingDriverStatus
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.refresh_rounded,
                        size: 20, color: DesignTokens.ink2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SunButton(
            label: buttonLabel,
            icon: Icons.open_in_new_rounded,
            tone: attention ? SunTone.sos : SunTone.primary,
            height: 46,
            fontSize: 14,
            onPressed: onOpenWebsite,
          ),
        ],
      ),
    );
  }
}
