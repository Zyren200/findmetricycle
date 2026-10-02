import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Contact Support"),
        content: const Text(
          "Support contact details haven't been set up yet. Please try again later.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: DesignTokens.bg2,
    showDragHandle: true,
    builder: (sheetContext) {
      Future<void> open(Uri uri) async {
        Navigator.of(sheetContext).pop();
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                "Contact Support",
                style: TextStyle(
                  color: DesignTokens.text,
                  fontSize: 18,
                  fontWeight: DesignTokens.fw600,
                ),
              ),
            ),
            if (config.operatingHoursLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  "Service hours: ${config.operatingHoursLabel}",
                  style: TextStyle(color: DesignTokens.muted, fontSize: 13),
                ),
              ),
            if (config.contactNumber.isNotEmpty)
              ListTile(
                leading: Icon(Icons.call_rounded, color: DesignTokens.accent),
                title: Text("Call", style: TextStyle(color: DesignTokens.text)),
                subtitle: Text(config.contactNumber,
                    style: TextStyle(color: DesignTokens.muted)),
                onTap: () => open(Uri(
                  scheme: "tel",
                  path: config.contactNumber.replaceAll(RegExp(r"[^0-9+]"), ""),
                )),
              ),
            if (config.supportEmail.isNotEmpty)
              ListTile(
                leading: Icon(Icons.email_outlined, color: DesignTokens.accent),
                title:
                    Text("Email", style: TextStyle(color: DesignTokens.text)),
                subtitle: Text(config.supportEmail,
                    style: TextStyle(color: DesignTokens.muted)),
                onTap: () =>
                    open(Uri(scheme: "mailto", path: config.supportEmail)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
