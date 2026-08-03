import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
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
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        fontWeight: FontWeight.w700,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
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
      avatar: Icon(_iconFor(account.type), size: 16),
      label: Text(account.name),
      visualDensity: VisualDensity.compact,
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'credit':
        return Icons.credit_card_rounded;
      case 'savings':
        return Icons.savings_outlined;
      case 'checking':
        return Icons.account_balance_outlined;
      default:
        return Icons.payments_outlined;
    }
  }
}

class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.progress});

  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final color = switch (progress.status) {
      'over' => AppColors.danger,
      'warn' => AppColors.warn,
      _ => AppColors.teal500,
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  progress.category.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${formatMoney(progress.spent)} / ${formatMoney(progress.limit)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.ratio.clamp(0, 1).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ],
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
  });

  final Transaction transaction;
  final String currency;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income' ||
        (transaction.type == 'transfer' &&
            transaction.transferDirection == 'in');
    final isTransfer = transaction.type == 'transfer';
    final amountColor = isTransfer
        ? AppColors.slate
        : isIncome
            ? AppColors.success
            : AppColors.danger;
    final title = transaction.merchant?.isNotEmpty == true
        ? transaction.merchant!
        : (transaction.category?.name ?? transaction.type);
    final subtitle = [
      transaction.account?.name,
      transaction.date,
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
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete transaction?'),
            content: const Text('This cannot be undone.'),
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
        onTap: onTap,
        onLongPress: () async {
          await HapticFeedback.selectionClick();
          await Share.share(
            '$title · ${formatMoney(transaction.amount, currency)} · ${transaction.date}',
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: amountColor.withValues(alpha: 0.12),
          child: Icon(
            isTransfer
                ? Icons.swap_horiz_rounded
                : isIncome
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
            color: amountColor,
            size: 20,
          ),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: MoneyText(
          isIncome && !isTransfer
              ? transaction.amount
              : isTransfer
                  ? transaction.amount
                  : -transaction.amount,
          currency: currency,
          signed: !isTransfer,
          color: amountColor,
          style: Theme.of(context).textTheme.titleSmall,
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
    this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Icon(icon, color: c, size: 20)
          else
            const SizedBox(height: 20),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.slate,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
