import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../../core/components/index.dart";
import "../../../../core/theme/design_tokens.dart";
import "../passenger_ride_controller.dart";
import "../widgets/passenger_ride_widgets.dart";

/// Safety: emergency SOS (sent to the admin team with the passenger's
/// location), emergency hotline and the current ride's details.
class SafetyPage extends StatelessWidget {
  const SafetyPage({super.key});

  Future<void> _call(BuildContext context, String number) async {
    final ok = await launchUrl(Uri(scheme: "tel", path: number));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Could not open the dialer. Call $number directly.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PassengerRideController>();
    final ongoing = hasOngoingBooking(ctrl);

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          const AppTopBar(title: "Safety", showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                InfoBox(
                  color: DesignTokens.red.withAlpha(20),
                  borderColor: DesignTokens.red.withAlpha(70),
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: DesignTokens.red),
                        const SizedBox(width: 8),
                        Text("Emergency SOS",
                            style: TextStyle(
                                color: DesignTokens.red,
                                fontWeight: DesignTokens.fw600)),
                      ],
                    ),
                    Text(
                      "Press this button in an emergency. Your location will be sent to the "
                      "FindMeTricycle admin team right away.",
                      style: TextStyle(color: DesignTokens.red, fontSize: 12),
                    ),
                    PrimaryActionButton(
                      label: ctrl.isSendingSos ? "Sending SOS..." : "SEND SOS",
                      icon: Icons.warning_amber_rounded,
                      color: DesignTokens.red,
                      foregroundColor: Colors.white,
                      loading: ctrl.isSendingSos,
                      onPressed: () => confirmAndSendSos(context, ctrl),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InfoBox(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone_rounded,
                            size: 16, color: DesignTokens.text),
                        const SizedBox(width: 8),
                        Text("Emergency Contacts",
                            style: TextStyle(
                                color: DesignTokens.text,
                                fontWeight: DesignTokens.fw500)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text("Emergency Hotline",
                              style: TextStyle(
                                  color: DesignTokens.muted, fontSize: 13)),
                        ),
                        TextButton(
                          onPressed: () => _call(context, "911"),
                          child: Text("911",
                              style: TextStyle(
                                  color: DesignTokens.accent,
                                  fontWeight: DesignTokens.fw600)),
                        ),
                      ],
                    ),
                  ],
                ),
                if (ongoing) ...[
                  const SizedBox(height: 16),
                  InfoBox(
                    color: DesignTokens.blue.withAlpha(20),
                    borderColor: DesignTokens.blue.withAlpha(70),
                    spacing: 4,
                    children: [
                      Text("Current Ride Info",
                          style: TextStyle(
                              color: DesignTokens.blue,
                              fontSize: 13,
                              fontWeight: DesignTokens.fw600)),
                      Text("Ride ID: ${ctrl.activeBookingId}",
                          style: TextStyle(
                              color: DesignTokens.blue, fontSize: 12)),
                      if (ctrl.driverName != null)
                        Text("Driver: ${ctrl.driverName}",
                            style: TextStyle(
                                color: DesignTokens.blue, fontSize: 12)),
                      if (ctrl.driverTricycle != null)
                        Text("Tricycle: ${ctrl.driverTricycle}",
                            style: TextStyle(
                                color: DesignTokens.blue, fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
