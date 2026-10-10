import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../state/notifications_controller.dart";
import "notification_detail_page.dart";

/// "Alerts" — the notifications inbox shared by the passenger and driver
/// apps: unread ones carry an orange dot until they're opened, and tapping
/// one opens it in full ([NotificationDetailPage]).
///
/// Pushed as its own page, or embedded as a tab: pass [tabIndex] and an
/// ambient `ValueNotifier<int>` nav index, and the list refreshes each
/// time that tab is opened.
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
    final embedded = widget.tabIndex != null;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                embedded ? top + 28 : top + 12,
                20,
                embedded ? DesignTokens.tabBarClearance + 8 : 32,
              ),
              children: [
                if (!embedded) ...[
                  Row(children: [
                    BackSquareButton(
                        onTap: () => Navigator.of(context).maybePop()),
                  ]),
                  const SizedBox(height: 16),
                ],
                ScreenTitle(
                  "Alerts",
                  subtitle: "Ride updates and safety notices.",
                  trailing: SunLink(
                    label: "Mark all read",
                    onTap: ctrl.unread == 0 ? null : ctrl.markAllRead,
                  ),
                ),
                const SizedBox(height: 18),
                if (ctrl.isLoading && ctrl.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (ctrl.error != null && ctrl.items.isEmpty)
                  ErrorBox(message: ctrl.error!, onRetry: _refresh)
                else if (ctrl.items.isEmpty)
                  const EmptyState(
                    icon: Icons.notifications_none_rounded,
                    message: "No alerts yet.",
                  )
                else
                  ...Stagger.wrap([
                    for (final n in ctrl.items)
                      _NotificationTile(
                        notification: n,
                        unread: !NotificationsController.isRead(n),
                        onTap: () => _openNotification(n),
                      ),
                  ], gap: 10),
              ],
            ),
          );
        },
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
        icon: Icons.campaign_outlined,
        color: DesignTokens.ink2,
        label: "Announcement"
      ),
    "ride_request" => (
        icon: Icons.navigation_outlined,
        color: DesignTokens.primaryText,
        label: "Ride request"
      ),
    "booking_accepted" => (
        icon: Icons.navigation_outlined,
        color: DesignTokens.primaryText,
        label: "Ride accepted"
      ),
    "booking_declined" => (
        icon: Icons.person_off_outlined,
        color: DesignTokens.primaryText,
        label: "Rider unavailable"
      ),
    "booking_cancelled" => (
        icon: Icons.cancel_outlined,
        color: DesignTokens.sosText,
        label: "Ride cancelled"
      ),
    "driver_arrived" => (
        icon: Icons.place_outlined,
        color: DesignTokens.primaryText,
        label: "Rider arrived"
      ),
    "ride_started" => (
        icon: Icons.directions_outlined,
        color: DesignTokens.primaryText,
        label: "Trip started"
      ),
    "ride_completed" => (
        icon: Icons.flag_outlined,
        color: DesignTokens.lagoonText,
        label: "Trip completed"
      ),
    "new_rating" => (
        icon: Icons.star_outline_rounded,
        color: DesignTokens.star,
        label: "New rating"
      ),
    "driver_approved" => (
        icon: Icons.verified_user_outlined,
        color: DesignTokens.lagoonText,
        label: "Driver application"
      ),
    "driver_rejected" => (
        icon: Icons.block_rounded,
        color: DesignTokens.sosText,
        label: "Driver application"
      ),
    final String t when t.startsWith("sos") => (
        icon: Icons.health_and_safety_outlined,
        color: DesignTokens.lagoonText,
        label: "Safety"
      ),
    _ => (
        icon: Icons.notifications_none_rounded,
        color: DesignTokens.primaryText,
        label: "Notification"
      ),
  };
}

/// The soft tile behind a notification icon of [iconColor].
Color notificationTileColor(Color iconColor) {
  if (iconColor == DesignTokens.lagoonText) return DesignTokens.lagoonSoft;
  if (iconColor == DesignTokens.sosText) return DesignTokens.sosSoft;
  if (iconColor == DesignTokens.ink2) return DesignTokens.surface2;
  return DesignTokens.primarySoft;
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

    return SunCard(
      onTap: onTap,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 14, 32, 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: style.icon,
                size: 40,
                radius: 12,
                iconSize: 19,
                background: notificationTileColor(style.color),
                foreground: style.color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification["title"]?.toString() ?? "Notification",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w700,
                        color: DesignTokens.ink,
                      ),
                    ),
                    if (body != null && body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: DesignTokens.ink2,
                            fontSize: 13,
                            height: 18 / 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                    if (when != null) ...[
                      const SizedBox(height: 3),
                      Text(when,
                          style: TextStyle(
                            color: DesignTokens.ink2,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 4,
            right: -16,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 350),
              curve: DesignTokens.spring,
              scale: unread ? 1 : 0,
              child: Semantics(
                label: unread ? "Unread" : null,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: DesignTokens.primaryBright,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
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

/// Glass 🔔 button with a red unread-count badge.
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
        return Stack(
          clipBehavior: Clip.none,
          children: [
            GlassIconButton(
              icon: Icons.notifications_none_rounded,
              label:
                  count > 0 ? "Notifications ($count bago)" : "Notifications",
              onTap: onPressed,
            ),
            if (count > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: DesignTokens.ember,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: DesignTokens.bgDeep, width: 2),
                    boxShadow: [
                      BoxShadow(color: DesignTokens.glowEmber, blurRadius: 8)
                    ],
                  ),
                  child: Text(
                    count > 99 ? "99+" : "$count",
                    style: const TextStyle(
                        color: DesignTokens.sosInk,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
