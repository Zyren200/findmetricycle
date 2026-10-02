import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../state/notifications_controller.dart";

/// Notifications list shared by the passenger and driver apps.
///
/// Pushed as its own page, or embedded as a bottom-nav tab: pass
/// [tabIndex] and an ambient `ValueNotifier<int>` nav index, and the list
/// refreshes (and is marked read) each time that tab is opened.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen(
      {super.key, required this.controller, this.tabIndex});

  final NotificationsController controller;
  final int? tabIndex;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Which items were unread when the screen opened — they keep their
  // highlight while it's open, even though they're marked read right away.
  Set<dynamic> _freshIds = {};
  ValueNotifier<int>? _navIndex;

  @override
  void initState() {
    super.initState();
    if (widget.tabIndex == null) _open();
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
    if (_navIndex?.value == widget.tabIndex) _open();
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

  void _openRide() {
    final navIndex = _navIndex;
    if (navIndex != null) {
      navIndex.value = 0; // Home tab, where the ride is shown
    } else {
      Navigator.of(context).pop();
    }
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
                  onRefresh: _open,
                  child: ctrl.isLoading && ctrl.items.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            if (ctrl.error != null && ctrl.items.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: ErrorBox(
                                    message: ctrl.error!, onRetry: _open),
                              )
                            else if (ctrl.items.isEmpty)
                              const EmptyState(
                                icon: Icons.notifications_none_rounded,
                                message: "No notifications",
                              ),
                            for (final n in ctrl.items)
                              _NotificationTile(
                                notification: n,
                                fresh: _freshIds.contains(n["id"]) ||
                                    !NotificationsController.isRead(n),
                                // Ride-related ones: back to Home, where the
                                // ride itself is shown.
                                onTap: _opensRide(n["type"]?.toString())
                                    ? _openRide
                                    : null,
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(
      {required this.notification, required this.fresh, this.onTap});

  final Map<String, dynamic> notification;
  final bool fresh;
  final VoidCallback? onTap;

  // A getter, so the colours follow the current light/dark palette.
  static Map<String, (IconData, Color)> get _styles => {
    "announcement": (Icons.campaign_rounded, DesignTokens.accent),
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
    final (icon, color) =
        _styles[type] ?? (Icons.notifications_rounded, DesignTokens.accent);
    final when =
        timeAgo(notification["created_at"] ?? notification["createdAt"]);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: fresh ? DesignTokens.accent.withAlpha(18) : Colors.transparent,
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
                color: fresh ? DesignTokens.accent : DesignTokens.border2,
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: fresh ? FontWeight.w700 : FontWeight.w500,
                      color: DesignTokens.text,
                    ),
                  ),
                  if (notification["body"] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      notification["body"].toString(),
                      style: TextStyle(color: DesignTokens.muted, fontSize: 12),
                    ),
                  ],
                  if (when != null) ...[
                    const SizedBox(height: 4),
                    Text(when,
                        style:
                            TextStyle(color: DesignTokens.muted, fontSize: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color.withAlpha(36),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(icon, size: 12, color: color),
            ),
          ],
        ),
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
  const months = [
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
  return "${months[date.month - 1]} ${date.day}, ${date.year}";
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
