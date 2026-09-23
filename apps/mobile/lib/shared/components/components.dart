import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/insights.dart';
import '../../core/utils/labels.dart';
import '../../core/utils/money.dart';
import '../models/models.dart';
import '../widgets/app_widgets.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.currency = 'USD',
    this.style,
    this.signed = false,
    this.color,
  });

  final num amount;
  final String currency;
  final TextStyle? style;
  final bool signed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final prefix = signed
        ? (amount > 0
            ? '+'
            : amount < 0
                ? ''
                : '')
        : '';
    return Text(
      '$prefix${formatMoney(amount, currency)}',
      style: (style ?? context.texts.titleMedium)?.copyWith(
        fontWeight: FontWeight.w700,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: -0.4,
      ),
    );
  }
}

class AccountChip extends StatelessWidget {
  const AccountChip({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(iconForAccountType(account.type), size: 16),
      label: Text(account.name),
      visualDensity: VisualDensity.compact,
    );
  }
}

class BudgetBar extends StatelessWidget {
  const BudgetBar({
    super.key,
    required this.progress,
    this.currency = 'USD',
    this.compact = false,
  });

  final BudgetProgress progress;
  final String currency;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (progress.status) {
      'over' => AppColors.danger,
      'warn' => AppColors.warn,
      _ => context.colors.primary,
    };
    final ratio = progress.ratio.clamp(0, 1).toDouble();

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CategoryMark(
              icon: progress.category.icon,
              name: progress.category.name,
              framed: true,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                progress.category.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${formatMoney(progress.spent, currency)} / ${formatMoney(progress.limit, currency)}',
              style: context.texts.bodySmall?.copyWith(color: context.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _FillBar(
          ratio: ratio,
          color: color,
          height: compact ? 6 : 8,
        ),
        if (progress.status == 'over' || progress.status == 'warn') ...[
          const SizedBox(height: 6),
          Text(
            progress.status == 'over' ? 'Over budget' : 'Nearing limit (80%+)',
            style: context.texts.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    if (compact) return body;
    return AppCard(child: body);
  }
}

class _FillBar extends StatefulWidget {
  const _FillBar({
    required this.ratio,
    required this.color,
    required this.height,
  });

  final double ratio;
  final Color color;
  final double height;

  @override
  State<_FillBar> createState() => _FillBarState();
}

class _FillBarState extends State<_FillBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppDuration.countUp);
    _animation = Tween<double>(begin: 0, end: widget.ratio).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_FillBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ratio == widget.ratio) return;
    _animation = Tween<double>(begin: _animation.value, end: widget.ratio).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = MediaQuery.of(context).disableAnimations
        ? widget.ratio
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: value != null
          ? LinearProgressIndicator(
              value: value,
              minHeight: widget.height,
              color: widget.color,
              backgroundColor: widget.color.withValues(alpha: 0.14),
            )
          : AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                return LinearProgressIndicator(
                  value: _animation.value,
                  minHeight: widget.height,
                  color: widget.color,
                  backgroundColor: widget.color.withValues(alpha: 0.14),
                );
              },
            ),
    );
  }
}

class TxTile extends StatelessWidget {
  const TxTile({
    super.key,
    required this.transaction,
    required this.currency,
    this.onTap,
    this.onDelete,
    this.showDate = true,
    this.showTypeBadge = true,
  });

