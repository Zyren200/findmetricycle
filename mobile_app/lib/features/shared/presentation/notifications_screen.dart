import "package:flutter/material.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../state/notifications_controller.dart";

/// Notifications list shared by the passenger and driver apps.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.controller});

  final NotificationsController controller;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Which items were unread when the screen opened — they keep their
  // highlight while it's open, even though they're marked read right away.
  Set<dynamic> _freshIds = {};

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    await widget.controller.load();
    if (!mounted) return;
    setState(() {
      _freshIds = widget.controller.items
          .where((n) => !NotificationsController.isRead(n))
          .map((n) => n["id"])
          .toSet();
    });
    await widget.controller.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: Container(
        color: DesignTokens.bg,
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final ctrl = widget.controller;
            return RefreshIndicator(
              onRefresh: _open,
              child: ctrl.isLoading && ctrl.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ctrl.error != null && ctrl.items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            Center(child: Text(ctrl.error!)),
                            Center(
                              child: TextButton(onPressed: _open, child: const Text("Subukan ulit")),
                            ),
                          ],
                        )
                      : ctrl.items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 80),
                                Icon(Icons.notifications_none_rounded,
                                    size: 48, color: DesignTokens.muted),
                                SizedBox(height: 16),
                                Center(child: Text("Wala pang notification")),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(DesignTokens.spacing16),
                              itemCount: ctrl.items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: DesignTokens.spacing8),
                              itemBuilder: (context, index) {
                                final n = ctrl.items[index];
                                return _NotificationTile(
                                  notification: n,
                                  fresh: _freshIds.contains(n["id"]) ||
                                      !NotificationsController.isRead(n),
                                  // Ride-related ones: back to the map/home,
                                  // where the ride itself is shown.
                                  onTap: _opensRide(n["type"]?.toString())
                                      ? () => Navigator.of(context).pop()
                                      : null,
                                );
                              },
                            ),
            );
          },
        ),
      ),
    );
  }

  static bool _opensRide(String? type) => const {
        "ride_request",
        "booking_accepted",
        "booking_declined",
        "booking_cancelled",
        "driver_arrived",
        "ride_started",
      }.contains(type);
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.fresh, this.onTap});

  final Map<String, dynamic> notification;
  final bool fresh;
  final VoidCallback? onTap;

  static const Map<String, (IconData, Color)> _styles = {
    "ride_request": (Icons.electric_rickshaw_rounded, DesignTokens.accent),
    "booking_accepted": (Icons.check_circle_rounded, DesignTokens.green),
    "booking_declined": (Icons.person_off_rounded, DesignTokens.warning),
    "booking_cancelled": (Icons.cancel_rounded, DesignTokens.red),
    "driver_arrived": (Icons.place_rounded, DesignTokens.accent),
    "ride_started": (Icons.directions_rounded, DesignTokens.blue),
    "ride_completed": (Icons.flag_rounded, DesignTokens.green),
    "new_rating": (Icons.star_rounded, Colors.amber),
    "driver_approved": (Icons.verified_rounded, DesignTokens.green),
    "driver_rejected": (Icons.block_rounded, DesignTokens.red),
  };

  @override
  Widget build(BuildContext context) {
    final type = notification["type"]?.toString();
    final (icon, color) = _styles[type] ?? (Icons.notifications_rounded, DesignTokens.accent);
    final when = timeAgo(notification["created_at"] ?? notification["createdAt"]);

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withAlpha(fresh ? 40 : 20),
            child: Icon(icon, size: 18, color: fresh ? color : DesignTokens.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification["title"]?.toString() ?? "Notification",
                        style: TextStyle(
                          fontWeight: fresh ? FontWeight.w800 : FontWeight.w600,
                          color: DesignTokens.text,
                        ),
                      ),
                    ),
                    if (fresh)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                          color: DesignTokens.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (notification["body"] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    notification["body"].toString(),
                    style: const TextStyle(color: DesignTokens.muted, fontSize: 13),
                  ),
                ],
                if (when != null) ...[
                  const SizedBox(height: 6),
                  Text(when, style: const TextStyle(color: DesignTokens.muted, fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ngayon lang", "5 min ang nakalipas", "Kahapon", or a date.
String? timeAgo(dynamic raw, {DateTime? now}) {
  final date = DateTime.tryParse(raw?.toString() ?? "")?.toLocal();
  if (date == null) return null;
  final diff = (now ?? DateTime.now()).difference(date);
  if (diff.inMinutes < 1) return "Ngayon lang";
  if (diff.inMinutes < 60) return "${diff.inMinutes} min ang nakalipas";
  if (diff.inHours < 24) return "${diff.inHours} oras ang nakalipas";
  if (diff.inDays == 1) return "Kahapon";
  if (diff.inDays < 7) return "${diff.inDays} araw ang nakalipas";
  const months = ["Ene", "Peb", "Mar", "Abr", "May", "Hun", "Hul", "Ago", "Set", "Okt", "Nob", "Dis"];
  return "${months[date.month - 1]} ${date.day}, ${date.year}";
}

/// 🔔 button with an unread-count badge.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.controller, required this.onPressed});

  final NotificationsController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final count = controller.unread;
        return IconButton(
          onPressed: onPressed,
          color: DesignTokens.text,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: count > 0 ? "Notifications ($count bago)" : "Notifications",
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? "99+" : "$count"),
            child: Icon(
              count > 0 ? Icons.notifications_active_rounded : Icons.notifications_outlined,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}
