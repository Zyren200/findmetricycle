import "package:flutter/material.dart";

import "../../../shared/presentation/map_credits.dart";
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
import "../widgets/passenger_ride_widgets.dart";
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

    if (saved == true && mounted) showSunToast(context, "Password updated.");
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

    final storage = context.read<FlutterSecureStorage>();
    final sessionStore = context.read<SessionStore>();
    await sessionStore.logout(storage);
  }

  Future<void> _deleteAccount() async {
    final password = await showSunSheet<String>(
      context,
      builder: (_) => const _DeleteAccountCard(),
    );
    if (password == null || password.isEmpty || !mounted) return;

    final ctrl = context.read<PassengerProfileController>();
    final ok = await ctrl.deleteAccount(password: password);
    if (!mounted) return;

    if (ok) {
      final storage = context.read<FlutterSecureStorage>();
      final sessionStore = context.read<SessionStore>();
      await sessionStore.logout(storage);
    } else {
      showSunToast(context, ctrl.profileError ?? "Failed to delete account.");
    }
  }

  /// FavoritesPage needs PassengerRideController and the shell's nav-index
  /// ValueNotifier, neither of which are ambient here — SettingsPage itself
  /// only received the shell controllers by value, so they're threaded
  /// through again before pushing.
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
    showSunSheet<void>(
      context,
      builder: (dialogContext) => SunSheetCard(
        title: title,
        message: message,
        align: CrossAxisAlignment.start,
        actions: [
          SunButton(
            label: "Close",
            tone: SunTone.quiet,
            height: 48,
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  void _reportProblem() =>
      reportPassengerProblem(context, context.read<PassengerRideController>());

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferences>();

    Widget section(String title, List<Widget> rows) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel(title),
              SunListCard(children: rows),
            ],
          ),
        );

    Widget toggle(String label, bool value, ValueChanged<bool> onChanged,
            {IconData? icon}) =>
        SunListRow(
          icon: icon,
          label: label,
          trailing: SunSwitch(value: value, onChanged: onChanged, label: label),
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const AppTopBar(title: "Settings", showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
                const SizedBox(height: 20),
                section("Account & Security", [
                  SunListRow(
                    icon: Icons.lock_outline_rounded,
                    label: "Change Password",
                    onTap: _changePassword,
                  ),
                  const SunListRow(
                    icon: Icons.mark_email_read_outlined,
                    label: "Email Verification",
                    trailing: StatusChip("Verified", tone: ChipTone.ok),
                  ),
                  const SunListRow(
                    icon: Icons.phone_android_outlined,
                    label: "Mobile Number Verification",
                    trailing: StatusChip("Verified", tone: ChipTone.ok),
                  ),
                ]),
                section("Notifications", [
                  for (final key in AppPreferences.notificationKeys)
                    toggle(
                      _notificationLabel(key),
                      prefs.isNotificationEnabled(key),
                      (v) => prefs.setNotificationEnabled(key, v),
                    ),
                ]),
                section("App Preferences", [
                  SunListRow(
                    icon: Icons.language_outlined,
                    label: "Language",
                    trailing: DropdownButton<String>(
                      value: prefs.language,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(16),
                      dropdownColor: DesignTokens.surface,
                      style: TextStyle(
                          color: DesignTokens.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: "en", child: Text("English")),
                        DropdownMenuItem(value: "fil", child: Text("Filipino")),
                      ],
                      onChanged: (v) {
                        if (v != null) prefs.setLanguage(v);
                      },
                    ),
                  ),
                  toggle("Sound Effects", prefs.soundEnabled,
                      prefs.setSoundEnabled,
                      icon: Icons.volume_up_outlined),
                  toggle("Vibration", prefs.vibrationEnabled,
                      prefs.setVibrationEnabled,
                      icon: Icons.vibration_rounded),
                ]),
                section("Location & Permissions", [
                  _PermissionTile(
                    label: "Location",
                    icon: Icons.location_on_outlined,
                    status: _locationStatus,
                    onFix: () async {
                      await Permission.locationWhenInUse.request();
                      _refreshPermissions();
                    },
                  ),
                  _PermissionTile(
                    label: "Notifications",
                    icon: Icons.notifications_none_rounded,
                    status: _notificationStatus,
                    onFix: () async {
                      await Permission.notification.request();
                      _refreshPermissions();
                    },
                  ),
                ]),
                section("Ride Preferences", [
                  SunListRow(
                    icon: Icons.groups_outlined,
                    label: "Default passengers",
                    trailing: SizedBox(
                      width: 136,
                      child: CountStepper(
                        value: prefs.defaultPassengerCount,
                        min: AppPreferences.minPassengers,
                        max: AppPreferences.maxPassengers,
                        onChanged: prefs.setDefaultPassengerCount,
                      ),
                    ),
                  ),
                  SunListRow(
                    icon: Icons.bookmark_border_rounded,
                    label: "Saved Places",
                    onTap: () => _openFavorites(context),
                  ),
                  const SunListRow(
                    icon: Icons.payments_outlined,
                    label: "Payment Method",
                    trailing: StatusChip("Cash", tone: ChipTone.primary),
                  ),
                ]),
                section("Help & Support", [
                  SunListRow(
                    icon: Icons.help_outline_rounded,
                    label: "Help Center",
                    onTap: () => _showInfoDialog(
                      "Help Center",
                      "Need a hand booking a ride, tracking a driver, or managing your account? "
                          "Tap Contact Support below to call or email us and we'll get back to you.",
                    ),
                  ),
                  SunListRow(
                    icon: Icons.quiz_outlined,
                    label: "FAQ",
                    onTap: () => _showInfoDialog(
                      "Frequently Asked Questions",
                      "• How do I book a ride? Tap Search destination on Home, choose where you're going, then tap Find a tricycle.\n\n"
                          "• How is the fare calculated? Base fare plus distance, with a small fee per extra passenger.\n\n"
                          "• How do I become a driver? Go to Profile and tap Become a Driver.\n\n"
                          "• More questions? Contact Support below.",
                    ),
                  ),
                  SunListRow(
                    icon: Icons.report_problem_outlined,
                    label: "Report a Problem",
                    onTap: _reportProblem,
                  ),
                  SunListRow(
                    icon: Icons.support_agent_outlined,
                    label: "Contact Support",
                    onTap: () => showContactSupport(context),
                  ),
                ]),
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: MapCreditsSection(),
                ),
                section("About", [
                  SunListRow(
                    icon: Icons.info_outline_rounded,
                    label: "About FindMeTricycle",
                    onTap: () => _showInfoDialog(
                      "About FindMeTricycle",
                      "FindMeTricycle connects passengers with local tricycle drivers in Guiuan for fast, "
                          "affordable rides. Version 1.0.0.",
                    ),
                  ),
                  SunListRow(
                    icon: Icons.description_outlined,
                    label: "Terms of Service",
                    onTap: () => _showInfoDialog(
                      "Terms of Service",
                      "Our full Terms of Service will be published here soon. "
                          "For questions in the meantime, use Contact Support under Help & Support.",
                    ),
                  ),
                  SunListRow(
                    icon: Icons.privacy_tip_outlined,
                    label: "Privacy Policy",
                    onTap: () => _showInfoDialog(
                      "Privacy Policy",
                      "Our full Privacy Policy will be published here soon. "
                          "For questions in the meantime, use Contact Support under Help & Support.",
                    ),
                  ),
                  SunListRow(
                    icon: Icons.tag_rounded,
                    label: "App Version",
                    trailing: Text("1.0.0",
                        style: TextStyle(
                            color: DesignTokens.ink2,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                SunButton(
                  label: "Log out",
                  tone: SunTone.outline,
                  height: 48,
                  foreground: DesignTokens.sosText,
                  onPressed: _logout,
                ),
                const SizedBox(height: 10),
                SunButton(
                  label: "Delete Account",
                  tone: SunTone.ghost,
                  height: 44,
                  foreground: DesignTokens.sosText,
                  onPressed: _deleteAccount,
                ),
              ],
            ),
          ),
        ],
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

/// Password prompt for "Delete Account"; pops with the password.
class _DeleteAccountCard extends StatefulWidget {
  const _DeleteAccountCard();

  @override
  State<_DeleteAccountCard> createState() => _DeleteAccountCardState();
}

class _DeleteAccountCardState extends State<_DeleteAccountCard> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SunSheetCard(
      title: "Delete Account",
      message:
          "This permanently deactivates your FindMeTricycle account. This action cannot be undone from the app. Enter your password to confirm.",
      icon: Icons.delete_outline_rounded,
      iconBg: DesignTokens.sosSoft,
      iconFg: DesignTokens.sosText,
      content: [
        SunField(
          label: "Password",
          controller: _password,
          obscure: true,
          icon: Icons.lock_outline_rounded,
          hint: "Enter your password",
        ),
      ],
      actions: [
        SunButton(
          label: "Delete Account",
          tone: SunTone.sos,
          onPressed: () => Navigator.pop(context, _password.text),
        ),
        SunButton(
          label: "Cancel",
          tone: SunTone.quiet,
          height: 48,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.label,
    required this.icon,
    required this.status,
    required this.onFix,
  });
  final String label;
  final IconData icon;
  final PermissionStatus? status;
  final Future<void> Function() onFix;

  @override
  Widget build(BuildContext context) {
    final granted = status?.isGranted ?? false;
    return SunListRow(
      icon: icon,
      label: label,
      subtitle: status == null
          ? "Checking…"
          : (granted ? "Allowed" : "Permission required"),
      trailing: granted
          ? const StatusChip("Allowed", tone: ChipTone.ok)
          : SunButton(
              label: "Allow",
              tone: SunTone.soft,
              height: 36,
              radius: 12,
              fontSize: 13,
              expand: false,
              onPressed: () {
                if (status?.isPermanentlyDenied ?? false) {
                  openAppSettings();
                } else {
                  onFix();
                }
              },
            ),
    );
  }
}