  final Transaction transaction;
  final String currency;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDate;
  final bool showTypeBadge;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income' ||
        (transaction.type == 'transfer' &&
            transaction.transferDirection == 'in');
    final isTransfer = transaction.type == 'transfer';
    final amountColor = isTransfer
        ? context.muted
        : isIncome
            ? AppColors.success
            : AppColors.danger;
    final title = transaction.merchant?.isNotEmpty == true
        ? transaction.merchant!
        : (transaction.category?.name ?? labelForTxType(transaction.type));
    final subtitle = [
      transaction.account?.name,
      if (showDate) formatFriendlyDate(transaction.date),
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final category = transaction.category;

    return Dismissible(
      key: ValueKey(transaction.id),
      direction:
          onDelete == null ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          useRootNavigator: true,
          builder: (context) => AlertDialog(
            title: const Text('Delete this?'),
            content: const Text(
              'This activity will be removed. You can’t undo this.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return ok ?? false;
      },
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        onLongPress: () async {
          await HapticFeedback.selectionClick();
          await Share.share(
            '$title · ${formatMoney(transaction.amount, currency)} · ${transaction.date}',
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        leading: isTransfer
            ? CircleAvatar(
                radius: 20,
                backgroundColor: amountColor.withValues(alpha: 0.12),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: amountColor,
                  size: 20,
                ),
              )
            : CategoryMark(
                icon: category?.icon,
                name: category?.name,
                framed: true,
                size: 20,
              ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                subtitle.isNotEmpty
                    ? subtitle
                    : labelForTxType(transaction.type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showTypeBadge) ...[
              const SizedBox(width: 8),
              _TypeBadge(type: transaction.type),
            ],
          ],
        ),
        trailing: MoneyText(
          isIncome && !isTransfer
              ? transaction.amount
              : isTransfer
                  ? transaction.amount
                  : -transaction.amount,
          currency: currency,
          signed: !isTransfer,
          color: amountColor,
          style: context.texts.titleSmall,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      'income' => AppColors.success,
      'expense' => AppColors.danger,
      _ => context.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        labelForTxType(type),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.tone = StatTone.neutral,
    this.featured = false,
  });

  final String label;
  final String value;
  final String? hint;
  final StatTone tone;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final valueColor = switch (tone) {
      StatTone.positive => AppColors.success,
      StatTone.negative => AppColors.danger,
      StatTone.neutral => null,
    };
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: context.texts.labelSmall?.copyWith(
              color: context.muted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: (featured
                    ? context.texts.headlineMedium
                    : context.texts.titleLarge)
                ?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.8,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1.1,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              hint!,
              style: context.texts.labelSmall?.copyWith(
                color: context.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum StatTone { neutral, positive, negative }

class MoneyDisplay extends StatelessWidget {
  const MoneyDisplay(
    this.amount, {
    super.key,
    this.currency = 'USD',
    this.hero = false,
    this.color,
    this.signed = false,
    this.animate = false,
  });

  final num amount;
  final String currency;
  final bool hero;
  final Color? color;
  final bool signed;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    Widget text(num value) {
      final prefix = signed
          ? (value > 0
              ? '+'
              : value < 0
                  ? ''
                  : '')
          : '';
      return Text(
        '$prefix${formatMoney(value, currency)}',
        style: (hero ? context.moneyHero : context.moneyTitle).copyWith(
          color: color,
        ),
      );
    }

    if (!animate) return text(amount);
    return Semantics(
      label: formatMoney(amount, currency),
      child: AnimatedAmount(
        amount: amount,
        builder: (context, value) => text(value),
      ),
    );
  }
}

class CashflowPair extends StatelessWidget {
  const CashflowPair({
    super.key,
    required this.income,
    required this.expense,
    required this.currency,
    this.animate = false,
  });

  final num income;
  final num expense;
  final String currency;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: _CashflowColumn(
              label: 'Income',
              amount: income,
              currency: currency,
              color: AppColors.success,
              animate: animate,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: context.colors.outlineVariant,
          ),
          Expanded(
            child: _CashflowColumn(
              label: 'Spent',
              amount: expense,
              currency: currency,
              color: AppColors.danger,
              alignEnd: true,
              animate: animate,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowColumn extends StatelessWidget {
  const _CashflowColumn({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    this.alignEnd = false,
    this.animate = false,
  });

  final String label;
  final num amount;
  final String currency;
  final Color color;
  final bool alignEnd;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            label.toUpperCase(),
            style: context.texts.labelSmall?.copyWith(
              color: context.muted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (animate)
            AnimatedAmount(
              amount: amount,
              duration: AppDuration.slow + const Duration(milliseconds: 200),
              builder: (context, value) => Text(
                formatMoney(value, currency),
                style: context.texts.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -0.4,
                ),
              ),
            )
          else
            Text(
              formatMoney(amount, currency),
              style: context.texts.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: -0.4,
              ),
            ),
        ],
      ),
    );
  }
}

class InsightChip extends StatelessWidget {
  const InsightChip({
    super.key,
    required this.insight,
    this.onTap,
  });

  final MoneyInsight insight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (insight.tone) {
      InsightTone.danger => AppColors.danger,
      InsightTone.warn => AppColors.warn,
      InsightTone.positive => AppColors.success,
      InsightTone.neutral => context.colors.primary,
    };
    final icon = switch (insight.tone) {
      InsightTone.danger => Icons.warning_amber_rounded,
      InsightTone.warn => Icons.trending_up_rounded,
      InsightTone.positive => Icons.trending_down_rounded,
      InsightTone.neutral => Icons.insights_outlined,
    };
    return Material(
      color: color.withValues(alpha: context.isDark ? 0.16 : 0.08),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  insight.message,
                  style: context.texts.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'Amount',
      hint: '0.00',
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      textAlign: TextAlign.start,
      style: context.moneyTitle,
      onChanged: onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
    );
  }
}

class CategoryChipRow extends StatelessWidget {
  const CategoryChipRow({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Text(
        'No categories for this type yet.',
        style: context.texts.bodySmall?.copyWith(color: context.muted),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in categories)
          CategoryChoiceChip(
            name: c.name,
            icon: c.icon,
            selected: selectedId == c.id,
            onSelected: () => onSelected(c.id),
          ),
      ],
    );
  }
}
