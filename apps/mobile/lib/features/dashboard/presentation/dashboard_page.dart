import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/labels.dart';
import '../../../core/utils/money.dart';
import '../../../shared/components/components.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/dashboard_repository.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);

    return Scaffold(
      body: SafeArea(
        child: async.when(
          loading: () => const DashboardSkeleton(),
          error: (e, _) => ErrorView(
            message: e is Failure
                ? e.message
                : "Couldn't load your money overview.",
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
          data: (data) {
            final firstName = data.profile?.displayName?.trim().isNotEmpty == true
                ? data.profile!.displayName!.split(' ').first
                : null;
            final empty = data.recent.isEmpty;
            final alerts = data.budgets
                .where((b) => b.status == 'warn' || b.status == 'over')
                .toList();
            final missingFx = hasMissingExchangeRate(
              data.accounts,
              data.baseCurrency,
              data.rates,
            );

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(dashboardProvider),
              child: ListView(
                padding: AppSpacing.page,
                children: [
                  FadeUp(
                    child: PageHeader(
                      title: firstName == null
                          ? 'Welcome back'
                          : 'Welcome back, $firstName',
                      description: AppConstants.tagline,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeUp(
                    delay: const Duration(milliseconds: 40),
                    child: CaptureModeGrid(
                    compact: true,
                    modes: [
                      CaptureMode(
                        icon: Icons.edit_note_rounded,
                        label: 'Manual',
                        onTap: () =>
                            context.go('${RoutePaths.add}?mode=manual'),
                      ),
                      CaptureMode(
                        icon: Icons.photo_camera_outlined,
                        label: 'Scan',
                        onTap: () =>
                            context.go('${RoutePaths.add}?mode=receipt'),
                      ),
                      CaptureMode(
                        icon: Icons.content_paste_rounded,
                        label: 'SMS',
                        onTap: () => context.go('${RoutePaths.add}?mode=sms'),
                      ),
                      CaptureMode(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Type',
                        onTap: () => context.go('${RoutePaths.add}?mode=text'),
                      ),
                    ],
                  ),
                  ),
                  if (empty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Start with your first expense',
                      message:
                          'Scan a receipt, paste a bank SMS, type “Coffee 450”, or enter an amount and category.',
                      actionLabel: 'Add manually',
                      onAction: () =>
                          context.go('${RoutePaths.add}?mode=manual'),
                      secondaryLabel: 'Log income',
                      onSecondary: () =>
                          context.go('${RoutePaths.add}?type=income'),
                    ),
                  ],
                  if (missingFx) ...[
                    const SizedBox(height: AppSpacing.md),
                    StatusBanner(
                      message:
                          'Some wallets use another currency. Add an exchange rate so totals stay accurate.',
                      icon: Icons.currency_exchange_rounded,
                      tone: StatusTone.warn,
                      onTap: () => context.push(RoutePaths.settings),
                    ),
                  ],
                  if (alerts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _BudgetAlerts(alerts: alerts),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  StatCard(
                    label: 'Net worth',
                    value: formatMoney(data.netWorth, data.baseCurrency),
                    hint: 'In ${data.baseCurrency}',
                    featured: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Income this month',
                          value: formatMoney(data.income, data.baseCurrency),
                          tone: StatTone.positive,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: StatCard(
                          label: 'Spent this month',
                          value: formatMoney(data.expense, data.baseCurrency),
                          tone: StatTone.negative,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _AccountsCard(data: data),
                  const SizedBox(height: AppSpacing.md),
                  _BudgetsCard(data: data),
                  if (!empty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _RecentCard(data: data),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BudgetAlerts extends StatelessWidget {
  const _BudgetAlerts({required this.alerts});

  final List<BudgetProgress> alerts;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: AppColors.warn),
              const SizedBox(width: 8),
              Text(
                'Budget alerts',
                style: context.texts.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.warn,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final b in alerts)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${b.category.name}: ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: b.status == 'over'
                          ? 'over budget (${(b.ratio * 100).round()}%)'
                          : 'at 80%+ of limit (${(b.ratio * 100).round()}%)',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountsCard extends StatelessWidget {
  const _AccountsCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
            child: SectionHeader(
              title: 'Accounts',
              actionLabel: 'Manage',
              onAction: () => context.push(RoutePaths.accounts),
            ),
          ),
          if (data.accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No accounts yet.',
                style: context.texts.bodySmall?.copyWith(color: context.muted),
              ),
            )
          else
            for (final account in data.accounts.take(4))
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(labelForAccountType(account.type)),
                trailing: MoneyText(
                  account.balance,
                  currency: account.currency,
                  style: context.texts.bodyMedium,
                ),
                onTap: () => context.push(RoutePaths.accounts),
              ),
        ],
      ),
    );
  }
}

class _BudgetsCard extends StatelessWidget {
  const _BudgetsCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          SectionHeader(
            title: 'Budgets',
            actionLabel: 'View all',
            onAction: () => context.push(RoutePaths.budgets),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (data.budgets.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Set monthly budgets on expense categories to track progress.',
                style: context.texts.bodySmall?.copyWith(color: context.muted),
              ),
            )
          else
            for (final budget in data.budgets.take(3)) ...[
              BudgetBar(
                progress: budget,
                currency: data.baseCurrency,
                compact: true,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
            child: SectionHeader(
              title: 'Recent activity',
              actionLabel: 'See all',
              onAction: () => context.go(RoutePaths.activity),
            ),
          ),
          for (final t in data.recent.take(6))
            TxTile(
              transaction: t,
              currency: t.account?.currency ?? data.baseCurrency,
              onTap: () => context.go(RoutePaths.activity),
            ),
        ],
      ),
    );
  }
}
