import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/components/components.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../dashboard/data/dashboard_repository.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          TextButton(
            onPressed: () => context.push(RoutePaths.analytics),
            child: const Text('Charts'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 5),
        error: (e, _) => ErrorView(
          message: e is Failure ? e.message : "Couldn't load your reports.",
          onRetry: () => ref.invalidate(analyticsProvider),
        ),
        data: (data) {
          final months = data.months;
          final summary = data.summary;
          if (months.isEmpty || summary == null || summary.monthCount == 0) {
            return EmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'No spending history yet',
              message:
                  'Add income and expenses and each month will show up here. Open a category to see every expense.',
              actionLabel: 'Add',
              onAction: () => context.go(RoutePaths.add),
            );
          }

          final selected = months.firstWhere(
            (month) => month.key == _selectedKey,
            orElse: () => months.first,
          );
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(analyticsProvider),
            child: ListView(
              padding: AppSpacing.page,
              children: [
                _SummaryGrid(summary: summary, currency: data.baseCurrency),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Every month',
                  style: context.texts.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final month in months)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _MonthRow(
                      month: month,
                      currency: data.baseCurrency,
                      selected: month.key == selected.key,
                      onTap: () => setState(() => _selectedKey = month.key),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                _CategoryCard(month: selected, currency: data.baseCurrency),
                const SizedBox(height: AppSpacing.md),
                _MerchantCard(month: selected, currency: data.baseCurrency),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.currency});

  final SpendingReportSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final months = summary.monthCount == 1 ? 'month' : 'months';
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                label: 'Average monthly spend',
                value: formatMoney(summary.averageExpense, currency),
                hint: 'Across ${summary.monthCount} $months',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatCard(
                label: 'Total spent',
                value: formatMoney(summary.totalExpense, currency),
                tone: StatTone.negative,
                hint: 'Income and transfers are kept separate',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                label: 'Total income',
                value: formatMoney(summary.totalIncome, currency),
                tone: StatTone.positive,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatCard(
                label: 'Savings rate',
                value: _formatPercent(summary.savingsRate),
                hint: summary.highestSpendMonth == null
                    ? null
                    : 'Highest spend: ${summary.highestSpendMonth} (${formatMoney(summary.highestSpend, currency)})',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.month,
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  final MonthlyReport month;
  final String currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final change = month.expenseChange;
    return Material(
      color: selected
          ? scheme.primaryContainer
          : Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      month.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${month.transactionCount} txn'
                    '${change == null ? '' : ' · ${_formatPercent(change, signed: true)}'}',
                    style: context.texts.labelSmall?.copyWith(
                      color: context.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _AmountLabel(
                    label: 'Spent',
                    value: formatMoney(month.expense, currency),
                    color: AppColors.danger,
                  ),
                  _AmountLabel(
                    label: 'Income',
                    value: formatMoney(month.income, currency),
                    color: AppColors.success,
                  ),
                  _AmountLabel(
                    label: 'Left',
                    value: formatMoney(month.net, currency),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountLabel extends StatelessWidget {
  const _AmountLabel({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: context.texts.labelSmall?.copyWith(color: context.muted),
          ),
          TextSpan(
            text: value,
            style: context.texts.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.month, required this.currency});

  final MonthlyReport month;
  final String currency;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  String? _expandedKey;

  @override
  void didUpdateWidget(covariant _CategoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month.key != widget.month.key) {
      _expandedKey = null;
    }
  }

  String _categoryKey(CategorySpendPoint category) =>
      category.categoryId ?? category.name;

  String _expenseLabel(String? merchant) {
    final trimmed = merchant?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'Expense';
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    final currency = widget.currency;
    final maxCategory = month.categories.isEmpty
        ? 0.0
        : month.categories.first.value;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${month.label} by category',
            style: context.texts.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_changeHint(month.expenseChange)}. Tap a category to see every expense.',
            style: context.texts.labelSmall?.copyWith(color: context.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          if (month.categories.isEmpty)
            Text(
              'No expenses recorded this month.',
              style: context.texts.bodySmall?.copyWith(color: context.muted),
            )
          else
            for (final category in month.categories) ...[
              _CategoryExpenseTile(
                category: category,
                currency: currency,
                fraction:
                    maxCategory <= 0 ? 0 : category.value / maxCategory,
                expanded: _expandedKey == _categoryKey(category),
                expenseLabel: _expenseLabel,
                onToggle: () {
                  final key = _categoryKey(category);
                  setState(() {
                    _expandedKey = _expandedKey == key ? null : key;
                  });
                },
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _CategoryExpenseTile extends StatelessWidget {
  const _CategoryExpenseTile({
    required this.category,
    required this.currency,
    required this.fraction,
    required this.expanded,
    required this.onToggle,
    required this.expenseLabel,
  });

  final CategorySpendPoint category;
  final String currency;
  final double fraction;
  final bool expanded;
  final VoidCallback onToggle;
  final String Function(String?) expenseLabel;

  @override
  Widget build(BuildContext context) {
    final count = category.count > 0
        ? category.count
        : category.expenses.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        expanded
                            ? Icons.expand_more_rounded
                            : Icons.chevron_right_rounded,
                        size: 20,
                        color: context.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          category.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (count > 0) ...[
                        Text(
                          '$count ${count == 1 ? 'expense' : 'expenses'}',
                          style: context.texts.labelSmall?.copyWith(
                            color: context.muted,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        formatMoney(category.value, currency),
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ShareBar(fraction: fraction),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (category.expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No individual expenses listed.',
                    style: context.texts.bodySmall?.copyWith(
                      color: context.muted,
                    ),
                  ),
                ),
              )
            else
              for (final expense in category.expenses)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expenseLabel(expense.merchant),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              expense.date,
                              style: context.texts.labelSmall?.copyWith(
                                color: context.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatMoney(expense.amount, currency),
                        style: TextStyle(
                          color: context.colors.error,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _MerchantCard extends StatelessWidget {
  const _MerchantCard({required this.month, required this.currency});

  final MonthlyReport month;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final rate = month.savingsRate;
    final hint = rate == null
        ? 'No income recorded this month'
        : rate < 0
            ? 'Overspent by ${_formatPercent(rate.abs())} of income'
            : 'Kept ${_formatPercent(rate)} of income';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where it went',
            style: context.texts.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: context.texts.labelSmall?.copyWith(color: context.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (month.merchants.isEmpty)
            Text(
              'Expenses this month have no payee names yet.',
              style: context.texts.bodySmall?.copyWith(color: context.muted),
            )
          else
            for (final merchant in month.merchants)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: merchant.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text:
                                  '  ${merchant.count} ${merchant.count == 1 ? 'time' : 'times'}',
                              style: context.texts.labelSmall?.copyWith(
                                color: context.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(merchant.value, currency),
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = fraction <= 0
            ? 0.0
            : (fraction * constraints.maxWidth).clamp(4.0, constraints.maxWidth);
        return Container(
          height: 8,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: context.colors.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      },
    );
  }
}

String _formatPercent(double? value, {bool signed = false}) {
  if (value == null) return '—';
  final text = '${value.abs().toStringAsFixed(1)}%';
  if (value < 0) return '-$text';
  if (signed && value > 0) return '+$text';
  if (value == 0) return '0%';
  return text;
}

String _changeHint(double? value) {
  if (value == null) return 'No earlier month to compare';
  if (value > 0) {
    return '${_formatPercent(value, signed: true)} more than the month before';
  }
  if (value < 0) {
    return '${_formatPercent(value, signed: true)} less than the month before';
  }
  return 'Same spend as the month before';
}
