import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/utils/category_match.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/receipt_currency.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money_input.dart';
import '../../../shared/components/components.dart';
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
  String? ocrText,
}) async {
  // Root navigator so the sheet sits above the shell bottom nav
  // (`extendBody: true` otherwise paints the bar over nested routes).
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AiReviewSheet(
      source: source,
      extraction: extraction,
      ocrText: ocrText,
    ),
  );
  return result == true;
}

class AiReviewSheet extends ConsumerStatefulWidget {
  const AiReviewSheet({
    super.key,
    required this.source,
    required this.extraction,
    this.ocrText,
  });

  final String source;
  final Object extraction;
  final String? ocrText;

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
  bool _converting = false;
  int _convertSeq = 0;
  bool _autoConvertStarted = false;
  double? _sourceAmount;
  String? _sourceCurrency;
  String? _amountCurrency;
  double? _rate;
  String? _warning;
  String? _proposedAccountId;
  String? _proposedCategoryId;
  late final String _proposedMerchant;
  String? _payeeKey;
  bool _categoryBaselineSet = false;
  bool _receiptPrepared = false;
  double? _displayAmount;

  ({String? categoryId, String? accountId, String? payeeKey}) get _feedback {
    final extraction = widget.extraction;
    if (extraction is ReceiptExtraction) {
      return (
        categoryId: extraction.categoryId,
        accountId: extraction.accountId,
        payeeKey: extraction.payeeKey,
      );
    }
    if (extraction is SmsExtraction) {
      return (
        categoryId: extraction.categoryId,
        accountId: extraction.accountId,
        payeeKey: extraction.payeeKey,
      );
    }
    if (extraction is QuickTextExtraction) {
      return (
        categoryId: extraction.categoryId,
        accountId: extraction.accountId,
        payeeKey: extraction.payeeKey,
      );
    }
    return (categoryId: null, accountId: null, payeeKey: null);
  }

