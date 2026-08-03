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

final _txFilterProvider =
    StateProvider.autoDispose<TransactionFilter>((ref) {
  return const TransactionFilter();
});

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateTransactionSheet(),
    );
    ref.invalidate(transactionsProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(accountsProvider);
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
            onPressed: _openCreateSheet,
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
                ref.read(_txFilterProvider.notifier).state =
                    filter.copyWith(q: v);
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
              loading: () => const LoadingView(),
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
                    itemCount: txs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, i) {
                      final t = txs[i];
                      return AppCard(
                        padding: EdgeInsets.zero,
                        child: TxTile(
                          transaction: t,
                          currency:
                              t.account?.currency ?? profileCurrency,
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

class _CreateTransactionSheet extends ConsumerStatefulWidget {
  const _CreateTransactionSheet();

  @override
  ConsumerState<_CreateTransactionSheet> createState() =>
      _CreateTransactionSheetState();
}

class _CreateTransactionSheetState
    extends ConsumerState<_CreateTransactionSheet> {
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  String _type = 'expense';
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  bool _recurring = false;
  String _frequency = 'monthly';
  bool _loading = false;

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0 || _accountId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(transactionsRepositoryProvider).createTransaction(
            TransactionInput(
              accountId: _accountId!,
              categoryId: _categoryId,
              amount: amount,
              type: _type,
              date: localDateYYYYMMDD(),
              merchant: _merchant.text.trim().isEmpty
                  ? null
                  : _merchant.text.trim(),
              isRecurring: _recurring,
              recurringFrequency: _frequency,
              transferToAccountId: _toAccountId,
            ),
          );
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
              'New transaction',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
                ButtonSegment(value: 'transfer', label: Text('Transfer')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _amount,
              label: 'Amount',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: InputDecoration(
                labelText: _type == 'transfer' ? 'From account' : 'Account',
              ),
              items: accounts
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
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
                    .where((a) => a.id != _accountId)
                    .map(
                      (a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name)),
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
            AppButton(label: 'Save', loading: _loading, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
