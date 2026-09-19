import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/open_url.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../authentication/data/auth_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            const PageHeader(
              title: 'More',
              description: 'Accounts, budgets, analytics, and settings',
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MoreTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Accounts',
                    subtitle: 'Cash, bank, and credit wallets',
                    onTap: () => context.push(RoutePaths.accounts),
                  ),
                  Divider(height: 1, color: context.colors.outlineVariant),
                  _MoreTile(
                    icon: Icons.savings_outlined,
                    title: 'Budgets',
                    subtitle: 'Category limits and progress',
                    onTap: () => context.push(RoutePaths.budgets),
                  ),
                  Divider(height: 1, color: context.colors.outlineVariant),
                  _MoreTile(
                    icon: Icons.pie_chart_outline_rounded,
                    title: 'Analytics',
                    subtitle: 'Trends and category charts',
                    onTap: () => context.push(RoutePaths.analytics),
                  ),
                  Divider(height: 1, color: context.colors.outlineVariant),
                  _MoreTile(
                    icon: Icons.event_repeat_outlined,
                    title: 'Recurring',
                    subtitle: 'Bills and repeating payments',
                    onTap: () => context.push(RoutePaths.recurring),
                  ),
                  Divider(height: 1, color: context.colors.outlineVariant),
                  _MoreTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Profile, currency, exchange rates',
                    onTap: () => context.push(RoutePaths.settings),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
                ref.invalidate(dashboardProvider);
                if (context.mounted) context.go(RoutePaths.login);
              },
              child: Text(
                'Sign out',
                style: TextStyle(color: context.muted),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                TextButton(
                  onPressed: () => openExternalUrl(AppConfig.termsUrl),
                  child: Text(
                    'Terms',
                    style: TextStyle(color: context.muted, fontSize: 12),
                  ),
                ),
                Text('·', style: TextStyle(color: context.muted)),
                TextButton(
                  onPressed: () => openExternalUrl(AppConfig.privacyUrl),
                  child: Text(
                    'Privacy',
                    style: TextStyle(color: context.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minTileHeight: 56,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.isDark
              ? context.colors.primary.withValues(alpha: 0.16)
              : AppColors.teal50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: context.isDark ? context.colors.primary : AppColors.teal700,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: context.muted,
      ),
    );
  }
}
