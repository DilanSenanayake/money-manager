import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/category_visuals.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/money_input.dart';
import '../../../shared/components/components.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/dashboard_repository.dart';

class FrequentQuickAdd extends ConsumerWidget {
  const FrequentQuickAdd({
    super.key,
    required this.records,
    required this.accounts,
    required this.baseCurrency,
  });

  final List<FrequentRecord> records;
  final List<Account> accounts;
  final String baseCurrency;

  String _currencyOf(FrequentRecord record) {
    for (final account in accounts) {
      if (account.id == record.accountId) return account.currency;
    }
    return baseCurrency;
  }

  Future<void> _open(BuildContext context, FrequentRecord record) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FrequentAddSheet(
        record: record,
        accounts: accounts,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (records.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Add again'),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) {
              final item = records[index];
              final categoryName = item.category?.name;
              return Material(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => _open(context, item),
                  child: Ink(
                    width: 176,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: context.colors.outline.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CategoryMark(
                              icon: item.category?.icon,
                              name: categoryName ?? item.label,
                              framed: true,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                categoryName ??
                                    (item.type == 'income'
                                        ? 'Income'
                                        : 'Expense'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.bodySmall?.copyWith(
                                  color: context.muted,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              formatMoney(item.amount, _currencyOf(item)),
                              style: context.texts.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FrequentAddSheet extends ConsumerStatefulWidget {
  const _FrequentAddSheet({
    required this.record,
    required this.accounts,
  });

  final FrequentRecord record;
  final List<Account> accounts;

  @override
  ConsumerState<_FrequentAddSheet> createState() => _FrequentAddSheetState();
}

class _FrequentAddSheetState extends ConsumerState<_FrequentAddSheet> {
  late final TextEditingController _amount;
  late String? _accountId;
  late String _date;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.record.amount.toStringAsFixed(2),
    );
    _date = localDateYYYYMMDD();
    final known = widget.accounts.any(
      (account) => account.id == widget.record.accountId,
    );
    _accountId = known
        ? widget.record.accountId
        : (widget.accounts.isNotEmpty ? widget.accounts.first.id : null);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String get _currency {
    for (final account in widget.accounts) {
      if (account.id == _accountId) return account.currency;
    }
    return widget.accounts.isNotEmpty ? widget.accounts.first.currency : 'USD';
  }

  Future<void> _save() async {
    final amount = canonicalMoney(_amount.text);
    if (amount == null || _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount and account')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(transactionsRepositoryProvider).createTransaction(
            TransactionInput(
              accountId: _accountId!,
              categoryId: widget.record.categoryId,
              amount: amount,
              type: widget.record.type,
              date: _date,
              merchant: widget.record.label,
            ),
          );
      await HapticFeedback.mediumImpact();
      ref.invalidate(dashboardProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(analyticsProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is Failure ? e.message : e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.record.category;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.record.label,
              style: context.texts.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Today’s date, last amount, and the category saved on this record.',
              style: context.texts.bodySmall?.copyWith(color: context.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Saved category',
              style: context.texts.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (category == null)
              Text(
                'No category on this record',
                style: context.texts.bodyMedium?.copyWith(color: context.muted),
              )
            else
              Row(
                children: [
                  CategoryMark(
                    icon: category.icon,
                    name: category.name,
                    framed: true,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      category.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            AmountField(
              controller: _amount,
              label: 'Amount ($_currency)',
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.accounts.isEmpty)
              Text(
                'Add an account before saving.',
                style: context.texts.bodySmall?.copyWith(
                  color: AppColors.danger,
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: const InputDecoration(labelText: 'Account'),
                items: [
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text('${account.name} (${account.currency})'),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _accountId = value),
              ),
            const SizedBox(height: AppSpacing.md),
            DateField(
              value: _date,
              onChanged: (value) => setState(() => _date = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving || _accountId == null ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
