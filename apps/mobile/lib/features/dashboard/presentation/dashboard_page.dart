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
import 'frequent_quick_add.dart';

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
                (data.income ?? 0) == 0 &&
                (data.expense ?? 0) == 0;
            final income = data.income;
            final expense = data.expense;
            final leftover = income == null || expense == null
                ? null
                : income - expense;
            final insights = empty
                ? const <MoneyInsight>[]
                : buildMoneyInsights(dashboard: data, analytics: analytics);
            final missingRates = data.missingRateCurrencies.isNotEmpty
                ? data.missingRateCurrencies
                : (hasMissingExchangeRate(
                    data.accounts,
                    data.baseCurrency,
                    data.rates,
                  )
                    ? data.accounts
                        .map((account) => account.currency)
                        .where((currency) => currency != data.baseCurrency)
                        .toSet()
                        .toList()
                    : const <String>[]);
            final appliedRates = data.netWorth == null
                ? const <ExchangeRate>[]
                : ratesCovering(
                    data.accounts.map((account) => account.currency),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            firstName == null ? 'Home' : 'Hi, $firstName',
                            style: context.texts.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => context.go(RoutePaths.add),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FadeUp(
                    delay: const Duration(milliseconds: 30),
                    child: FrequentQuickAdd(
                      records: data.frequent,
                      shortcuts: data.shortcuts,
                      accounts: data.accounts,
                      baseCurrency: data.baseCurrency,
                    ),
                  ),
                  if (missingRates.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    StatusBanner(
                      message:
                          'Add an exchange rate for ${missingRates.join(', ')}. Combined totals stay hidden until you do.',
                      icon: Icons.currency_exchange_rounded,
                      tone: StatusTone.warn,
                      onTap: () => context.push(RoutePaths.settings),
                    ),
                  ],
                  if (empty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Start with your first expense',
                      message:
                          'Add an expense with AI or enter the details yourself.',
                      actionLabel: 'Add',
                      onAction: () => context.go(RoutePaths.add),
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.lg),
                    FadeUp(
                      delay: const Duration(milliseconds: 40),
                      child: Semantics(
                        label: data.netWorth == null
                            ? 'Net worth hidden until an exchange rate is added'
                            : 'Net worth ${formatMoney(data.netWorth!, data.baseCurrency)}',
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
                            if (data.netWorth == null)
                              Text(
                                'Rate needed',
                                style: context.texts.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            else
                              MoneyDisplay(
                                data.netWorth!,
                                currency: data.baseCurrency,
                                hero: true,
                                animate: true,
                              ),
                            if (leftover != null &&
                                ((income ?? 0) != 0 || (expense ?? 0) != 0)) ...[
                              const SizedBox(height: AppSpacing.xs),
                              _MonthLeftover(
                                leftover: leftover,
                                currency: data.baseCurrency,
                              ),
                            ],
                            for (final rate in appliedRates) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                appliedRateLabel(rate),
                                style: context.texts.bodySmall?.copyWith(
                                  color: context.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (income != null && expense != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      FadeUp(
                        delay: const Duration(milliseconds: 80),
                        child: CashflowPair(
                          income: income,
                          expense: expense,
                          currency: data.baseCurrency,
                          animate: true,
                        ),
                      ),
                    ],
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
                    const SizedBox(height: AppSpacing.xl),
                    _BudgetsCard(data: data),
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

class _MonthLeftover extends StatelessWidget {
  const _MonthLeftover({required this.leftover, required this.currency});

  final double leftover;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final positive = leftover >= 0;
    return AnimatedAmount(
      amount: leftover.abs(),
      builder: (context, value) {
        return Text(
          positive
              ? '${formatMoney(value, currency)} left this month'
              : '${formatMoney(value, currency)} more spent than earned this month',
          style: context.texts.bodyMedium?.copyWith(
            color: positive ? AppColors.success : AppColors.danger,
            fontWeight: FontWeight.w600,
          ),
        );
      },
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
