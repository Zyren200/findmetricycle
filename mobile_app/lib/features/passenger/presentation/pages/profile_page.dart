import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";
import "../../../../core/components/index.dart";
import "../../../../core/config/app_config.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../shared/state/session_store.dart";
import "../passenger_profile_controller.dart";
import "../passenger_ride_controller.dart";
import "edit_profile_page.dart";
import "settings_page.dart";

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PassengerProfileController>().loadUserProfile();
    });
  }

  /// SettingsPage (and the FavoritesPage it can push for "Saved Places")
  /// live outside PassengerShellPage's local MultiProvider once pushed via
  /// Navigator — a pushed route's Overlay entry is a sibling of the shell's
  /// subtree, not a descendant of it, so the shell-scoped controllers are
  /// re-supplied by value here instead of relying on ambient inheritance.
  void _openSettings(BuildContext context) {
    final profileController = context.read<PassengerProfileController>();
    final rideController = context.read<PassengerRideController>();
    final navIndex = context.read<ValueNotifier<int>>();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: profileController),
            ChangeNotifierProvider.value(value: rideController),
            ChangeNotifierProvider.value(value: navIndex),
          ],
          child: const SettingsPage(),
        ),
      ),
    );
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
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;

    final ctrl = context.read<PassengerProfileController>();
    final ok = await ctrl.updateProfile(profileImage: file);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? "Profile picture updated." : (ctrl.profileError ?? "Failed to update photo."))),
    );
  }

  Future<void> _openDriverApplicationWebsite() async {
    final uri = Uri.parse(AppConfig.driverApplyUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open the driver application website.")),
      );
    }
  }

  Future<void> _switchMode() async {
    final storage = context.read<FlutterSecureStorage>();
    final sessionStore = context.read<SessionStore>();
    final profileCtrl = context.read<PassengerProfileController>();
    final currentMode = sessionStore.session?.effectiveRole ?? "passenger";
    await sessionStore.setActiveRole(
      storage,
      currentMode == "driver" ? "passenger" : "driver",
      knownApproved: profileCtrl.driverStatus == "approved",
    );
  }

  void _logout() async {
    final storage = context.read<FlutterSecureStorage>();
    final sessionStore = context.read<SessionStore>();
    await sessionStore.logout(storage);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed("/login");
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionStore = context.watch<SessionStore>();
    final session = sessionStore.session;
    final profileCtrl = context.watch<PassengerProfileController>();
    final driverStatus = profileCtrl.driverStatus ?? "none";
    final isLoadingDriver = profileCtrl.isLoadingDriverStatus;
    final activeMode = session?.effectiveRole ?? "passenger";
    final profileImagePath = profileCtrl.userProfile?["profile_image_url"] as String?;
    final profileImageUrl =
        profileImagePath == null ? null : AppConfig.resolveAssetUrl(profileImagePath);

    final initials = session?.fullName
            .split(' ')
            .where((segment) => segment.isNotEmpty)
            .map((segment) => segment[0])
            .take(2)
            .join() ??
        "P";

    return Scaffold(
      body: Container(
        color: DesignTokens.bg,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(DesignTokens.spacing16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Profile",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: DesignTokens.text),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => _openSettings(context),
                ),
              ],
            ),
            // Profile Header
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _changeProfilePicture,
                    child: Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                            gradient: const LinearGradient(
                              colors: [DesignTokens.accent, DesignTokens.accent2],
                            ),
                            image: profileImageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(profileImageUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: profileImageUrl != null
                              ? null
                              : Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: DesignTokens.fontSize20,
                                    fontWeight: DesignTokens.fw700,
                                    fontFamily: DesignTokens.fontSyne,
                                  ),
                                ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: DesignTokens.bg2,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session?.fullName ?? "Passenger",
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: DesignTokens.text),
                        ),
                        const SizedBox(height: DesignTokens.spacing6),
                        Text(
                          session?.phone ?? "-",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: DesignTokens.spacing8),
                        Text(
                          "Current Mode: ${activeMode == "driver" ? "Driver" : "Passenger"}",
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: DesignTokens.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spacing16),

            // Become a Driver Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: DesignTokens.border),
                borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                color: DesignTokens.bg3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Become a Driver",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Earn money by accepting ride bookings",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: DesignTokens.muted),
                  ),
                  const SizedBox(height: 12),
                  if (isLoadingDriver)
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (driverStatus == "none")
                    AppButton(
                      label: "Become a Driver",
                      onPressed: _openDriverApplicationWebsite,
                      height: 44,
                    )
                  else if (driverStatus == "pending")
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2D7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_bottom_rounded,
                              color: Color(0xFF9F6A00)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Application Pending",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF9F6A00),
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Your documents are under review",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF9F6A00),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (driverStatus == "approved")
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F6EC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF0E8C46)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Approved! 🎉",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF0E8C46),
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "You can now switch to Driver mode",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF0E8C46),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: activeMode == "driver"
                              ? "Switch to Passenger"
                              : "Switch to Driver",
                          onPressed: _switchMode,
                          height: 44,
                        ),
                      ],
                    )
                  else if (driverStatus == "rejected")
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE5E5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Application Not Approved",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFFD32F2F),
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Reason: ${profileCtrl.driverRejectionReason ?? "Not specified"}",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFFD32F2F),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: "Resubmit Application",
                          onPressed: _openDriverApplicationWebsite,
                          height: 44,
                        ),
                      ],
                    )
                  else if (driverStatus == "needs_correction")
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF2D7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Action Required",
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF9F6A00),
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profileCtrl.driverCorrectionNote ??
                                    "Please update your documents and resubmit.",
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF9F6A00),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: "Update Application",
                          onPressed: _openDriverApplicationWebsite,
                          height: 44,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spacing24),

            // Account Info
            Text(
              "Account",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DesignTokens.muted,
                  ),
            ),
            const SizedBox(height: DesignTokens.spacing12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileInfoRow(
                    label: "Full Name",
                    value: session?.fullName ?? "-",
                  ),
                  _ProfileInfoRow(
                    label: "Email",
                    value: profileCtrl.userProfile?["email"]?.toString() ?? "-",
                  ),
                  _ProfileInfoRow(
                    label: "Mobile Number",
                    value: session?.phone ?? "-",
                  ),
                  _ProfileInfoRow(
                    label: "Address",
                    value: profileCtrl.userProfile?["address"]?.toString() ?? "-",
                  ),
                  const SizedBox(height: 4),
                  AppButton(
                    label: "Edit Profile",
                    style: AppButtonStyle.ghost,
                    onPressed: _editProfile,
                    height: 44,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spacing16),

            // Logout
            AppButton(
              label: "Logout",
              style: AppButtonStyle.destructive,
              onPressed: _logout,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: DesignTokens.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