  @override
  void initState() {
    super.initState();
    final parsed = _parsed();
    _amount = TextEditingController(
      text: widget.extraction is ReceiptExtraction ? '' : parsed.amount.toString(),
    );
    _merchant = TextEditingController(text: parsed.merchant);
    _notes = TextEditingController(text: parsed.notes ?? '');
    _type = parsed.type;
    _date = parsed.date.isEmpty ? localDateYYYYMMDD() : parsed.date;
    _proposedMerchant = parsed.merchant;
    _payeeKey = _feedback.payeeKey;
    final extraction = widget.extraction;
    if (extraction is ReceiptExtraction) {
      _sourceAmount = extraction.sourceAmount ?? extraction.amount;
      _sourceCurrency =
          (extraction.sourceCurrency ?? extraction.currency).toUpperCase();
      _amountCurrency = extraction.currency.toUpperCase();
      final rate = extraction.exchangeRate;
      _rate = rate != null && rate > 0 ? rate : null;
      final warning = extraction.conversionWarning?.trim();
      _warning = warning == null || warning.isEmpty ? null : warning;
    }
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

  Account? _accountById(List<Account> accounts, String? id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  void _prepareReceiptAmount(List<Account> accounts) {
    if (_receiptPrepared || widget.extraction is! ReceiptExtraction) return;
    final account = _accountById(accounts, _accountId);
    if (account == null) return;
    _receiptPrepared = true;
    final extraction = widget.extraction as ReceiptExtraction;
    final target = account.currency.toUpperCase();
    final rate = extraction.exchangeRate;
    final serverConverted = extraction.sourceCurrency != null &&
        rate != null &&
        rate > 0 &&
        extraction.currency.toUpperCase() == target;
    if (serverConverted) {
      _displayAmount = extraction.amount;
      _sourceAmount = extraction.sourceAmount ?? extraction.amount;
      _sourceCurrency = extraction.sourceCurrency!.toUpperCase();
      _amountCurrency = target;
      _rate = rate;
      _warning = null;
      return;
    }

    final printed = resolveReceiptCurrency(
      modelCurrency: extraction.currency,
      ocrText: widget.ocrText,
      targetCurrency: target,
    );
    _sourceAmount = extraction.sourceAmount ?? extraction.amount;
    _sourceCurrency = printed;
    _amountCurrency = printed;
    _rate = null;
    final warning = extraction.conversionWarning?.trim();
    _warning = warning == null || warning.isEmpty ? null : warning;
    if (printed == target) {
      _displayAmount = _sourceAmount;
    } else {
      _displayAmount = null;
      _converting = true;
    }
  }

  bool _amountMatches(List<Account> accounts) {
    if (widget.extraction is! ReceiptExtraction || _amountCurrency == null) {
      return true;
    }
    final account = _accountById(accounts, _accountId);
    if (account == null) return true;
    return account.currency.toUpperCase() == _amountCurrency;
  }

  String _moneyText(double amount, String currency) {
    if (currency == 'JPY') return amount.round().toString();
    return amount.toStringAsFixed(2);
  }

  String _rateText(double rate) {
    var text = rate.toStringAsFixed(6);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    return text;
  }

  Future<void> _changeAccount(String? id, List<Account> accounts) async {
    final next = _accountById(accounts, id);
    if (next == null) return;
    final seq = ++_convertSeq;
    final nextCurrency = next.currency.toUpperCase();
    final sourceCurrency = _sourceCurrency;
    final sourceAmount = _sourceAmount;
    if (widget.extraction is! ReceiptExtraction ||
        sourceCurrency == null ||
        sourceAmount == null ||
        nextCurrency == _amountCurrency) {
      setState(() {
        _accountId = id;
        _converting = false;
      });
      return;
    }

    if (nextCurrency == sourceCurrency) {
      setState(() {
        _accountId = id;
        _amount.text = _moneyText(sourceAmount, nextCurrency);
        _amountCurrency = nextCurrency;
        _rate = null;
        _warning = null;
        _converting = false;
      });
      return;
    }

    final previous = _accountId;
    setState(() {
      _accountId = id;
      _converting = true;
    });
    try {
      final converted = await ref.read(aiRepositoryProvider).convertAmount(
            amount: sourceAmount,
            fromCurrency: sourceCurrency,
            toCurrency: nextCurrency,
          );
      if (!mounted || seq != _convertSeq) return;
      setState(() {
        _amount.text = _moneyText(converted.amount, converted.currency);
        _amountCurrency = converted.currency.toUpperCase();
        _rate = converted.rate > 0 ? converted.rate : null;
        _warning = null;
        _converting = false;
      });
    } catch (e) {
      if (!mounted || seq != _convertSeq) return;
      setState(() {
        _accountId = previous;
        _converting = false;
        if (_amount.text.trim().isEmpty && sourceAmount != null) {
          _amount.text = _moneyText(sourceAmount, sourceCurrency);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is Failure ? e.message : e.toString())),
      );
    }
  }

  void _acceptUnconverted(List<Account> accounts) {
    final account = _accountById(accounts, _accountId);
    if (account == null) return;
    setState(() {
      _amountCurrency = account.currency.toUpperCase();
      _rate = null;
      _warning = null;
    });
  }

  Future<void> _save(List<Account> accounts, List<Category> categories) async {
    final amount = canonicalMoney(_amount.text);
    if (!_amountMatches(accounts)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Convert the receipt amount before saving'),
        ),
      );
      return;
    }
    if (amount == null || _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount and account')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final savedCategory = _categoryId ??
          matchCategoryId(
            categories.where((c) => c.type == _type).toList(),
            _type,
            [
              _parsed().category,
              _merchant.text,
              _notes.text,
            ],
          );
      await ref.read(aiRepositoryProvider).saveReviewed(
            AiReviewSave(
              accountId: _accountId!,
              categoryId: savedCategory,
              amount: amount,
              type: _type,
              date: _date,
              merchant:
                  _merchant.text.trim().isEmpty ? null : _merchant.text.trim(),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              proposedCategoryId:
                  _categoryId == null ? savedCategory : _proposedCategoryId,
              proposedAccountId: _proposedAccountId ?? _accountId,
              proposedMerchant: _proposedMerchant,
              payeeKey: _payeeKey,
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
    if (accounts.isNotEmpty && _proposedAccountId == null) {
      final hinted = _feedback.accountId;
      final initial = hinted != null && accounts.any((a) => a.id == hinted)
          ? hinted
          : accounts.first.id;
      _proposedAccountId = initial;
      _accountId ??= initial;
    } else {
      _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;
    }
    _prepareReceiptAmount(accounts);
    if (!_autoConvertStarted &&
        _receiptPrepared &&
        widget.extraction is ReceiptExtraction) {
      _autoConvertStarted = true;
      final id = _accountId;
      final matches = _amountMatches(accounts);
      final display = _displayAmount;
      final displayCurrency = _amountCurrency;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (matches) {
          if (display != null && displayCurrency != null) {
            setState(() {
              _amount.text = _moneyText(display, displayCurrency);
              _converting = false;
            });
          }
          return;
        }
        final latest = ref.read(accountsProvider).valueOrNull ?? accounts;
        _changeAccount(id, latest);
      });
    }
    final filtered = categories.where((c) => c.type == _type).toList();
    if (!_categoryBaselineSet && filtered.isNotEmpty) {
      _categoryBaselineSet = true;
      final hinted = _feedback.categoryId;
      final parsed = _parsed();
      _proposedCategoryId = hinted != null && filtered.any((c) => c.id == hinted)
          ? hinted
          : matchCategoryId(filtered, parsed.type, [
              parsed.category,
              parsed.merchant,
              parsed.notes,
            ]);
      _categoryId ??= _proposedCategoryId;
    }
    final selectedAccount = _accountById(accounts, _accountId);
    final amountCurrency = _converting
        ? (selectedAccount?.currency ?? _amountCurrency ?? 'USD')
        : (_amountCurrency ?? selectedAccount?.currency ?? 'USD');
    final showRate = widget.extraction is ReceiptExtraction &&
        _rate != null &&
        _sourceCurrency != null &&
        _sourceAmount != null &&
        _sourceCurrency != amountCurrency;
    final mismatch = !_amountMatches(accounts);

    final selectedCategoryId = _categoryId ??
        matchCategoryId(filtered, _type, [
          _parsed().category,
          _merchant.text,
          _notes.text,
        ]);

    final media = MediaQuery.of(context);
    final bottomPad = media.viewInsets.bottom + media.padding.bottom + 16;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: bottomPad,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.92 - media.viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'expense',
                          label: Text('Expense'),
                        ),
                        ButtonSegment(
                          value: 'income',
                          label: Text('Income'),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => setState(() {
                        _type = s.first;
                        _categoryId = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    AmountField(
                      controller: _amount,
                      label: 'Amount ($amountCurrency)',
                    ),
                    if (showRate) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Receipt total ${formatMoney(_sourceAmount!, _sourceCurrency!)} converted at today\'s rate (1 $_sourceCurrency = ${_rateText(_rate!)} $amountCurrency).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                    if (_converting) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Converting to ${selectedAccount?.currency ?? ''}…',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (_warning != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _warning!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                    if (mismatch && !_converting) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Save stays off until this amount is in ${selectedAccount?.currency}.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () =>
                                _changeAccount(_accountId, accounts),
                            child: Text(
                              'Convert to ${selectedAccount?.currency}',
                            ),
                          ),
                          TextButton(
                            onPressed: () => _acceptUnconverted(accounts),
                            child: Text(
                              'Use this number as ${selectedAccount?.currency}',
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    CategoryChipRow(
                      categories: filtered,
                      selectedId: selectedCategoryId,
                      onSelected: (id) => setState(() => _categoryId = id),
                    ),
                    const SizedBox(height: 12),
                    DateField(
                      value: _date,
                      onChanged: (v) => setState(() => _date = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_accountId),
                      initialValue: _accountId,
                      decoration:
                          const InputDecoration(labelText: 'Account'),
                      items: accounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text('${a.name} (${a.currency})'),
                            ),
                          )
                          .toList(),
                      onChanged: _converting
                          ? null
                          : (v) => _changeAccount(v, accounts),
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
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Save',
              loading: _loading || _converting,
              onPressed: mismatch || _converting
                  ? null
                  : () => _save(accounts, categories),
            ),
          ],
        ),
      ),
    );
  }
}
