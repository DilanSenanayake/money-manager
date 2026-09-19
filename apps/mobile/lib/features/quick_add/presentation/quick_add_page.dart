import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/ocr/receipt_ocr.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../shared/components/components.dart';
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
    final params = GoRouterState.of(context).uri.queryParameters;
    final mode = params['mode'];
    final type = params['type'];
    var nextMode = _mode;
    if (mode == 'receipt' ||
        mode == 'sms' ||
        mode == 'text' ||
        mode == 'manual') {
      nextMode = mode!;
    }
    if (type == 'income' || type == 'expense') {
      _type = type!;
      nextMode = 'manual';
    }
    if (nextMode != _mode) {
      _mode = nextMode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    if (!_handledInitialMode && _mode == 'receipt') {
      _handledInitialMode = true;
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
      body: SafeArea(
        child: Stack(
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
                  title: 'Add a wallet first',
                  message:
                      'You need an account before logging activity. Add cash, bank, or a card.',
                  actionLabel: 'Add account',
                  onAction: () => context.push(RoutePaths.accounts),
                );
              }
              _accountId ??= accounts.first.id;
              final categories = categoriesAsync.valueOrNull ?? [];
              final filtered =
                  categories.where((c) => c.type == _type).toList();

              return ListView(
                padding: AppSpacing.page,
                children: [
                  const PageHeader(
                    title: 'Add',
                    description:
                        'Let AI fill the details — scan, paste, describe, or enter manually',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  CaptureModeGrid(
                    compact: true,
                    modes: [
                      CaptureMode(
                        icon: Icons.photo_camera_outlined,
                        label: 'Scan',
                        selected: _mode == 'receipt',
                        onTap: () {
                          setState(() => _mode = 'receipt');
                          _pickReceipt();
                        },
                      ),
                      CaptureMode(
                        icon: Icons.content_paste_rounded,
                        label: 'SMS',
                        selected: _mode == 'sms',
                        onTap: () => setState(() => _mode = 'sms'),
                      ),
                      CaptureMode(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Type',
                        selected: _mode == 'text',
                        onTap: () => setState(() => _mode = 'text'),
                      ),
                      CaptureMode(
                        icon: Icons.edit_note_rounded,
                        label: 'Manual',
                        selected: _mode == 'manual',
                        onTap: () => setState(() => _mode = 'manual'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: AppDuration.normal,
                    switchInCurve: Curves.easeOutCubic,
                    child: Column(
                      key: ValueKey(_mode),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  if (_mode == 'receipt') ...[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Take a photo of a receipt. We’ll read it on this device, then you check & save.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
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
                      hint: 'Rs 4,500 debited from A/C ...',
                      maxLines: 5,
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            setState(() => _sms.text = data!.text!);
                          }
                        },
                        child: const Text('Paste from clipboard'),
                      ),
                    ),
                    AppButton(
                      label: 'Continue',
                      onPressed: _parseSms,
                      icon: Icons.auto_awesome,
                    ),
                  ] else if (_mode == 'text') ...[
                    AppTextField(
                      controller: _quickText,
                      label: 'Describe it',
                      hint: 'Coffee 4.50',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Continue',
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
                    const SizedBox(height: 20),
                    AmountField(controller: _amount, autofocus: true),
                    const SizedBox(height: 16),
                    Text(
                      'Category',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    CategoryChipRow(
                      categories: filtered,
                      selectedId: _categoryId,
                      onSelected: (id) => setState(() => _categoryId = id),
                    ),
                    const SizedBox(height: 16),
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
                    AppTextField(
                      controller: _merchant,
                      label: 'Description (optional)',
                      hint: 'Where or what',
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
                      label: 'Save',
                      loading: _loading,
                      onPressed: _saveManual,
                      icon: Icons.check_rounded,
                    ),
                  ],
                      ],
                    ),
                  ),
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
      ),
    );
  }
}
