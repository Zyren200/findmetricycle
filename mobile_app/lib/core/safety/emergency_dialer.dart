import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

import "../components/sunrise.dart";
import "../theme/design_tokens.dart";

/// The number SOS opens the dialer with. Production builds dial 911; pilot
/// and test builds pass a safe number instead so testers never reach the
/// real hotline:
///   flutter build apk --dart-define=EMERGENCY_NUMBER=09XXXXXXXXX
const String kEmergencyNumber =
    String.fromEnvironment("EMERGENCY_NUMBER", defaultValue: "911");

/// A build whose SOS dials something other than 911 — labelled on screen.
const bool kIsEmergencyTestBuild = kEmergencyNumber != "911";

/// Opens the phone's dialer with [kEmergencyNumber] filled in (ACTION_DIAL).
/// The user still taps Call: Android only lets the system dialer place
/// emergency calls. False when there's no dialer (e.g. a tablet).
Future<bool> openEmergencyDialer() async {
  final uri = Uri(scheme: "tel", path: kEmergencyNumber);
  try {
    if (!await canLaunchUrl(uri)) return false;
    return await launchUrl(uri);
  } catch (_) {
    return false;
  }
}

/// "TEST MODE: dials 0917…" — shown wherever SOS is confirmed in a build
/// that doesn't dial 911.
class EmergencyTestModeLabel extends StatelessWidget {
  const EmergencyTestModeLabel({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsEmergencyTestBuild) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DesignTokens.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        "TEST MODE: dials $kEmergencyNumber",
        style: TextStyle(
          color: DesignTokens.primaryText,
          fontSize: 12,
          fontWeight: DesignTokens.fw800,
        ),
      ),
    );
  }
}

/// When the dialer can't open: the number, large, to dial by hand.
Future<void> showDialManuallyDialog(BuildContext context) {
  return showSunSheet<void>(
    context,
    builder: (dialogContext) => SunSheetCard(
      title: "Call for help",
      message: "This device couldn't open the phone dialer. Call this number "
          "from any phone:",
      icon: Icons.phone_in_talk_rounded,
      iconBg: DesignTokens.sosSoft,
      iconFg: DesignTokens.sosText,
      content: [
        SelectableText(
          kEmergencyNumber,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: DesignTokens.sosText,
            fontSize: 44,
            fontWeight: DesignTokens.fw800,
            letterSpacing: 2,
            fontFeatures: DesignTokens.tabular,
          ),
        ),
        if (kIsEmergencyTestBuild) const EmergencyTestModeLabel(),
      ],
      actions: [
        SunButton(
          label: "OK",
          tone: SunTone.ink,
          height: 52,
          onPressed: () => Navigator.pop(dialogContext),
        ),
      ],
    ),
  );
}
