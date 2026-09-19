import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/theme/category_visuals.dart';
import '../../../core/utils/category_match.dart';
import '../../../core/utils/dates.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../budgets/data/categories_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/ai_repository.dart';

Future<bool> showAiReviewSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String source,
  required Object extraction,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AiReviewSheet(source: source, extraction: extraction),
  );
  return result == true;
}

class AiReviewSheet extends ConsumerStatefulWidget {
  const AiReviewSheet({
    super.key,
    required this.source,
    required this.extraction,
  });

  final String source;
  final Object extraction;

  @override
  ConsumerState<AiReviewSheet> createState() => _AiReviewSheetState();
}

class _AiReviewSheetState extends ConsumerState<AiReviewSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _merchant;
  late final TextEditingController _notes;
  late String _type;
  late String _date;
  String? _accountId;
  String? _categoryId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final parsed = _parsed();
    _amount = TextEditingController(text: parsed.amount.toString());
    _merchant = TextEditingController(text: parsed.merchant);
    _notes = TextEditingController(text: parsed.notes ?? '');
    _type = parsed.type;
    _date = parsed.date.isEmpty ? localDateYYYYMMDD() : parsed.date;
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _notes.dispose();
    super.dispose();
  }

  ({
    double amount,
    String type,
    String merchant,
    String date,
    String category,
    String? notes,
  }) _parsed() {
    final extraction = widget.extraction;
    if (extraction is SmsExtraction) {
      return (
        amount: extraction.amount,
        type: extraction.isIncome ? 'income' : 'expense',
        merchant: extraction.merchant,
        date: extraction.date,
        category: '',
        notes: extraction.notes,
      );
    }
    if (extraction is QuickTextExtraction) {
      return (
        amount: extraction.amount,
        type: extraction.type == 'income' ? 'income' : 'expense',
        merchant: extraction.merchant,
        date: extraction.date,
        category: extraction.category,
        notes: extraction.notes,
      );
    }
    final receipt = extraction as ReceiptExtraction;
    return (
      amount: receipt.amount,
      type: 'expense',
      merchant: receipt.merchant,
      date: receipt.date,
      category: receipt.category,
      notes: receipt.notes,
    );
  }

  Future<void> _save(List<Account> accounts, List<Category> categories) async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0 || _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount and account')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(aiRepositoryProvider).saveReviewed(
            AiReviewSave(
              accountId: _accountId!,
              categoryId: _categoryId ??
                  matchCategoryId(
                    categories.where((c) => c.type == _type).toList(),
                    _type,
                    [
                      _parsed().category,
                      _merchant.text,
                      _notes.text,
                    ],
                  ),
              amount: amount,
              type: _type,
              date: _date,
              merchant:
                  _merchant.text.trim().isEmpty ? null : _merchant.text.trim(),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            ),
          );
      ref.invalidate(dashboardProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(analyticsProvider);
      if (mounted) Navigator.pop(context, true);
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
    final selectedCategoryId = _categoryId ??
        matchCategoryId(filtered, _type, [
          _parsed().category,
          _merchant.text,
          _notes.text,
        ]);

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
              'Check & save',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'We filled this in for you — change anything you need, then save.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filtered
                  .map(
                    (c) => CategoryChoiceChip(
                      name: c.name,
                      icon: c.icon,
                      selected: selectedCategoryId == c.id,
                      onSelected: () => setState(() => _categoryId = c.id),
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
            const SizedBox(height: 16),
            AppButton(
              label: 'Save',
              loading: _loading,
              onPressed: () => _save(accounts, categories),
            ),
          ],
        ),
      ),
    );
  }
}
