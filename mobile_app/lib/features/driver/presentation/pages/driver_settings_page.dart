import "package:flutter/material.dart";

import "../../../shared/presentation/map_credits.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:permission_handler/permission_handler.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../../core/components/index.dart";
import "../../../../core/config/app_config.dart";
import "../../../../core/state/app_preferences.dart";
import "../../../../core/theme/design_tokens.dart";
import "../../../shared/presentation/change_password_page.dart";
import "../../../shared/presentation/contact_support_sheet.dart";
import "../../../shared/state/session_store.dart";
import "../driver_edit_profile_page.dart";
import "../driver_ride_controller.dart";
import "../widgets/driver_ride_actions.dart";

/// Driver Mode settings: account, notifications, app preferences,
/// permissions, documents, support and sign-out.
class DriverSettingsPage extends StatefulWidget {
  const DriverSettingsPage({super.key});

  @override
  State<DriverSettingsPage> createState() => _DriverSettingsPageState();
}

class _DriverSettingsPageState extends State<DriverSettingsPage>
    with WidgetsBindingObserver {
  PermissionStatus? _locationStatus;
  PermissionStatus? _notificationStatus;

  // Ride-request alerts matter to drivers; passenger-only ones are left out.
  static const _notificationKeys = {
    "rideUpdates": "Ride Requests & Updates",
    "applicationUpdates": "Application / Account Updates",
    "announcements": "Important Announcements",
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the system Settings app: show the new permission state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermissions();
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

  void _editProfile() {
    final ctrl = context.read<DriverRideController>();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: ctrl,
        child: const DriverEditProfilePage(),
      ),
    ));
  }

  Future<void> _changePassword() async {
    final ctrl = context.read<DriverRideController>();
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Password updated.")));
    }
  }

  Future<void> _openUrl(String url) async {
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open the link.")));
    }
  }

  void _info(String title, String message) {
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

  Future<void> _logout() async {
    final confirmed = await confirmSun(
      context,
      title: "Log out?",
      message: "You'll go offline and stop getting ride requests.",
      confirmLabel: "Log out",
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !mounted) return;

    // Go offline first so the rider stops showing up as available.
    final ctrl = context.read<DriverRideController>();
    if (ctrl.isOnline) await ctrl.setOnline(false);
    if (!mounted) return;
    final storage = context.read<FlutterSecureStorage>();
    final sessionStore = context.read<SessionStore>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    // AppRouter shows the login screen once the session is gone.
    await sessionStore.logout(storage);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferences>();
    final ctrl = context.watch<DriverRideController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const AppTopBar(title: "Settings", showBack: true),
          Expanded(
            child: ListView(
              children: [
                _Group(
                  title: "Account & Security",
                  children: [
                    NavListItem(
                        icon: Icons.person_outline_rounded,
                        label: "Edit Profile",
                        onTap: _editProfile),
                    NavListItem(
                        icon: Icons.lock_outline_rounded,
                        label: "Change Password",
                        onTap: _changePassword),
                  ],
                ),
                _Group(
                  title: "Notifications",
                  children: [
                    for (final entry in _notificationKeys.entries)
                      _Toggle(
                        label: entry.value,
                        value: prefs.isNotificationEnabled(entry.key),
                        onChanged: (v) =>
                            prefs.setNotificationEnabled(entry.key, v),
                      ),
                  ],
                ),
                _Group(
                  title: "App Preferences",
                  children: [
                    NavListItem(
                      icon: Icons.language_outlined,
                      label: "Language",
                      onTap: null,
                      trailing: DropdownButton<String>(
                        value: prefs.language,
                        underline: const SizedBox.shrink(),
                        dropdownColor: DesignTokens.bg2,
                        items: const [
                          DropdownMenuItem(value: "en", child: Text("English")),
                          DropdownMenuItem(
                              value: "fil", child: Text("Filipino")),
                        ],
                        onChanged: (v) {
                          if (v != null) prefs.setLanguage(v);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Segmented<ThemeMode>(
                        semanticLabel: "Theme",
                        value: prefs.themeMode,
                        onChanged: prefs.setThemeMode,
                        options: const [
                          (ThemeMode.light, "Light", Icons.light_mode_outlined),
                          (ThemeMode.dark, "Dark", Icons.dark_mode_outlined),
                          (
                            ThemeMode.system,
                            "System",
                            Icons.smartphone_rounded
                          ),
                        ],
                      ),
                    ),
                    _Toggle(
                      label: "Sound Effects",
                      value: prefs.soundEnabled,
                      onChanged: prefs.setSoundEnabled,
                    ),
                    _Toggle(
                      label: "Vibration",
                      value: prefs.vibrationEnabled,
                      onChanged: prefs.setVibrationEnabled,
                    ),
                  ],
                ),
                _Group(
                  title: "Location & Permissions",
                  children: [
                    _Permission(
                      label: "Location",
                      hint: "Needed to go online and receive ride requests",
                      status: _locationStatus,
                      onFix: () async {
                        await Permission.locationWhenInUse.request();
                        _refreshPermissions();
                      },
                    ),
                    _Permission(
                      label: "Notifications",
                      hint: "So you don't miss ride requests",
                      status: _notificationStatus,
                      onFix: () async {
                        await Permission.notification.request();
                        _refreshPermissions();
                      },
                    ),
                    NavListItem(
                      icon: Icons.gps_fixed_rounded,
                      label: "GPS",
                      onTap: null,
                      trailing: Text(
                        ctrl.gpsEnabled ? "On" : "Off",
                        style: TextStyle(
                            color: ctrl.gpsEnabled
                                ? DesignTokens.green
                                : DesignTokens.red),
                      ),
                    ),
                  ],
                ),
                _Group(
                  title: "Driver",
                  children: [
                    _Toggle(
                      label: "Auto Online",
                      subtitle: prefs.driverAutoOnline
                          ? "You go Online automatically when Driver Mode opens"
                          : "You start Offline — tap GO ONLINE on Home when ready",
                      value: prefs.driverAutoOnline,
                      onChanged: (v) async {
                        await prefs.setDriverAutoOnline(v);
                        // Turning it on also takes effect right away.
                        if (v && !ctrl.isOnline && ctrl.activeBooking == null) {
                          await ctrl.setOnline(true);
                          if (!context.mounted || ctrl.error == null) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ctrl.error!)));
                        }
                      },
                    ),
                    NavListItem(
                      icon: Icons.upload_file_rounded,
                      label: "Update Documents",
                      onTap: () => _openUrl(AppConfig.driverApplyUrl),
                    ),
                    const NavListItem(
                      icon: Icons.payments_outlined,
                      label: "Payment Method",
                      onTap: null,
                      trailing: StatusChip("Cash", tone: ChipTone.primary),
                    ),
                  ],
                ),
                _Group(
                  title: "Help & Support",
                  children: [
                    NavListItem(
                      icon: Icons.help_outline_rounded,
                      label: "Help Center",
                      onTap: () => _info(
                        "Help Center",
                        "• Go online from Home to start receiving ride requests.\n\n"
                            "• A new request opens automatically — accept it before the timer runs out.\n\n"
                            "• At pickup, ask the passenger for their 4-digit PIN to start the ride.\n\n"
                            "• Collect the cash fare when you complete the ride.",
                      ),
                    ),
                    NavListItem(
                      icon: Icons.report_problem_outlined,
                      label: "Report a Problem",
                      onTap: () => showDriverReportDialog(context, ctrl),
                    ),
                    NavListItem(
                      icon: Icons.support_agent_outlined,
                      label: "Contact Support",
                      onTap: () => showContactSupport(context),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: MapCreditsSection(),
                ),
                _Group(
                  title: "About",
                  children: [
                    NavListItem(
                      icon: Icons.info_outline_rounded,
                      label: "About FindMeTricycle",
                      onTap: () => _info(
                        "About FindMeTricycle",
                        "FindMeTricycle connects passengers with local tricycle drivers for fast, "
                            "affordable rides. Version 1.0.0.",
                      ),
                    ),
                    NavListItem(
                      icon: Icons.tag_outlined,
                      label: "App Version",
                      onTap: null,
                      trailing: Text("1.0.0",
                          style: TextStyle(color: DesignTokens.muted)),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: SunButton(
                    label: "Log out",
                    tone: SunTone.outline,
                    height: 48,
                    foreground: DesignTokens.sosText,
                    onPressed: _logout,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(title),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: DesignTokens.surface,
              borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
              border: Border.all(color: DesignTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: DesignTokens.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: DesignTokens.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                            color: DesignTokens.ink2,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SunSwitch(value: value, onChanged: onChanged, label: label),
          ],
        ),
      ),
    );
  }
}

class _Permission extends StatelessWidget {
  const _Permission({
    required this.label,
    required this.hint,
    required this.status,
    required this.onFix,
  });

  final String label;
  final String hint;
  final PermissionStatus? status;
  final Future<void> Function() onFix;

  @override
  Widget build(BuildContext context) {
    final granted = status?.isGranted ?? false;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: DesignTokens.line)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label,
            style: TextStyle(
                color: DesignTokens.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        subtitle: Text(
          status == null
              ? "Checking…"
              : (granted ? "Allowed" : "Permission required — $hint"),
          style: TextStyle(
              color: granted ? DesignTokens.lagoonText : DesignTokens.sosText,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
        trailing: granted
            ? const StatusChip("Allowed", tone: ChipTone.ok)
            : TextButton(
                onPressed: () {
                  if (status?.isPermanentlyDenied ?? false) {
                    openAppSettings();
                  } else {
                    onFix();
                  }
                },
                child: const Text("Allow"),
              ),
      ),
    );
  }
}
