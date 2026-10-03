import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../state/notifications_controller.dart";
import "notification_detail_page.dart";

/// Notifications list shared by the passenger and driver apps — an inbox:
/// unread ones stand out until they're opened, and tapping one opens it in
/// full ([NotificationDetailPage]).
///
/// Pushed as its own page, or embedded as a bottom-nav tab: pass
/// [tabIndex] and an ambient `ValueNotifier<int>` nav index, and the list
/// refreshes each time that tab is opened.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen(
      {super.key, required this.controller, this.tabIndex});

  final NotificationsController controller;
  final int? tabIndex;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  ValueNotifier<int>? _navIndex;

  @override
  void initState() {
    super.initState();
    if (widget.tabIndex == null) _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.tabIndex == null || _navIndex != null) return;
    _navIndex = context.read<ValueNotifier<int>>()..addListener(_onTabChanged);
    _onTabChanged();
  }

  @override
  void dispose() {
    _navIndex?.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (_navIndex?.value == widget.tabIndex) _refresh();
  }

  Future<void> _refresh() => widget.controller.load();

  void _openRide() {
    final navIndex = _navIndex;
    if (navIndex != null) {
      navIndex.value = 0; // Home tab, where the ride is shown
    } else {
      Navigator.of(context).pop();
    }
  }

  void _openNotification(Map<String, dynamic> notification) {
    widget.controller.markRead(notification);
    final type = notification["type"]?.toString();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailPage(
          notification: notification,
          // Ride-related ones offer a way back to the ride on Home.
          onOpenRide: _opensRide(type) ? _openRide : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          AppTopBar(
            title: "Notifications",
            showBack: widget.tabIndex == null,
            trailing: ListenableBuilder(
              listenable: ctrl,
              builder: (context, _) => TextButton.icon(
                onPressed: ctrl.unread == 0 ? null : ctrl.markAllRead,
                icon: Icon(Icons.done_all_rounded,
                    size: 16, color: DesignTokens.accent),
                label: Text("All read",
                    style: TextStyle(color: DesignTokens.accent)),
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: ctrl,
              builder: (context, _) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ctrl.isLoading && ctrl.items.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            if (ctrl.error != null && ctrl.items.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: ErrorBox(
                                    message: ctrl.error!, onRetry: _refresh),
                              )
                            else if (ctrl.items.isEmpty)
                              const EmptyState(
                                icon: Icons.notifications_none_rounded,
                                message: "No notifications",
                              ),
                            for (final n in ctrl.items)
                              _NotificationTile(
                                notification: n,
                                unread: !NotificationsController.isRead(n),
                                onTap: () => _openNotification(n),
                              ),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
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

/// Icon, colour and category label for a notification type.
({IconData icon, Color color, String label}) notificationStyle(String? type) {
  return switch (type) {
    "announcement" => (
        icon: Icons.campaign_rounded,
        color: DesignTokens.accent,
        label: "Announcement"
      ),
    "ride_request" => (
        icon: Icons.electric_rickshaw_rounded,
        color: DesignTokens.accent,
        label: "Ride request"
      ),
    "booking_accepted" => (
        icon: Icons.check_circle_rounded,
        color: DesignTokens.green,
        label: "Ride accepted"
      ),
    "booking_declined" => (
        icon: Icons.person_off_rounded,
        color: DesignTokens.warning,
        label: "Rider unavailable"
      ),
    "booking_cancelled" => (
        icon: Icons.cancel_rounded,
        color: DesignTokens.red,
        label: "Ride cancelled"
      ),
    "driver_arrived" => (
        icon: Icons.place_rounded,
        color: DesignTokens.accent,
        label: "Rider arrived"
      ),
    "ride_started" => (
        icon: Icons.directions_rounded,
        color: DesignTokens.blue,
        label: "Trip started"
      ),
    "ride_completed" => (
        icon: Icons.flag_rounded,
        color: DesignTokens.green,
        label: "Trip completed"
      ),
    "new_rating" => (
        icon: Icons.star_rounded,
        color: Colors.amber,
        label: "New rating"
      ),
    "driver_approved" => (
        icon: Icons.verified_rounded,
        color: DesignTokens.green,
        label: "Driver application"
      ),
    "driver_rejected" => (
        icon: Icons.block_rounded,
        color: DesignTokens.red,
        label: "Driver application"
      ),
    _ => (
        icon: Icons.notifications_rounded,
        color: DesignTokens.accent,
        label: "Notification"
      ),
  };
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(
      {required this.notification, required this.unread, required this.onTap});

  final Map<String, dynamic> notification;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = notificationStyle(notification["type"]?.toString());
    final when =
        timeAgo(notification["created_at"] ?? notification["createdAt"]);
    final body = notification["body"]?.toString();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              unread ? DesignTokens.accent.withAlpha(18) : Colors.transparent,
          border: Border(bottom: BorderSide(color: DesignTokens.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: unread ? DesignTokens.accent : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification["title"]?.toString() ?? "Notification",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      color: DesignTokens.text,
                    ),
                  ),
                  if (body != null && body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: DesignTokens.muted, fontSize: 12),
                    ),
                  ],
                  if (when != null) ...[
                    const SizedBox(height: 4),
                    Text(when,
                        style: TextStyle(
                          color: unread ? DesignTokens.text : DesignTokens.muted,
                          fontSize: 11,
                          fontWeight: unread ? FontWeight.w600 : null,
                        )),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: style.color.withAlpha(36),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(style.icon, size: 12, color: style.color),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: DesignTokens.muted),
          ],
        ),
      ),
    );
  }
}

const _months = [
  "Ene",
  "Peb",
  "Mar",
  "Abr",
  "May",
  "Hun",
  "Hul",
  "Ago",
  "Set",
  "Okt",
  "Nob",
  "Dis"
];

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
  return "${_months[date.month - 1]} ${date.day}, ${date.year}";
}

/// "Okt 3, 2026 · 9:15 AM" — the full time shown on an opened notification.
String? fullDateTime(dynamic raw) {
  final date = DateTime.tryParse(raw?.toString() ?? "")?.toLocal();
  if (date == null) return null;
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, "0");
  final suffix = date.hour < 12 ? "AM" : "PM";
  return "${_months[date.month - 1]} ${date.day}, ${date.year} · $hour:$minute $suffix";
}

/// 🔔 button with an unread-count badge.
class NotificationBell extends StatelessWidget {
  const NotificationBell(
      {super.key, required this.controller, required this.onPressed});

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
              count > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_outlined,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}
