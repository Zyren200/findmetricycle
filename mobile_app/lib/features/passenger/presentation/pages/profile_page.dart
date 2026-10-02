import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";
import "../../../../core/components/index.dart";
import "../../../../core/config/app_config.dart";
import "../../../../core/theme/design_tokens.dart";
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? "Profile picture updated."
            : (ctrl.profileError ?? "Failed to update photo.")),
      ),
    );
  }

  Future<void> _openDriverApplicationWebsite() async {
    final uri = Uri.parse(AppConfig.driverApplyUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Could not open the driver application website.")),
      );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text("Sign Out", style: TextStyle(color: DesignTokens.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // AppRouter watches the session and shows the login screen.
    await context
        .read<SessionStore>()
        .logout(context.read<FlutterSecureStorage>());
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>().session;
    final profileCtrl = context.watch<PassengerProfileController>();
    final profile = profileCtrl.userProfile;
    final profileImagePath = profile?["profile_image_url"] as String?;
    final profileImageUrl = profileImagePath == null
        ? null
        : AppConfig.resolveAssetUrl(profileImagePath);
    final name = session?.fullName ?? "Passenger";
    final email = profile?["email"]?.toString();

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          const AppTopBar(title: "Profile"),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // User card
                  InkWell(
                    onTap: _editProfile,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: DesignTokens.border)),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _changeProfilePicture,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor:
                                      DesignTokens.accent.withAlpha(40),
                                  backgroundImage: profileImageUrl == null
                                      ? null
                                      : NetworkImage(profileImageUrl),
                                  child: profileImageUrl != null
                                      ? null
                                      : Text(
                                          name.trim().isEmpty
                                              ? "P"
                                              : name.trim()[0].toUpperCase(),
                                          style: TextStyle(
                                            color: DesignTokens.accent,
                                            fontSize: 22,
                                            fontWeight: DesignTokens.fw700,
                                          ),
                                        ),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: DesignTokens.bg3,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.camera_alt_rounded,
                                        size: 12, color: DesignTokens.text),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: TextStyle(
                                        color: DesignTokens.text,
                                        fontSize: 16,
                                        fontWeight: DesignTokens.fw600)),
                                if (email != null)
                                  Text(email,
                                      style: TextStyle(
                                          color: DesignTokens.muted,
                                          fontSize: 13)),
                                Text(session?.phone ?? "-",
                                    style: TextStyle(
                                        color: DesignTokens.muted,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_outlined,
                              size: 18, color: DesignTokens.muted),
                        ],
                      ),
                    ),
                  ),

                  // Driver section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionLabel("Driver Account"),
                        _DriverSection(
                          profileCtrl: profileCtrl,
                          onSwitchToDriver: _switchToDriver,
                          onOpenWebsite: _openDriverApplicationWebsite,
                        ),
                      ],
                    ),
                  ),

                  // Nav items
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionLabel("Account"),
                        NavListItem(
                          icon: Icons.schedule_rounded,
                          label: "Ride History",
                          onTap: () =>
                              context.read<ValueNotifier<int>>().value = 1,
                        ),
                        NavListItem(
                          icon: Icons.notifications_none_rounded,
                          label: "Notifications",
                          onTap: () =>
                              context.read<ValueNotifier<int>>().value = 2,
                        ),
                        NavListItem(
                          icon: Icons.star_border_rounded,
                          label: "Saved Places",
                          onTap: () =>
                              pushPassengerPage(context, const FavoritesPage()),
                        ),
                        NavListItem(
                          icon: Icons.shield_outlined,
                          label: "Safety",
                          onTap: () =>
                              pushPassengerPage(context, const SafetyPage()),
                        ),
                        NavListItem(
                          icon: Icons.person_outline_rounded,
                          label: "Edit Profile",
                          onTap: _editProfile,
                        ),
                        NavListItem(
                          icon: Icons.help_outline_rounded,
                          label: "Help & Support",
                          onTap: () =>
                              pushPassengerPage(context, const SettingsPage()),
                        ),
                        NavListItem(
                          icon: Icons.settings_outlined,
                          label: "Settings",
                          onTap: () =>
                              pushPassengerPage(context, const SettingsPage()),
                        ),
                      ],
                    ),
                  ),

                  // Logout
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border:
                          Border(top: BorderSide(color: DesignTokens.border)),
                    ),
                    child: InkWell(
                      onTap: _logout,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded,
                                size: 20, color: DesignTokens.red),
                            const SizedBox(width: 12),
                            Text("Sign Out",
                                style: TextStyle(
                                    color: DesignTokens.red,
                                    fontSize: 14,
                                    fontWeight: DesignTokens.fw500)),
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

/// Driver-application status and the matching action.
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
      return Material(
        color: DesignTokens.accent,
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radius),
          onTap: onSwitchToDriver,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.electric_rickshaw_rounded, color: DesignTokens.bg),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Switch to Driver Mode",
                          style: TextStyle(
                              color: DesignTokens.bg,
                              fontWeight: DesignTokens.fw600)),
                      Text("Start accepting ride requests",
                          style:
                              TextStyle(color: DesignTokens.bg, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: DesignTokens.bg),
              ],
            ),
          ),
        ),
      );
    }

    final (String? label, Color color, IconData icon) = switch (status) {
      "pending" => (
          "Application submitted — Pending review",
          DesignTokens.warning,
          Icons.hourglass_bottom_rounded
        ),
      "rejected" => (
          "Application not approved. Reason: ${profileCtrl.driverRejectionReason ?? "Not specified"}",
          DesignTokens.red,
          Icons.error_outline_rounded
        ),
      "needs_correction" => (
          "Action required: ${profileCtrl.driverCorrectionNote ?? "Please update your documents and resubmit."}",
          DesignTokens.warning,
          Icons.error_outline_rounded
        ),
      _ => (null, DesignTokens.muted, Icons.person_outline_rounded),
    };

    final buttonLabel = switch (status) {
      "rejected" => "Resubmit Application",
      "needs_correction" => "Update Application",
      "pending" => "Application Website",
      _ => "Become a Driver",
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withAlpha(24),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              border: Border.all(color: color.withAlpha(70)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: DesignTokens.fw500)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpenWebsite,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(color: DesignTokens.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radius),
                  ),
                ),
                icon: Icon(Icons.open_in_new_rounded,
                    size: 16, color: DesignTokens.accent),
                label: Text(buttonLabel,
                    style: TextStyle(color: DesignTokens.accent)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 46,
              width: 46,
              child: OutlinedButton(
                onPressed: profileCtrl.isLoadingDriverStatus
                    ? null
                    : profileCtrl.loadDriverStatus,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: BorderSide(color: DesignTokens.border2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radius),
                  ),
                ),
                child: profileCtrl.isLoadingDriverStatus
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.refresh_rounded,
                        size: 18, color: DesignTokens.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
