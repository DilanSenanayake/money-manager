import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/category_visuals.dart';
import '../../../core/utils/dates.dart';
import '../../../shared/components/components.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../budgets/data/categories_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/transactions_repository.dart';

final _txFilterProvider = StateProvider.autoDispose<TransactionFilter>((ref) {
  return const TransactionFilter();
});

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilters(TransactionFilter filter) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ActivityFilterSheet(initial: filter),
    );
  }

  Future<void> _openEditor({Transaction? tx}) async {
    if (tx != null && tx.isTransfer) {
      await _confirmDelete(tx);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TransactionEditorSheet(existing: tx),
    );
    ref.invalidate(transactionsProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(analyticsProvider);
  }

  Future<void> _deleteTransaction(Transaction tx) async {
    try {
      await ref.read(transactionsRepositoryProvider).deleteTransaction(tx);
      ref.invalidate(transactionsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(analyticsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is Failure ? e.message : e.toString())),
      );
      // List may be out of sync if swipe already removed the row.
      ref.invalidate(transactionsProvider);
    }
  }

  Future<void> _confirmDelete(Transaction tx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tx.isTransfer ? 'Delete this transfer?' : 'Delete this?'),
        content: Text(
          tx.isTransfer
              ? 'Both sides of the transfer will be removed. You can’t undo this.'
              : 'This activity will be removed. You can’t undo this.',
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
    if (ok != true || !mounted) return;
    await _deleteTransaction(tx);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(_txFilterProvider);
    final async = ref.watch(transactionsProvider(filter));
    final profileCurrency =
        ref.watch(dashboardProvider).valueOrNull?.baseCurrency ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () => _openFilters(filter),
            icon: Badge(
              isLabelVisible: filter.hasExtraFilters,
              smallSize: 8,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: AppTextField(
              controller: _search,
              hint: 'Search merchant or notes',
              prefixIcon: Icons.search_rounded,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () {
                  ref.read(_txFilterProvider.notifier).state =
                      filter.copyWith(q: v, clearQ: v.trim().isEmpty);
                });
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: filter.type == null,
                  onSelected: (_) {
                    ref.read(_txFilterProvider.notifier).state =
                        filter.copyWith(clearType: true);
                  },
                ),
                const SizedBox(width: 8),
                ...[
                  ('expense', 'Expense'),
                  ('income', 'Income'),
                  ('transfer', 'Transfer'),
                ].map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(t.$2),
                      selected: filter.type == t.$1,
                      onSelected: (_) {
                        ref.read(_txFilterProvider.notifier).state =
                            filter.copyWith(type: t.$1);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (e, _) => ErrorView(
                message: e is Failure
                    ? e.message
                    : "Couldn't load your transactions.",
                onRetry: () => ref.invalidate(transactionsProvider),
              ),
              data: (txs) {
                if (txs.isEmpty) {
                  final narrowed = filter.isNarrowed;
                  return Center(
                    child: Padding(
                      padding: AppSpacing.page,
                      child: EmptyState(
                        icon: narrowed
                            ? Icons.filter_alt_off_outlined
                            : Icons.receipt_long_outlined,
                        title: narrowed
                            ? 'No matching activity'
                            : 'No activity yet',
                        message: narrowed
                            ? 'Try a different search or clear filters to see more.'
                            : 'Add a purchase in seconds. Use AI or enter it yourself.',
                        actionLabel: narrowed ? 'Clear filters' : 'Add',
                        onAction: narrowed
                            ? () {
                                _search.clear();
                                ref.read(_txFilterProvider.notifier).state =
                                    const TransactionFilter();
                              }
                            : () => context.go(RoutePaths.add),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(transactionsProvider);
                  },
                  child: ListView.builder(
                    padding: AppSpacing.page,
                    itemCount: txs.length +
                        (txs.length >= AppConstants.transactionLimit ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == txs.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Showing the latest 200. Narrow with search or filters.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        );
                      }
                      final t = txs[i];
                      final showHeader =
                          i == 0 || txs[i - 1].date != t.date;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeader)
                            Padding(
                              padding: EdgeInsets.only(
                                top: i == 0 ? 4 : 20,
                                bottom: 8,
                              ),
                              child: Text(
                                formatFriendlyDate(t.date).toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          TxTile(
                            transaction: t,
                            currency:
                                t.account?.currency ?? profileCurrency,
                            showDate: false,
                            showTypeBadge: false,
                            onTap: () => _openEditor(tx: t),
                            onDelete: () => _deleteTransaction(t),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityFilterSheet extends ConsumerStatefulWidget {
  const _ActivityFilterSheet({required this.initial});

  final TransactionFilter initial;

  @override
  ConsumerState<_ActivityFilterSheet> createState() =>
      _ActivityFilterSheetState();
}

class _ActivityFilterSheetState extends ConsumerState<_ActivityFilterSheet> {
  late String? _accountId = widget.initial.accountId;
  late String? _categoryId = widget.initial.categoryId;
  late String? _from = widget.initial.from;
  late String? _to = widget.initial.to;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filters',
              style: context.texts.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Account'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All accounts'),
                ),
                ...accounts.map(
                  (a) => DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text(a.name),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All categories'),
                ),
                ...categories.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Row(
                      children: [
                        CategoryMark(
                          icon: c.icon,
                          name: c.name,
                          framed: true,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            c.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            DateField(
              label: 'From',
              value: _from ?? '',
              onChanged: (v) => setState(() => _from = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            DateField(
              label: 'To',
              value: _to ?? '',
              onChanged: (v) => setState(() => _to = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Apply filters',
              onPressed: () {
                final current = ref.read(_txFilterProvider);
                ref.read(_txFilterProvider.notifier).state = current.copyWith(
                  accountId: _accountId,
                  categoryId: _categoryId,
                  from: _from,
                  to: _to,
                  clearAccount: _accountId == null,
                  clearCategory: _categoryId == null,
                  clearFrom: _from == null || _from!.isEmpty,
                  clearTo: _to == null || _to!.isEmpty,
                );
                Navigator.pop(context);
              },
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _accountId = null;
                  _categoryId = null;
                  _from = null;
                  _to = null;
                });
              },
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionEditorSheet extends ConsumerStatefulWidget {
  const _TransactionEditorSheet({this.existing});

  final Transaction? existing;

  @override
  ConsumerState<_TransactionEditorSheet> createState() =>
      _TransactionEditorSheetState();
}

class _TransactionEditorSheetState
    extends ConsumerState<_TransactionEditorSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _merchant;
  late final TextEditingController _notes;
  late String _type;
  late String _date;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  bool _recurring = false;
  String _frequency = 'monthly';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.existing;
    _amount = TextEditingController(
      text: tx == null ? '' : tx.amount.toString(),
    );
    _merchant = TextEditingController(text: tx?.merchant ?? '');
    _notes = TextEditingController(text: tx?.notes ?? '');
    _type = tx?.type ?? 'expense';
    _date = tx?.date ?? localDateYYYYMMDD();
    _accountId = tx?.accountId;
    _categoryId = tx?.categoryId;
    _recurring = tx?.isRecurring ?? false;
    _frequency = tx?.recurringFrequency ?? 'monthly';
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0 || _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount and account')),
      );
      return;
    }
    if (_type == 'transfer') {
      if (_toAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose where the money should go')),
        );
        return;
      }
      final accounts = ref.read(accountsProvider).valueOrNull ?? [];
      final from = accounts.where((a) => a.id == _accountId).firstOrNull;
      final to = accounts.where((a) => a.id == _toAccountId).firstOrNull;
      if (from != null && to != null && from.currency != to.currency) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Transfers must be between accounts that share the same currency',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final input = TransactionInput(
        accountId: _accountId!,
        categoryId: _type == 'transfer' ? null : _categoryId,
        amount: amount,
        type: _type,
        date: _date,
        merchant: _merchant.text.trim().isEmpty ? null : _merchant.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        isRecurring: _type == 'transfer' ? false : _recurring,
        recurringFrequency: _frequency,
        transferToAccountId: _toAccountId,
      );
      final repo = ref.read(transactionsRepositoryProvider);
      if (widget.existing == null) {
        await repo.createTransaction(input);
      } else {
        await repo.updateTransaction(widget.existing!.id, input);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is Failure ? e.message : e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final tx = widget.existing;
    if (tx == null) return;
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
    if (ok != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await ref.read(transactionsRepositoryProvider).deleteTransaction(tx);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is Failure ? e.message : e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;
    final filtered = categories.where((c) => c.type == _type).toList();
    final fromCurrency =
        accounts.where((a) => a.id == _accountId).firstOrNull?.currency;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? 'New transaction' : 'Edit transaction',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            if (widget.existing == null)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                  ButtonSegment(value: 'transfer', label: Text('Transfer')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _categoryId = null;
                }),
              ),
            const SizedBox(height: 12),
            AmountField(controller: _amount),
            const SizedBox(height: 12),
            DateField(
              value: _date,
              onChanged: (v) => setState(() => _date = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: InputDecoration(
                labelText: _type == 'transfer' ? 'From account' : 'Account',
              ),
              items: accounts
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name} (${a.currency})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _accountId = v),
            ),
            if (_type == 'transfer') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _toAccountId,
                decoration: const InputDecoration(labelText: 'To account'),
                items: accounts
                    .where(
                      (a) =>
                          a.id != _accountId &&
                          (fromCurrency == null || a.currency == fromCurrency),
                    )
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.name} (${a.currency})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _toAccountId = v),
              ),
            ] else ...[
              const SizedBox(height: 12),
              CategoryChipRow(
                categories: filtered,
                selectedId: _categoryId,
                onSelected: (id) => setState(() => _categoryId = id),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _merchant,
                label: 'Merchant',
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _notes,
                label: 'Notes (optional)',
                maxLines: 2,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recurring'),
                value: _recurring,
                onChanged: (v) => setState(() => _recurring = v),
              ),
              if (_recurring)
                DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (v) =>
                      setState(() => _frequency = v ?? 'monthly'),
                ),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: widget.existing == null ? 'Save' : 'Update',
              loading: _loading,
              onPressed: _save,
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _delete,
                child: Text(
                  'Delete',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
