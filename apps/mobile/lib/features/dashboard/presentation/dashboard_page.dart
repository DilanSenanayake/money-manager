import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/insights.dart';
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
    final analytics = ref.watch(analyticsProvider).valueOrNull;

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
            final empty = data.recent.isEmpty &&
                data.income == 0 &&
                data.expense == 0;
            final leftover = data.income - data.expense;
            final insights = empty
                ? const <MoneyInsight>[]
                : buildMoneyInsights(dashboard: data, analytics: analytics);
            final missingFx = hasMissingExchangeRate(
              data.accounts,
              data.baseCurrency,
              data.rates,
            );

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardProvider);
                ref.invalidate(analyticsProvider);
              },
              child: ListView(
                padding: AppSpacing.page,
                children: [
                  FadeUp(
                    child: Text(
                      firstName == null ? 'Home' : 'Hi, $firstName',
                      style: context.texts.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  if (empty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Start with your first expense',
                      message:
                          'Use Smart AI to type, paste, speak, or scan — or enter details manually.',
                      actionLabel: 'Smart AI',
                      onAction: () =>
                          context.go('${RoutePaths.add}?mode=smart'),
                      secondaryLabel: 'Add manually',
                      onSecondary: () =>
                          context.go('${RoutePaths.add}?mode=manual'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _CaptureRow(),
                  ] else ...[
                    const SizedBox(height: AppSpacing.lg),
                    FadeUp(
                      delay: const Duration(milliseconds: 40),
                      child: Semantics(
                        label:
                            'Net worth ${formatMoney(data.netWorth, data.baseCurrency)}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NET WORTH',
                              style: context.texts.labelSmall?.copyWith(
                                color: context.muted,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            MoneyDisplay(
                              data.netWorth,
                              currency: data.baseCurrency,
                              hero: true,
                              animate: true,
                            ),
                            if (data.income != 0 || data.expense != 0) ...[
                              const SizedBox(height: AppSpacing.xs),
                              AnimatedAmount(
                                amount: leftover.abs(),
                                builder: (context, value) {
                                  final positive = leftover >= 0;
                                  return Text(
                                    positive
                                        ? '${formatMoney(value, data.baseCurrency)} left this month'
                                        : '${formatMoney(value, data.baseCurrency)} more spent than earned this month',
                                    style: context.texts.bodyMedium?.copyWith(
                                      color: positive
                                          ? AppColors.success
                                          : AppColors.danger,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FadeUp(
                      delay: const Duration(milliseconds: 80),
                      child: CashflowPair(
                        income: data.income,
                        expense: data.expense,
                        currency: data.baseCurrency,
                        animate: true,
                      ),
                    ),
                    if (insights.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      for (var i = 0; i < insights.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.xs),
                        FadeUp(
                          delay: Duration(milliseconds: 120 + (i * 70)),
                          child: InsightChip(
                            insight: insights[i],
                            onTap: insights[i].kind == InsightKind.budget
                                ? () => context.push(RoutePaths.budgets)
                                : () => context.push(RoutePaths.analytics),
                          ),
                        ),
                      ],
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
                    const SizedBox(height: AppSpacing.xl),
                    _BudgetsCard(data: data),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Add',
                      style: context.texts.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const _CaptureRow(),
                    const SizedBox(height: AppSpacing.lg),
                    _RecentCard(data: data),
                    const SizedBox(height: AppSpacing.md),
                    _AccountsCard(data: data),
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

class _CaptureRow extends StatelessWidget {
  const _CaptureRow();

  @override
  Widget build(BuildContext context) {
    return CaptureModeGrid(
      compact: true,
      modes: [
        CaptureMode(
          icon: Icons.auto_awesome_rounded,
          label: 'Smart AI',
          subtitle: 'Type, paste, speak, scan',
          onTap: () => context.go('${RoutePaths.add}?mode=smart'),
        ),
        CaptureMode(
          icon: Icons.edit_note_rounded,
          label: 'Manual',
          subtitle: 'Enter details yourself',
          onTap: () => context.go('${RoutePaths.add}?mode=manual'),
        ),
      ],
    );
  }
}

class _AccountsCard extends StatelessWidget {
  const _AccountsCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Accounts',
          actionLabel: 'Manage',
          onAction: () => context.push(RoutePaths.accounts),
        ),
        if (data.accounts.isEmpty)
          Text(
            'Add a wallet to track balances.',
            style: context.texts.bodySmall?.copyWith(color: context.muted),
          )
        else
          for (final account in data.accounts.take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              minVerticalPadding: 8,
              leading: Icon(
                iconForAccountType(account.type),
                color: context.colors.primary,
              ),
              title: Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
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
    );
  }
}

class _BudgetsCard extends StatelessWidget {
  const _BudgetsCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Budgets',
          actionLabel: 'View all',
          onAction: () => context.push(RoutePaths.budgets),
        ),
        if (data.budgets.isEmpty)
          Text(
            'Set a monthly limit to see if spending stays on track.',
            style: context.texts.bodySmall?.copyWith(color: context.muted),
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
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: 'Recent',
          actionLabel: 'See all',
          onAction: () => context.go(RoutePaths.activity),
        ),
        for (final t in data.recent.take(6))
          TxTile(
            transaction: t,
            currency: t.account?.currency ?? data.baseCurrency,
            showTypeBadge: false,
            onTap: () => context.go(RoutePaths.activity),
          ),
      ],
    );
  }
}
