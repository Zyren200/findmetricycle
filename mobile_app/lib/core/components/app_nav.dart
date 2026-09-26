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
        style: const TextStyle(
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
      iconTheme: const IconThemeData(color: DesignTokens.text),
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
      decoration: const BoxDecoration(
        color: DesignTokens.bg2,
        border: Border(
          top: BorderSide(color: DesignTokens.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(
          items.length,
          (index) {
            final item = items[index];
            final isSelected = index == selectedIndex;
            return GestureDetector(
              onTap: () => onIndexChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: DesignTokens.spacing12,
                  horizontal: DesignTokens.spacing14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 24 : 0,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: DesignTokens.accent,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: DesignTokens.accent.withAlpha(140),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected ? DesignTokens.accent : DesignTokens.muted,
                      size: 26,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: DesignTokens.fontSize12,
                        fontWeight: DesignTokens.fw600,
                        color: isSelected ? DesignTokens.accent : DesignTokens.muted,
                        fontFamily: DesignTokens.fontDmSans,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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

  BottomNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
  });
}
