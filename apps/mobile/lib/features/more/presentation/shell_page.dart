import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class ShellPage extends StatelessWidget {
  const ShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _WebMobileNav(
        index: navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }
}

class _WebMobileNav extends StatelessWidget {
  const _WebMobileNav({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final surface = Theme.of(context).cardTheme.color ?? context.colors.surface;
    final selectedColor =
        context.isDark ? context.colors.primary : AppColors.teal700;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: surface.withValues(alpha: context.isDark ? 0.82 : 0.88),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: context.colors.outlineVariant.withValues(alpha: 0.8),
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(8, 6, 8, bottom > 0 ? bottom : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _NavTab(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Home',
                  selected: index == 0,
                  selectedColor: selectedColor,
                  onTap: () => onTap(0),
                ),
                _NavTab(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Activity',
                  selected: index == 1,
                  selectedColor: selectedColor,
                  onTap: () => onTap(1),
                ),
                _AddTab(
                  selected: index == 2,
                  selectedColor: selectedColor,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onTap(2);
                  },
                ),
                _NavTab(
                  icon: Icons.menu_rounded,
                  label: 'More',
                  selected: index == 3,
                  selectedColor: selectedColor,
                  onTap: () => onTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : context.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTab extends StatelessWidget {
  const _AddTab({
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: const Offset(0, -16),
              child: AnimatedScale(
                scale: selected ? 1 : 0.96,
                duration: AppDuration.fast,
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected ? selectedColor : AppColors.teal500,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal500.withValues(
                          alpha: context.isDark ? 0.28 : 0.28,
                        ),
                        blurRadius: selected ? 18 : 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: context.isDark && selected
                        ? context.colors.onPrimary
                        : Colors.white,
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -12),
              child: Text(
                'Add',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? selectedColor : context.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
