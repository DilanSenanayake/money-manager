import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/components/components.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/dashboard_repository.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledgerly'),
        actions: [
          IconButton(
            tooltip: 'Add',
            onPressed: () => context.go(RoutePaths.add),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is Failure ? e.message : e.toString(),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (data) {
          final name = data.profile.displayName?.isNotEmpty == true
              ? data.profile.displayName!
              : 'there';
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Text(
                  'Hi, $name',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here’s your money at a glance',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.slate,
                      ),
                ),
                const SizedBox(height: 20),
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net worth',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.slate,
                            ),
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: data.netWorth),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return Text(
                            formatMoney(value, data.baseCurrency),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Income',
                        value: formatMoney(data.income, data.baseCurrency),
                        icon: Icons.south_west_rounded,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'Spent',
                        value: formatMoney(data.expense, data.baseCurrency),
                        icon: Icons.north_east_rounded,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Quick add',
                  actionLabel: 'Open',
                  onAction: () => context.go(RoutePaths.add),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.edit_note_rounded,
                        label: 'Manual',
                        onTap: () => context.go(RoutePaths.add),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.document_scanner_outlined,
                        label: 'Receipt',
                        onTap: () => context.go('${RoutePaths.add}?mode=receipt'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.sms_outlined,
                        label: 'SMS',
                        onTap: () => context.go('${RoutePaths.add}?mode=sms'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Accounts',
                  actionLabel: 'All',
                  onAction: () => context.push(RoutePaths.accounts),
                ),
                const SizedBox(height: 8),
                if (data.accounts.isEmpty)
                  const AppCard(
                    child: Text('No accounts yet. Create one from More.'),
                  )
                else
                  ...data.accounts.take(4).map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        a.type,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppColors.slate),
                                      ),
                                    ],
                                  ),
                                ),
                                MoneyText(a.balance, currency: a.currency),
                              ],
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 16),
                SectionHeader(
                  title: 'Budgets',
                  actionLabel: 'Manage',
                  onAction: () => context.push(RoutePaths.budgets),
                ),
                const SizedBox(height: 8),
                if (data.budgets.isEmpty)
                  const AppCard(
                    child: Text('Set monthly budgets to track spending.'),
                  )
                else
                  ...data.budgets.take(3).map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: BudgetBar(progress: b),
                        ),
                      ),
                const SizedBox(height: 16),
                SectionHeader(
                  title: 'Recent',
                  actionLabel: 'Activity',
                  onAction: () => context.go(RoutePaths.activity),
                ),
                const SizedBox(height: 8),
                if (data.recent.isEmpty)
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions yet',
                    message: 'Add your first expense in about 30 seconds.',
                    actionLabel: 'Add now',
                    onAction: () => context.go(RoutePaths.add),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: data.recent
                          .map(
                            (t) => TxTile(
                              transaction: t,
                              currency: t.account?.currency ?? data.baseCurrency,
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
