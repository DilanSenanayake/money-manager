import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
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
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: compact ? 6 : 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.14),
          ),
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
      if (transaction.category != null && transaction.merchant != null)
        transaction.category!.name,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

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
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: amountColor.withValues(alpha: 0.12),
          child: Icon(
            isTransfer
                ? Icons.swap_horiz_rounded
                : isIncome
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
            color: amountColor,
            size: 18,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                subtitle,
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
