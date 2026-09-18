import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/ocr/receipt_ocr.dart';
import '../../../core/utils/dates.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../budgets/data/categories_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/ai_repository.dart';
import 'ai_review_sheet.dart';

class QuickAddPage extends ConsumerStatefulWidget {
  const QuickAddPage({super.key});

  @override
  ConsumerState<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends ConsumerState<QuickAddPage> {
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _notes = TextEditingController();
  final _sms = TextEditingController();
  final _quickText = TextEditingController();
  String _type = 'expense';
  String _date = localDateYYYYMMDD();
  String? _accountId;
  String? _categoryId;
  bool _loading = false;
  String _busyMessage = 'Please wait…';
  String _mode = 'manual';
  bool _handledInitialMode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledInitialMode) return;
    _handledInitialMode = true;
    final mode = GoRouterState.of(context).uri.queryParameters['mode'];
    if (mode == 'receipt' || mode == 'sms' || mode == 'text' || mode == 'manual') {
      _mode = mode!;
    }
    if (_mode == 'receipt') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickReceipt();
      });
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _notes.dispose();
    _sms.dispose();
    _quickText.dispose();
    super.dispose();
  }

  Future<void> _afterSave() async {
    await HapticFeedback.mediumImpact();
    ref.invalidate(dashboardProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(analyticsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved')),
    );
    context.go(RoutePaths.home);
  }

  Future<void> _saveManual() async {
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

    setState(() {
      _loading = true;
      _busyMessage = 'Saving…';
    });
    try {
      await ref.read(transactionsRepositoryProvider).createTransaction(
            TransactionInput(
              accountId: _accountId!,
              categoryId: _categoryId,
              amount: amount,
              type: _type,
              date: _date,
              merchant: _merchant.text.trim().isEmpty
                  ? null
                  : _merchant.text.trim(),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            ),
          );
      await _afterSave();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is Failure ? e.message : e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickReceipt({ImageSource source = ImageSource.camera}) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.length();
      if (bytes > AppConstants.maxReceiptBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That photo is too large. Use one under 8 MB.')),
        );
        return;
      }

      setState(() {
        _loading = true;
        _busyMessage = 'Reading your receipt…';
      });
      final text = await ReceiptOcr().extractText(picked.path);
      if (text.trim().length < 8) {
        throw const ValidationFailure(
          'We couldn’t read that photo clearly. Try again with better lighting, or add it manually.',
        );
      }
      setState(() => _busyMessage = 'Filling in the details…');
      final extraction = await ref.read(aiRepositoryProvider).parseReceipt(text);
      if (!mounted) return;
      setState(() => _loading = false);
      final saved = await showAiReviewSheet(
        context: context,
        ref: ref,
        source: 'receipt',
        extraction: extraction,
      );
      if (saved) await _afterSave();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is Failure ? e.message : e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _parseSms() async {
    setState(() {
      _loading = true;
      _busyMessage = 'Reading message…';
    });
    try {
      final extraction =
          await ref.read(aiRepositoryProvider).parseSms(_sms.text);
      if (!mounted) return;
      setState(() => _loading = false);
      final saved = await showAiReviewSheet(
        context: context,
        ref: ref,
        source: 'sms',
        extraction: extraction,
      );
      if (saved) await _afterSave();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is Failure ? e.message : e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _parseText() async {
    setState(() {
      _loading = true;
      _busyMessage = 'Understanding that note…';
    });
    try {
      final extraction =
          await ref.read(aiRepositoryProvider).parseQuickText(_quickText.text);
      if (!mounted) return;
      setState(() => _loading = false);
      final saved = await showAiReviewSheet(
        context: context,
        ref: ref,
        source: 'text',
        extraction: extraction,
      );
      if (saved) await _afterSave();
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
      appBar: AppBar(title: const Text('Add')),
      body: Stack(
        children: [
          accountsAsync.when(
            loading: () => const SkeletonList(),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Manual'),
                        selected: _mode == 'manual',
                        onSelected: (_) => setState(() => _mode = 'manual'),
                      ),
                      ChoiceChip(
                        label: const Text('Scan'),
                        selected: _mode == 'receipt',
                        onSelected: (_) {
                          setState(() => _mode = 'receipt');
                          _pickReceipt();
                        },
                      ),
                      ChoiceChip(
                        label: const Text('SMS'),
                        selected: _mode == 'sms',
                        onSelected: (_) => setState(() => _mode = 'sms'),
                      ),
                      ChoiceChip(
                        label: const Text('Type'),
                        selected: _mode == 'text',
                        onSelected: (_) => setState(() => _mode = 'text'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_mode == 'receipt') ...[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Take a photo of a receipt. We’ll read it on this device, then you confirm before anything is saved.',
                          ),
                          const SizedBox(height: 12),
                          AppButton(
                            label: 'Take photo',
                            onPressed: () =>
                                _pickReceipt(source: ImageSource.camera),
                            icon: Icons.photo_camera_outlined,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _pickReceipt(source: ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Choose from gallery'),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_mode == 'sms') ...[
                    AppTextField(
                      controller: _sms,
                      label: 'Paste a bank SMS',
                      maxLines: 5,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          setState(() => _sms.text = data!.text!);
                        }
                      },
                      child: const Text('Paste from clipboard'),
                    ),
                    AppButton(
                      label: 'Parse message',
                      onPressed: _parseSms,
                      icon: Icons.auto_awesome,
                    ),
                  ] else if (_mode == 'text') ...[
                    AppTextField(
                      controller: _quickText,
                      label: 'Describe it',
                      hint: 'Coffee 450 at Starbucks',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Parse note',
                      onPressed: _parseText,
                      icon: Icons.auto_awesome,
                    ),
                  ] else ...[
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
                          onSelected: (_) =>
                              setState(() => _categoryId = c.id),
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
                      onPressed: _saveManual,
                      icon: Icons.check_rounded,
                    ),
                  ],
                ],
              );
            },
          ),
          if (_loading)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: AppCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_busyMessage),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
