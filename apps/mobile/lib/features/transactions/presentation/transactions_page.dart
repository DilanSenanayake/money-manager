import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
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

  Future<void> _openEditor({Transaction? tx}) async {
    if (tx != null && tx.isTransfer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Edit transfers by deleting and recreating them'),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransactionEditorSheet(existing: tx),
    );
    ref.invalidate(transactionsProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(analyticsProvider);
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
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: AppTextField(
              controller: _search,
              label: 'Search merchant or notes',
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                ...['expense', 'income', 'transfer'].map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(t),
                      selected: filter.type == t,
                      onSelected: (_) {
                        ref.read(_txFilterProvider.notifier).state =
                            filter.copyWith(type: t);
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
                message: e is Failure ? e.message : e.toString(),
                onRetry: () => ref.invalidate(transactionsProvider),
              ),
              data: (txs) {
                if (txs.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No activity',
                    message: 'Try a different filter or add a transaction.',
                    actionLabel: 'Add',
                    onAction: () => context.go(RoutePaths.add),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(transactionsProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: txs.length +
                        (txs.length >= AppConstants.transactionLimit ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, i) {
                      if (i == txs.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Showing the latest 200 transactions. Narrow with search or filters.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      final t = txs[i];
                      return AppCard(
                        padding: EdgeInsets.zero,
                        child: TxTile(
                          transaction: t,
                          currency: t.account?.currency ?? profileCurrency,
                          onTap: () => _openEditor(tx: t),
                          onDelete: () async {
                            await ref
                                .read(transactionsRepositoryProvider)
                                .deleteTransaction(t);
                            ref.invalidate(transactionsProvider);
                            ref.invalidate(dashboardProvider);
                            ref.invalidate(accountsProvider);
                          },
                        ),
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
            AppTextField(
              controller: _amount,
              label: 'Amount',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
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
              Wrap(
                spacing: 8,
                children: filtered
                    .map(
                      (c) => ChoiceChip(
                        label: Text(c.name),
                        selected: _categoryId == c.id,
                        onSelected: (_) => setState(() => _categoryId = c.id),
                      ),
                    )
                    .toList(),
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
          ],
        ),
      ),
    );
  }
}
