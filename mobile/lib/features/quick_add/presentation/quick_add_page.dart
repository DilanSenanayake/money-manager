import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../budgets/data/categories_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../transactions/data/transactions_repository.dart';

class QuickAddPage extends ConsumerStatefulWidget {
  const QuickAddPage({super.key});

  @override
  ConsumerState<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends ConsumerState<QuickAddPage> {
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'expense';
  String? _accountId;
  String? _categoryId;
  bool _loading = false;
  String _mode = 'manual';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mode = GoRouterState.of(context).uri.queryParameters['mode'];
    if (mode != null) _mode = mode;
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
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an account')),
      );
      return;
    }

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
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            ),
          );
      await HapticFeedback.mediumImpact();
      ref.invalidate(dashboardProvider);
      ref.invalidate(transactionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      context.go(RoutePaths.home);
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
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quick add')),
      body: accountsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is Failure ? e.message : e.toString(),
          onRetry: () => ref.invalidate(accountsProvider),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Add an account first',
              message: 'You need a wallet before logging transactions.',
              actionLabel: 'Accounts',
              onAction: () => context.push(RoutePaths.accounts),
            );
          }
          _accountId ??= accounts.first.id;

          final categories = categoriesAsync.valueOrNull ?? [];
          final filtered =
              categories.where((c) => c.type == _type).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              if (_mode != 'manual') ...[
                AppCard(
                  child: Row(
                    children: [
                      Icon(
                        _mode == 'receipt'
                            ? Icons.document_scanner_outlined
                            : Icons.sms_outlined,
                        color: AppColors.teal700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _mode == 'receipt'
                              ? 'Receipt AI parsing arrives in a later update via a secure Edge Function. Use manual entry for now.'
                              : 'SMS / text AI parsing arrives later. Paste details into merchant/notes and save manually.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                ],
                selected: {_type},
                onSelectionChanged: (s) {
                  setState(() {
                    _type = s.first;
                    _categoryId = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _amount,
                label: 'Amount',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Icons.payments_outlined,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: const InputDecoration(labelText: 'Account'),
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
              const SizedBox(height: 16),
              Text(
                'Category',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filtered.map((c) {
                  final selected = _categoryId == c.id;
                  return ChoiceChip(
                    label: Text(c.name),
                    selected: selected,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _merchant,
                label: 'Merchant (optional)',
                prefixIcon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _notes,
                label: 'Notes (optional)',
                maxLines: 3,
                prefixIcon: Icons.notes_rounded,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Save transaction',
                loading: _loading,
                onPressed: _save,
                icon: Icons.check_rounded,
              ),
            ],
          );
        },
      ),
    );
  }
}
