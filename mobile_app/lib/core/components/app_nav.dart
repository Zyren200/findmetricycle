import 'package:flutter/material.dart';
import 'app_layout.dart';
import 'sunrise.dart';

/// App bar in the Sunrise style: the rounded back button (when the page
/// can go back) and the 22/28 title — the same header as [AppTopBar].
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color? backgroundColor;
  final List<Widget>? actions;
  final bool showLeading;

  const AppAppBar({
    required this.title,
    this.backgroundColor,
    this.actions,
    this.showLeading = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = showLeading && (ModalRoute.of(context)?.canPop ?? false);
    return AppTopBar(
      title: title,
      showBack: canPop,
      trailing: actions == null
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: actions!),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(68);
}

/// Bottom navigation as the Sunrise floating glass tab bar.
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;
  final List<BottomNavItem> items;

  const AppBottomNav({
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.items,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingTabBar(
      index: selectedIndex,
      onChanged: (i) => onIndexChanged(i),
      tabs: [
        for (final item in items)
          SunTab(
            icon: item.icon,
            label: item.label,
            badge: item.badgeCount ?? 0,
          ),
      ],
    );
  }
}

/// Bottom nav item model
class BottomNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  /// Unread count shown as a red badge on the icon (e.g. Alerts).
  final int? badgeCount;

  BottomNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badgeCount,
  });
}
