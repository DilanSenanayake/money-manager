import '../../shared/models/models.dart';

enum InsightTone { neutral, positive, warn, danger }

enum InsightKind { budget, spend }

class MoneyInsight {
  const MoneyInsight({
    required this.message,
    this.tone = InsightTone.neutral,
    this.kind = InsightKind.spend,
  });

  final String message;
  final InsightTone tone;
  final InsightKind kind;
}

/// Builds at most two insights from data the app already has. Never invents.
List<MoneyInsight> buildMoneyInsights({
  DashboardData? dashboard,
  AnalyticsData? analytics,
}) {
  final items = <MoneyInsight>[];

  final budgets = dashboard?.budgets ?? const [];
  final over = budgets.where((b) => b.status == 'over').toList();
  if (over.isNotEmpty) {
    items.add(
      MoneyInsight(
        message: over.length == 1
            ? '${over.first.category.name} is over budget.'
            : '${over.length} budgets are over their limit.',
        tone: InsightTone.danger,
        kind: InsightKind.budget,
      ),
    );
  } else {
    final warn = budgets.where((b) => b.status == 'warn').toList();
    if (warn.isNotEmpty) {
      items.add(
        MoneyInsight(
          message: warn.length == 1
              ? '${warn.first.category.name} is at 80%+ of its limit.'
              : '${warn.length} budgets are nearing their limit.',
          tone: InsightTone.warn,
          kind: InsightKind.budget,
        ),
      );
    }
  }

  final trend = analytics?.trend ?? const [];
  if (trend.length >= 2) {
    final current = trend.last.expense;
    final previous = trend[trend.length - 2].expense;
    if (current > previous && previous > 0) {
      items.add(
        const MoneyInsight(
          message: 'Spending is up from last month.',
          tone: InsightTone.warn,
        ),
      );
    } else if (current < previous && current >= 0) {
      items.add(
        const MoneyInsight(
          message: 'Spending is down from last month.',
          tone: InsightTone.positive,
        ),
      );
    }
  }

  final spend = [...?analytics?.categorySpend]
    ..sort((a, b) => b.value.compareTo(a.value));
  if (spend.isNotEmpty && spend.first.value > 0) {
    items.add(
      MoneyInsight(
        message: '${spend.first.name} is your largest spend this month.',
      ),
    );
  }

  return items.take(2).toList();
}
