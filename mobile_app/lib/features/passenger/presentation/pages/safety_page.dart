import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/safety/emergency_dialer.dart";
import "../../../../core/safety/sos_flow.dart";
import "../../../../core/theme/design_tokens.dart";
import "../passenger_ride_controller.dart";
import "../widgets/passenger_ride_widgets.dart";

/// Safety: emergency SOS (sent to the admin team with the passenger's
/// location, then the dialer opens), the emergency hotline and the current
/// ride's details.
class SafetyPage extends StatelessWidget {
  const SafetyPage({super.key});

  /// The hotline row dials the same number SOS does.
  Future<void> _callHotline(BuildContext context) async {
    final ok = await openEmergencyDialer();
    if (!ok && context.mounted) await showDialManuallyDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PassengerRideController>();
    final ongoing = hasOngoingBooking(ctrl);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const AppTopBar(title: "Safety and SOS", showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                SosStatusBanner(
                    delivery: ctrl.sosDelivery, error: ctrl.sosError),
                FadeRise(
                  child: Column(
                    children: [
                      SosBigButton(
                        caption: ctrl.isSendingSos
                            ? "Sending alert…"
                            : "Tap in an emergency",
                        onTap: ctrl.isSendingSos
                            ? null
                            : () => confirmAndSendSos(context, ctrl),
                      ),
                      Text(
                        "We alert the FindMeTricycle admin with your location and ride, then open your dialer with $kEmergencyNumber.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: DesignTokens.ink2,
                            fontSize: 13.5,
                            height: 1.5),
                      ),
                      const SizedBox(height: 10),
                      const EmergencyTestModeLabel(),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const SectionLabel("Emergency contacts"),
                SunListCard(children: [
                  SunListRow(
                    icon: Icons.call_outlined,
                    label: "Emergency hotline",
                    subtitle: "Police, fire and medical",
                    trailing: SunButton(
                      label: kEmergencyNumber,
                      tone: SunTone.danger,
                      height: 36,
                      expand: false,
                      onPressed: () => _callHotline(context),
                    ),
                  ),
                ]),
                if (ongoing) ...[
                  const SizedBox(height: 18),
                  const SectionLabel("Current ride"),
                  InfoBox(
                    spacing: 8,
                    children: [
                      InfoRow(
                          label: "Ride ID", value: "#${ctrl.activeBookingId}"),
                      if (ctrl.driverName != null)
                        InfoRow(label: "Driver", value: ctrl.driverName!),
                      if (ctrl.driverTricycle != null)
                        InfoRow(label: "Tricycle", value: ctrl.driverTricycle!),
                      InfoRow(label: "Status", value: rideStatusHeadline(ctrl)),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                const SectionLabel("Ride safely"),
                const _Tip(
                  icon: Icons.verified_user_outlined,
                  text:
                      "Check the rider's name and tricycle number before you ride.",
                ),
                const _Tip(
                  icon: Icons.pin_outlined,
                  text:
                      "Give your pickup PIN only when your rider has arrived.",
                ),
                const _Tip(
                  icon: Icons.payments_outlined,
                  text: "Pay in cash at drop-off — never before the trip.",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          IconTile(
            icon: icon,
            size: 36,
            radius: 11,
            iconSize: 18,
            background: DesignTokens.lagoonSoft,
            foreground: DesignTokens.lagoonText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: DesignTokens.ink1,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}
