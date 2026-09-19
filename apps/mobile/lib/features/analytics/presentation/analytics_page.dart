import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/category_visuals.dart';
import '../../../core/utils/insights.dart';
import '../../../core/utils/money.dart';
import '../../../shared/components/components.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../dashboard/data/dashboard_repository.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: async.when(
        loading: () => const SkeletonList(count: 5),
        error: (e, _) => ErrorView(
          message: e is Failure
              ? e.message
              : "Couldn't load your trends.",
          onRetry: () => ref.invalidate(analyticsProvider),
        ),
        data: (data) {
          if (data.trend.isEmpty && data.categorySpend.isEmpty) {
            return EmptyState(
              icon: Icons.insights_outlined,
              title: 'Not enough activity yet',
              message:
                  'Add a few purchases this month to see where money is going.',
              actionLabel: 'Add',
              onAction: () => context.go(RoutePaths.add),
            );
          }

          final insights = buildMoneyInsights(analytics: data);
          final maxY = [
            ...data.trend.map((t) => t.income),
            ...data.trend.map((t) => t.expense),
            1.0,
          ].reduce((a, b) => a > b ? a : b);
          final totalSpend = data.categorySpend.fold<double>(
            0,
            (sum, c) => sum + c.value,
          );

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(analyticsProvider),
            child: ListView(
              padding: AppSpacing.page,
              children: [
                if (insights.isNotEmpty) ...[
                  for (final insight in insights) ...[
                    InsightChip(insight: insight),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  'Where did it go?',
                  style: context.texts.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This month’s spending by category.',
                  style: context.texts.bodySmall?.copyWith(color: context.muted),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (data.categorySpend.isEmpty)
                  const EmptyState(
                    icon: Icons.pie_chart_outline_rounded,
                    title: 'No spending this month',
                    message: 'Expense activity will show up here.',
                  )
                else
                  AppCard(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 180,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 52,
                              sections: [
                                for (final c in data.categorySpend)
                                  PieChartSectionData(
                                    value: c.value,
                                    title: '',
                                    radius: 28,
                                    color: categoryHex(name: c.name),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (final c in data.categorySpend)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                CategoryMark(name: c.name, framed: true),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(c.name),
                                ),
                                Text(
                                  totalSpend <= 0
                                      ? formatMoney(
                                          c.value,
                                          data.baseCurrency,
                                        )
                                      : '${((c.value / totalSpend) * 100).round()}%',
                                  style: context.texts.bodySmall?.copyWith(
                                    color: context.muted,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  formatMoney(
                                    c.value,
                                    data.baseCurrency,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'More or less than before?',
                  style: context.texts.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last six months, in your base currency.',
                  style: context.texts.bodySmall?.copyWith(color: context.muted),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: BarChart(
                          BarChartData(
                            maxY: maxY * 1.2,
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            groupsSpace: 14,
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final i = value.toInt();
                                    if (i < 0 || i >= data.trend.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        data.trend[i].month,
                                        style: context.texts.labelSmall,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups: [
                              for (var i = 0; i < data.trend.length; i++)
                                BarChartGroupData(
                                  x: i,
                                  barsSpace: 4,
                                  barRods: [
                                    BarChartRodData(
                                      toY: data.trend[i].income,
                                      color: AppColors.success,
                                      width: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    BarChartRodData(
                                      toY: data.trend[i].expense,
                                      color: AppColors.danger,
                                      width: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          _LegendDot(color: AppColors.success, label: 'Income'),
                          const SizedBox(width: AppSpacing.md),
                          _LegendDot(color: AppColors.danger, label: 'Spent'),
                        ],
                      ),
                    ],
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: context.texts.labelMedium),
      ],
    );
  }
}

