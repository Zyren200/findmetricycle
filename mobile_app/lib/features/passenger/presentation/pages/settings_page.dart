import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:permission_handler/permission_handler.dart";
import "package:provider/provider.dart";
import "../../../../core/components/index.dart";
import "../../../../core/state/app_preferences.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../shared/presentation/change_password_page.dart";
import "../../../shared/presentation/contact_support_sheet.dart";
import "../../../shared/state/session_store.dart";
import "../passenger_profile_controller.dart";
import "../passenger_ride_controller.dart";
import "favorites_page.dart";

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  PermissionStatus? _locationStatus;
  PermissionStatus? _notificationStatus;

  @override
  void initState() {
    super.initState();
    _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final location = await Permission.locationWhenInUse.status;
    final notification = await Permission.notification.status;
    if (!mounted) return;
    setState(() {
      _locationStatus = location;
      _notificationStatus = notification;
    });
  }

  Future<void> _changePassword() async {
    final ctrl = context.read<PassengerProfileController>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangePasswordPage(
          requestOtp: (currentPassword) =>
              ctrl.requestPasswordChangeOtp(currentPassword: currentPassword),
          confirmChange: (currentPassword, newPassword, otp) =>
              ctrl.confirmPasswordChange(
            currentPassword: currentPassword,
            newPassword: newPassword,
            otp: otp,
            keepRefreshToken:
                context.read<SessionStore>().session?.refreshToken,
          ),
        ),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password updated.")),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text("Logout", style: TextStyle(color: DesignTokens.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final storage = context.read<FlutterSecureStorage>();
    final sessionStore = context.read<SessionStore>();
    await sessionStore.logout(storage);
    if (mounted) {
      // AppRouter shows the login screen once the session is gone.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _deleteAccount() async {
    final passwordCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Account"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This permanently deactivates your FindMeTricycle account. This action cannot be undone from the app. Enter your password to confirm.",
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text("Delete Account",
                style: TextStyle(color: DesignTokens.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (passwordCtrl.text.isEmpty) return;

    final ctrl = context.read<PassengerProfileController>();
    final ok = await ctrl.deleteAccount(password: passwordCtrl.text);
    if (!mounted) return;

    if (ok) {
      final storage = context.read<FlutterSecureStorage>();
      final sessionStore = context.read<SessionStore>();
      await sessionStore.logout(storage);
      if (mounted) {
        // AppRouter shows the login screen once the session is gone.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ctrl.profileError ?? "Failed to delete account.")),
      );
    }
  }

  /// FavoritesPage needs PassengerRideController and the shell's nav-index
  /// ValueNotifier, neither of which are ambient here — SettingsPage itself
  /// only received PassengerProfileController from ProfilePage's push, so
  /// the other two are threaded through by value as well before pushing.
  void _openFavorites(BuildContext context) {
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
          child: const FavoritesPage(),
        ),
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _reportProblem() {
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text("Report a Problem"),
        children: [
          _ReportOptionTile(
              label: "Booking issue",
              onTap: () => Navigator.pop(dialogContext)),
          _ReportOptionTile(
              label: "Driver issue", onTap: () => Navigator.pop(dialogContext)),
          _ReportOptionTile(
              label: "Fare issue", onTap: () => Navigator.pop(dialogContext)),
          _ReportOptionTile(
              label: "App issue", onTap: () => Navigator.pop(dialogContext)),
          _ReportOptionTile(
              label: "Account issue",
              onTap: () => Navigator.pop(dialogContext)),
          _ReportOptionTile(
              label: "Other", onTap: () => Navigator.pop(dialogContext)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferences>();

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Container(
        color: DesignTokens.bg,
        child: ListView(
          padding: const EdgeInsets.all(DesignTokens.spacing16),
          children: [
            const _SectionTitle("Account & Security"),
            AppCard(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.lock_outline,
                    label: "Change Password",
                    onTap: _changePassword,
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: Icons.mark_email_read_outlined,
                    label: "Email Verification",
                    trailing: Text("Verified",
                        style: TextStyle(color: DesignTokens.green)),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: Icons.phone_android_outlined,
                    label: "Mobile Number Verification",
                    trailing: Text("Verified",
                        style: TextStyle(color: DesignTokens.green)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spacing20),
            const _SectionTitle("Notifications"),
            AppCard(
              child: Column(
                children: [
                  for (final key in AppPreferences.notificationKeys) ...[
                    _ToggleTile(
                      label: _notificationLabel(key),
                      value: prefs.isNotificationEnabled(key),
                      onChanged: (v) => prefs.setNotificationEnabled(key, v),
                    ),
                    if (key != AppPreferences.notificationKeys.last)
                      const _SettingsDivider(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spacing20),
            const _SectionTitle("App Preferences"),
            AppCard(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.language_outlined,
                    label: "Language",
                    trailing: DropdownButton<String>(
                      value: prefs.language,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: "en", child: Text("English")),
                        DropdownMenuItem(value: "fil", child: Text("Filipino")),
                      ],
                      onChanged: (v) {
                        if (v != null) prefs.setLanguage(v);
                      },
                    ),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: Icons.dark_mode_outlined,
                    label: "Dark Mode",
                    trailing: Switch(
                      value: DesignTokens.isDark,
                      onChanged: (v) => prefs
                          .setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
                    ),
                  ),
                  const _SettingsDivider(),
                  _ToggleTile(
                    label: "Sound Effects",
                    value: prefs.soundEnabled,
                    onChanged: prefs.setSoundEnabled,
                  ),
                  const _SettingsDivider(),
                  _ToggleTile(
                    label: "Vibration",
                    value: prefs.vibrationEnabled,
                    onChanged: prefs.setVibrationEnabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spacing20),
            const _SectionTitle("Location & Permissions"),
            AppCard(
              child: Column(
                children: [
                  _PermissionTile(
                    label: "Location",
                    status: _locationStatus,
                    onFix: () async {
                      await Permission.locationWhenInUse.request();
                      _refreshPermissions();
                    },
                  ),
                  const _SettingsDivider(),
                  _PermissionTile(
                    label: "Notifications",
                    status: _notificationStatus,
                    onFix: () async {
                      await Permission.notification.request();
                      _refreshPermissions();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spacing20),
            const _SectionTitle("Ride Preferences"),
            AppCard(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Default Passenger Count"),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: prefs.defaultPassengerCount <=
                                      AppPreferences.minPassengers
                                  ? null
                                  : () => prefs.setDefaultPassengerCount(
                                      prefs.defaultPassengerCount - 1),
                            ),
                            Text(
                              "${prefs.defaultPassengerCount}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: prefs.defaultPassengerCount >=
                                      AppPreferences.maxPassengers
                                  ? null
                                  : () => prefs.setDefaultPassengerCount(
                                      prefs.defaultPassengerCount + 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: Icons.bookmark_border_rounded,
                    label: "Saved Places",
                    onTap: () => _openFavorites(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spacing20),
            const _SectionTitle("Payment Method"),
            const AppCard(
              child: _SettingsTile(
                icon: Icons.payments_outlined,
                label: "Payment Method",
                trailing: Text("💵 Cash"),
              ),
            ),
            const SizedBox(height: DesignTokens.spacing20),
            const _SectionTitle("Help & Support"),
            AppCard(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.help_outline,
                    label: "Help Center",
                    onTap: () => _showInfoDialog(
                      "Help Center",
                      "Need a hand booking a ride, tracking a driver, or managing your account? "
                          "Tap Contact Support below to call or email us and we'll get back to you.",
                    ),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: Icons.quiz_outlined,
                    label: "FAQ",
                    onTap: () => _showInfoDialog(
                      "Frequently Asked Questions",
                      "• How do I book a ride? Set your pickup and drop-off on the map, then tap Find Ride.\n\n"
                          "• How is the fare calculated? Base fare plus distance, with a small fee per extra passenger.\n\n"
                          "• How do I become a driver? Go to Profile and tap Become a Driver.\n\n"
                          "• More questions? Contact Support below.",
                    ),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                      icon: Icons.report_problem_outlined,
                      label: "Report a Problem",
                      onTap: _reportProblem),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: Icons.support_agent_outlined,
                    label: "Contact Support",
                    onTap: () => showContactSupport(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spacing20),
            const _SectionTitle("About"),
            AppCard(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.info_outline,
                    label: "About FindMeTricycle",
                    onTap: () => _showInfoDialog(
                      "About FindMeTricycle",
                      "FindMeTricycle connects passengers with local tricycle drivers for fast, "
                          "affordable rides. Version 1.0.0.",
                    ),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    label: "Terms of Service",
                    onTap: () => _showInfoDialog(
                      "Terms of Service",
                      "Our full Terms of Service will be published here soon. "
                          "For questions in the meantime, use Contact Support under Help & Support.",
                    ),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    label: "Privacy Policy",
                    onTap: () => _showInfoDialog(
                      "Privacy Policy",
                      "Our full Privacy Policy will be published here soon. "
                          "For questions in the meantime, use Contact Support under Help & Support.",
                    ),
                  ),
                  const _SettingsDivider(),
                  const _SettingsTile(
                    icon: Icons.tag_outlined,
                    label: "App Version",
                    trailing: Text("1.0.0"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spacing20),
            AppButton(
                label: "Logout",
                style: AppButtonStyle.destructive,
                onPressed: _logout),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _deleteAccount,
              style: OutlinedButton.styleFrom(
                foregroundColor: DesignTokens.red,
                side: BorderSide(color: DesignTokens.red),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text("Delete Account"),
            ),
            const SizedBox(height: DesignTokens.spacing24),
          ],
        ),
      ),
    );
  }

  String _notificationLabel(String key) {
    switch (key) {
      case "rideUpdates":
        return "Ride Updates";
      case "driverAccepted":
        return "Driver Accepted";
      case "driverArrived":
        return "Driver Arrived";
      case "tripStarted":
        return "Trip Started";
      case "tripCompleted":
        return "Trip Completed";
      case "applicationUpdates":
        return "Application Updates";
      case "announcements":
        return "Important Announcements";
      default:
        return key;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: DesignTokens.muted,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: DesignTokens.border);
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile(
      {required this.icon, required this.label, this.trailing, this.onTap});
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: DesignTokens.muted),
      title: Text(label),
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right, color: DesignTokens.muted)
              : null),
      onTap: onTap,
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile(
      {required this.label, required this.status, required this.onFix});
  final String label;
  final PermissionStatus? status;
  final Future<void> Function() onFix;

  @override
  Widget build(BuildContext context) {
    final granted = status?.isGranted ?? false;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        status == null
            ? "Checking…"
            : (granted ? "Allowed" : "Permission Required"),
        style:
            TextStyle(color: granted ? DesignTokens.green : DesignTokens.red),
      ),
      trailing: granted
          ? Icon(Icons.check_circle, color: DesignTokens.green)
          : TextButton(
              onPressed: () {
                if (status?.isPermanentlyDenied ?? false) {
                  openAppSettings();
                } else {
                  onFix();
                }
              },
              child: const Text("Fix"),
            ),
    );
  }
}

class _ReportOptionTile extends StatelessWidget {
  const _ReportOptionTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onTap,
      child: Text(label),
    );
  }
}
