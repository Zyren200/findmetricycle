import "package:flutter/material.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "notifications_screen.dart";

/// One notification opened in full, like opening an email: what kind it is,
/// when it came, the whole message, and the ride details it carries.
class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({
    super.key,
    required this.notification,
    this.onOpenRide,
  });

  final Map<String, dynamic> notification;

  /// Set for notifications about a ride in progress: shows "View ride".
  final VoidCallback? onOpenRide;

  @override
  Widget build(BuildContext context) {
    final type = notification["type"]?.toString();
    final style = notificationStyle(type);
    final title = notification["title"]?.toString() ?? "Notification";
    final body = notification["body"]?.toString().trim() ?? "";
    final when =
        fullDateTime(notification["created_at"] ?? notification["createdAt"]);
    final details = _details(notification["metadata"]);

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          const AppTopBar(title: "Notification", showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: style.color.withAlpha(36),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(style.icon, size: 20, color: style.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            style.label,
                            style: TextStyle(
                              color: style.color,
                              fontSize: 12,
                              fontWeight: DesignTokens.fw600,
                            ),
                          ),
                          if (when != null)
                            Text(
                              when,
                              style: TextStyle(
                                  color: DesignTokens.muted, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    color: DesignTokens.text,
                    fontSize: 20,
                    fontWeight: DesignTokens.fw700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  body.isEmpty ? "(No message)" : body,
                  style: TextStyle(
                    color: DesignTokens.text,
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  InfoBox(
                    children: [
                      for (final (label, value) in details)
                        InfoRow(label: label, value: value),
                    ],
                  ),
                ],
                if (onOpenRide != null) ...[
                  const SizedBox(height: 24),
                  PrimaryActionButton(
                    label: "View ride",
                    icon: Icons.electric_rickshaw_rounded,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onOpenRide!();
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ride number, fare, stars and reason, when the notification has them.
  static List<(String, String)> _details(dynamic raw) {
    if (raw is! Map) return const [];
    final details = <(String, String)>[];
    final bookingId = raw["bookingId"];
    if (bookingId != null) details.add(("Ride", "#$bookingId"));
    final fare = double.tryParse(raw["finalFare"]?.toString() ?? "");
    if (fare != null) details.add(("Fare", "₱${fare.toStringAsFixed(2)}"));
    final stars = int.tryParse(raw["stars"]?.toString() ?? "");
    if (stars != null) details.add(("Rating", "${"★" * stars}${"☆" * (5 - stars)}"));
    final reason = raw["reason"]?.toString().trim();
    if (reason != null && reason.isNotEmpty) {
      final readable = reason.replaceAll("_", " ");
      details.add(("Reason", readable[0].toUpperCase() + readable.substring(1)));
    }
    return details;
  }
}
