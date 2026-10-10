import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/components/index.dart";
import "../../../core/state/app_config_store.dart";
import "../../../core/theme/design_tokens.dart";

/// "Contact Support" for both passenger and driver settings — uses the
/// support email / number the admin set in Settings, so the apps never
/// point at a placeholder address.
Future<void> showContactSupport(BuildContext context) async {
  final config = context.read<AppConfigStore>();
  await config.refresh();
  if (!context.mounted) return;

  if (!config.hasSupportContact) {
    await showSunSheet<void>(
      context,
      builder: (dialogContext) => SunSheetCard(
        title: "Contact Support",
        message:
            "Support contact details haven't been set up yet. Please try again later.",
        icon: Icons.support_agent_rounded,
        iconBg: DesignTokens.primarySoft,
        iconFg: DesignTokens.primaryText,
        actions: [
          SunButton(
            label: "OK",
            tone: SunTone.ink,
            height: 52,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
    return;
  }

  await showSunSheet<void>(
    context,
    builder: (sheetContext) {
      Future<void> open(Uri uri) async {
        Navigator.of(sheetContext).pop();
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      return SunSheetCard(
        title: "Contact Support",
        message: config.operatingHoursLabel.isEmpty
            ? "We're here to help with bookings, rides and your account."
            : "Service hours: ${config.operatingHoursLabel}",
        icon: Icons.support_agent_rounded,
        iconBg: DesignTokens.primarySoft,
        iconFg: DesignTokens.primaryText,
        content: [
          SunListCard(children: [
            if (config.contactNumber.isNotEmpty)
              SunListRow(
                icon: Icons.call_rounded,
                iconBg: DesignTokens.lagoonSoft,
                iconFg: DesignTokens.lagoonText,
                label: "Call",
                subtitle: config.contactNumber,
                onTap: () => open(Uri(
                  scheme: "tel",
                  path: config.contactNumber.replaceAll(RegExp(r"[^0-9+]"), ""),
                )),
              ),
            if (config.supportEmail.isNotEmpty)
              SunListRow(
                icon: Icons.mail_outline_rounded,
                iconBg: DesignTokens.primarySoft,
                iconFg: DesignTokens.primaryText,
                label: "Email",
                subtitle: config.supportEmail,
                onTap: () =>
                    open(Uri(scheme: "mailto", path: config.supportEmail)),
              ),
          ]),
        ],
        actions: [
          SunButton(
            label: "Close",
            tone: SunTone.quiet,
            height: 48,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      );
    },
  );
}
