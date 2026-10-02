import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Custom app bar
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
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: DesignTokens.fontSize20,
          fontWeight: DesignTokens.fw700,
          color: DesignTokens.accent,
          fontFamily: DesignTokens.fontSyne,
        ),
      ),
      backgroundColor: backgroundColor ?? DesignTokens.bg,
      foregroundColor: DesignTokens.text,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
      actions: actions,
      automaticallyImplyLeading: showLeading,
      iconTheme: IconThemeData(color: DesignTokens.text),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

/// Custom bottom navigation bar
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
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.bg2,
        border: Border(
          top: BorderSide(color: DesignTokens.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(
            items.length,
            (index) {
              final item = items[index];
              final isSelected = index == selectedIndex;
              final color =
                  isSelected ? DesignTokens.accent : DesignTokens.muted;
              final badge = item.badgeCount ?? 0;
              return Expanded(
                child: InkWell(
                  onTap: () => onIndexChanged(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge(
                          isLabelVisible: badge > 0,
                          label: Text(badge > 9 ? "9+" : "$badge"),
                          backgroundColor: DesignTokens.red,
                          child: Icon(
                            isSelected
                                ? (item.activeIcon ?? item.icon)
                                : item.icon,
                            color: color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: DesignTokens.fontSize11,
                            fontWeight: isSelected
                                ? DesignTokens.fw600
                                : DesignTokens.fw500,
                            color: color,
                            fontFamily: DesignTokens.fontDmSans,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
