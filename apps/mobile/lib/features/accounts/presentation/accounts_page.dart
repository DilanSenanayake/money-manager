import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/labels.dart';
import '../../../shared/components/components.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/accounts_repository.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    String? id,
    String? name,
    String? type,
    String? currency,
    double? balance,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AccountEditor(
        id: id,
        initialName: name,
        initialType: type ?? 'cash',
        initialCurrency: currency ?? 'USD',
        initialBalance: balance ?? 0,
      ),
    );
    ref.invalidate(accountsProvider);
    ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            onPressed: () => _openEditor(context, ref),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(
          message: e is Failure ? e.message : "Couldn't load your wallets.",
          onRetry: () => ref.invalidate(accountsProvider),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No wallets yet',
              message:
                  'Add cash, checking, savings, or a card so balances stay in view.',
              actionLabel: 'Add account',
              onAction: () => _openEditor(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(accountsProvider),
            child: ListView.separated(
              padding: AppSpacing.page,
              itemCount: accounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final a = accounts[i];
                return AppCard(
                  onTap: () => _openEditor(
                    context,
                    ref,
                    id: a.id,
                    name: a.name,
                    type: a.type,
                    currency: a.currency,
                    balance: a.balance,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(
                          iconForAccountType(a.type),
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${labelForAccountType(a.type)} · ${a.currency}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      MoneyText(a.balance, currency: a.currency),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AccountEditor extends ConsumerStatefulWidget {
  const _AccountEditor({
    this.id,
    this.initialName,
    required this.initialType,
    required this.initialCurrency,
    required this.initialBalance,
  });

  final String? id;
  final String? initialName;
  final String initialType;
  final String initialCurrency;
  final double initialBalance;

  @override
  ConsumerState<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends ConsumerState<_AccountEditor> {
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late String _type;
  late String _currency;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName ?? '');
    _balance =
        TextEditingController(text: widget.initialBalance.toStringAsFixed(2));
    _type = widget.initialType;
    _currency = widget.initialCurrency;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an account name')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(accountsRepositoryProvider);
      if (widget.id == null) {
        await repo.createAccount(
          name: _name.text.trim(),
          type: _type,
          balance: double.tryParse(_balance.text) ?? 0,
          currency: _currency,
        );
      } else {
        if (_currency != widget.initialCurrency &&
            widget.initialBalance != 0) {
          throw const ValidationFailure(
            'Change currency only when the balance is zero, or transfer funds out first',
          );
        }
        await repo.updateAccount(
          id: widget.id!,
          name: _name.text.trim(),
          type: _type,
          currency: _currency,
        );
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
    if (widget.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
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
    if (ok != true) return;
    await ref.read(accountsRepositoryProvider).deleteAccount(widget.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.id == null ? 'New account' : 'Edit account',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          AppTextField(controller: _name, label: 'Name'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: AppConstants.accountTypes
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(labelForAccountType(t)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? 'cash'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: AppConstants.currencies
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _currency = v ?? 'USD'),
          ),
          if (widget.id == null) ...[
            const SizedBox(height: 12),
            AppTextField(
              controller: _balance,
              label: 'Opening balance',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Balance updates automatically from activity.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 16),
          AppButton(label: 'Save', loading: _loading, onPressed: _save),
          if (widget.id != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _delete,
              child: const Text('Delete account'),
            ),
          ],
        ],
      ),
    );
  }
}
