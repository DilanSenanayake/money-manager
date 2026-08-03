import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../authentication/data/auth_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <_MoreItem>[
      _MoreItem(
        Icons.account_balance_wallet_outlined,
        'Accounts',
        'Wallets and balances',
        RoutePaths.accounts,
      ),
      _MoreItem(
        Icons.pie_chart_outline_rounded,
        'Budgets',
        'Categories and limits',
        RoutePaths.budgets,
      ),
      _MoreItem(
        Icons.insights_outlined,
        'Analytics',
        'Trends and category spend',
        RoutePaths.analytics,
      ),
      _MoreItem(
        Icons.event_repeat_outlined,
        'Recurring',
        'Upcoming bills',
        RoutePaths.recurring,
      ),
      _MoreItem(
        Icons.settings_outlined,
        'Settings',
        'Profile and exchange rates',
        RoutePaths.settings,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => context.push(item.route),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.teal500.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: AppColors.teal700),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            item.subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.slate),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Sign out',
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              ref.invalidate(dashboardProvider);
              if (context.mounted) context.go(RoutePaths.login);
            },
          ),
        ],
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem(this.icon, this.title, this.subtitle, this.route);
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}
