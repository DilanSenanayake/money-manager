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
import '../../budgets/data/categories_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/dashboard_repository.dart';
import '../data/quick_adds_repository.dart';

class FrequentQuickAdd extends ConsumerWidget {
  const FrequentQuickAdd({
    super.key,
    required this.records,
    required this.shortcuts,
    required this.accounts,
    required this.baseCurrency,
  });

  final List<FrequentRecord> records;
  final List<QuickShortcut> shortcuts;
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

  Future<void> _openShortcut(BuildContext context, QuickShortcut shortcut) {
    final accountId = accounts.isNotEmpty ? accounts.first.id : '';
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FrequentAddSheet(
        record: FrequentRecord(
          label: shortcut.label,
          notes: shortcut.notes,
          type: shortcut.type,
          amount: shortcut.amount,
          accountId: accountId,
          categoryId: shortcut.categoryId,
          category: shortcut.category,
          count: 0,
        ),
        accounts: accounts,
        shortcutId: shortcut.id,
      ),
    );
  }

  Future<void> _compose(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _QuickAddComposer(currency: baseCurrency),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Add again'),
        const SizedBox(height: AppSpacing.xs),
        if (records.isEmpty && shortcuts.isEmpty) ...[
          Text(
            'Save a description, category, and amount, then add it in one tap.',
            style: context.texts.bodySmall?.copyWith(color: context.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: records.length + shortcuts.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) {
              if (index == records.length + shortcuts.length) {
                return _AddQuickChip(onTap: () => _compose(context));
              }
              final frequent = index < records.length;
              final record = frequent ? records[index] : null;
              final shortcut = frequent ? null : shortcuts[index - records.length];
              final label = record?.label ?? shortcut!.label;
              final notes = record?.notes ?? shortcut!.notes;
              final type = record?.type ?? shortcut!.type;
              final amount = record?.amount ?? shortcut!.amount;
              final category = record?.category ?? shortcut!.category;
              final categoryName = category?.name;
              return Material(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => frequent
                      ? _open(context, record!)
                      : _openShortcut(context, shortcut!),
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
                              icon: category?.icon,
                              name: categoryName ?? label,
                              framed: true,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (notes != null && notes.trim().isNotEmpty)
                                    Text(
                                      notes,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.texts.bodySmall?.copyWith(
                                        color: context.muted,
                                      ),
                                    ),
                                ],
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
                                    (type == 'income' ? 'Income' : 'Expense'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.bodySmall?.copyWith(
                                  color: context.muted,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              formatMoney(
                                amount,
                                record == null
                                    ? baseCurrency
                                    : _currencyOf(record),
                              ),
                              style: context.texts.bodySmall?.copyWith(
                                color: context.muted.withValues(alpha: 0.65),
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
    this.shortcutId,
  });

  final FrequentRecord record;
  final List<Account> accounts;
  final String? shortcutId;

  @override
  ConsumerState<_FrequentAddSheet> createState() => _FrequentAddSheetState();
}

class _FrequentAddSheetState extends ConsumerState<_FrequentAddSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _detail;
  late String? _accountId;
  late String? _categoryId;
  late String _date;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.record.amount.toStringAsFixed(2),
    );
    _description = TextEditingController(text: widget.record.label);
    _detail = TextEditingController(text: widget.record.notes ?? '');
    _date = localDateYYYYMMDD();
    final known = widget.accounts.any(
      (account) => account.id == widget.record.accountId,
    );
    _accountId = known
        ? widget.record.accountId
        : (widget.accounts.isNotEmpty ? widget.accounts.first.id : null);
    _categoryId = widget.record.categoryId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _detail.dispose();
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
              categoryId: _categoryId,
              amount: amount,
              type: widget.record.type,
              date: _date,
              merchant: _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
              notes: _detail.text.trim().isEmpty ? null : _detail.text.trim(),
              proposedMerchant: widget.record.label,
              proposedCategoryId: widget.record.categoryId,
              proposedAccountId: widget.record.accountId,
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

  Future<void> _removeShortcut() async {
    final id = widget.shortcutId;
    if (id == null || _saving) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove quick add?'),
        content: const Text(
          'This shortcut will be removed. Entries you already saved stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(quickAddsRepositoryProvider).delete(id);
      ref.invalidate(dashboardProvider);
      if (!mounted) return;
      Navigator.pop(context);
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
    final loaded = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final choices = loaded.where((c) => c.type == widget.record.type).toList();
    final categoryChoices = choices.isNotEmpty
        ? choices
        : [
            if (widget.record.category != null) widget.record.category!,
          ];
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
            AppTextField(
              controller: _description,
              label: 'Description',
              autofocus: true,
              inputFormatters: [
                LengthLimitingTextInputFormatter(200),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _detail,
              label: 'Long description',
              hint: 'Optional details',
              maxLines: 2,
              inputFormatters: [
                LengthLimitingTextInputFormatter(1000),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Category',
              style: context.texts.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            CategoryChipRow(
              categories: categoryChoices,
              selectedId: _categoryId,
              onSelected: (id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: AppSpacing.md),
            AmountField(
              controller: _amount,
              label: 'Amount ($_currency)',
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
            if (widget.shortcutId != null) ...[
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _saving ? null : _removeShortcut,
                  child: const Text('Remove quick add'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddQuickChip extends StatelessWidget {
  const _AddQuickChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Ink(
          width: 148,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: context.colors.outline.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: context.muted),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Add quick add',
                style: context.texts.labelLarge?.copyWith(color: context.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAddComposer extends ConsumerStatefulWidget {
  const _QuickAddComposer({required this.currency});

  final String currency;

  @override
  ConsumerState<_QuickAddComposer> createState() => _QuickAddComposerState();
}

class _QuickAddComposerState extends ConsumerState<_QuickAddComposer> {
  final _description = TextEditingController();
  final _detail = TextEditingController();
  final _amount = TextEditingController();
  var _type = 'expense';
  String? _categoryId;
  var _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _detail.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(List<Category> categories) async {
    final name = _description.text.trim();
    final amount = canonicalMoney(_amount.text);
    if (name.isEmpty) {
      _toast('Enter a description');
      return;
    }
    if (_categoryId == null ||
        !categories.any((category) => category.id == _categoryId)) {
      _toast('Choose a category');
      return;
    }
    if (amount == null) {
      _toast('Enter an amount');
      return;
    }

    setState(() => _saving = true);
    try {
      final detail = _detail.text.trim();
      await ref.read(quickAddsRepositoryProvider).create(
            merchant: name.length <= 200 ? name : name.substring(0, 200),
            notes: detail.isEmpty
                ? null
                : (detail.length <= 1000 ? detail : detail.substring(0, 1000)),
            categoryId: _categoryId!,
            amount: amount,
          );
      ref.invalidate(dashboardProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quick add saved')),
      );
    } catch (e) {
      if (!mounted) return;
      _toast(e is Failure ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loaded =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final choices = loaded.where((category) => category.type == _type).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
              'New quick add',
              style: context.texts.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Choose the description, category, and amount. It stays on home so you can add it again.',
              style: context.texts.bodySmall?.copyWith(color: context.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _description,
              label: 'Description',
              autofocus: true,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _detail,
              label: 'Long description',
              hint: 'Optional details',
              maxLines: 2,
              inputFormatters: [LengthLimitingTextInputFormatter(1000)],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Category', style: context.texts.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              children: [
                for (final type in const ['expense', 'income'])
                  ChoiceChip(
                    label: Text(type == 'expense' ? 'Expense' : 'Income'),
                    selected: _type == type,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() {
                              _type = type;
                              final matches = loaded.where(
                                (category) => category.id == _categoryId,
                              );
                              if (matches.isEmpty || matches.first.type != type) {
                                _categoryId = null;
                              }
                            }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            CategoryChipRow(
              categories: choices,
              selectedId: _categoryId,
              onSelected: (id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: AppSpacing.md),
            AmountField(
              controller: _amount,
              label: 'Amount (${widget.currency})',
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : () => _save(choices),
                child: Text(_saving ? 'Saving…' : 'Save quick add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
