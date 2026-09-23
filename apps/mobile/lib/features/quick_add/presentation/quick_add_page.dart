import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
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
import '../../../core/utils/smart_input.dart';
import '../../../core/voice/voice_input.dart';
import '../../../shared/components/components.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../budgets/data/categories_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/ai_repository.dart';
import 'ai_review_sheet.dart';

/// Add path: AI composer (sparkles) vs enter-details form (+). Legacy query modes map in.
class QuickAddPage extends ConsumerStatefulWidget {
  const QuickAddPage({super.key});

  @override
  ConsumerState<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends ConsumerState<QuickAddPage> {
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _notes = TextEditingController();
  final _composer = TextEditingController();
  String _type = 'expense';
  String _date = localDateYYYYMMDD();
  String? _accountId;
  String? _categoryId;
  bool _loading = false;
  String _busyMessage = 'Please wait…';
  /// `smart` | `manual`
  String _path = 'smart';
  final _picker = ImagePicker();
  final _voice = VoiceInput();
  bool _listening = false;
  bool? _voiceAvailable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoverLostReceipt();
      _probeVoice();
    });
  }

  Future<void> _probeVoice() async {
    final ok = await _voice.ensureReady();
    if (!mounted) return;
    setState(() => _voiceAvailable = ok);
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    await _voice.start(
      onWords: (words) {
        if (!mounted) return;
        setState(() {
          _composer.text = words;
          _composer.selection = TextSelection.collapsed(offset: words.length);
        });
      },
      onListeningChanged: (listening) {
        if (!mounted) return;
        setState(() => _listening = listening);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _listening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
    if (!mounted) return;
    setState(() => _listening = _voice.isListening);
  }

  Future<void> _stopVoiceIfNeeded() async {
    if (!_listening) return;
    await _voice.stop();
    if (mounted) setState(() => _listening = false);
  }

  String? _pathFromQuery(String? mode, String? type) {
    if (type == 'income' || type == 'expense') return 'manual';
    if (mode == 'manual') return 'manual';
    if (mode == 'receipt' ||
        mode == 'sms' ||
        mode == 'text' ||
        mode == 'voice' ||
        mode == 'smart') {
      return 'smart';
    }
    // No mode → keep whatever the Add tab already shows.
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final params = GoRouterState.of(context).uri.queryParameters;
    final type = params['type'];
    if (type == 'income' || type == 'expense') {
      _type = type!;
    }
    final next = _pathFromQuery(params['mode'], type);
    if (next != null && next != _path) {
      _path = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _voice.dispose();
    _amount.dispose();
    _merchant.dispose();
    _notes.dispose();
    _composer.dispose();
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

  Future<void> _switchPath(String next) async {
    await _stopVoiceIfNeeded();
    setState(() => _path = next);
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to paste from the clipboard')),
      );
      return;
    }
    setState(() {
      _composer.text = text;
      _composer.selection = TextSelection.collapsed(offset: text.length);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pasted')),
    );
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

  Future<void> _recoverLostReceipt() async {
    if (kIsWeb) return;
    try {
      final lost = await _picker.retrieveLostData();
      if (lost.isEmpty || lost.file == null) return;
      await _processPickedReceipt(lost.file!);
    } catch (_) {}
  }

  Future<void> _pickReceipt({required ImageSource source}) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
        requestFullMetadata: false,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked == null) return;
      await _processPickedReceipt(picked);
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (_isPickerCancel(e)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_pickerErrorMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is Failure ? e.message : e.toString())),
      );
    }
  }

  Future<void> _processPickedReceipt(XFile picked) async {
    try {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        if (bytes.length > AppConstants.maxReceiptBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('That photo is too large. Use one under 8 MB.'),
            ),
          );
          return;
        }
        if (!mounted) return;
        final saved = await showAiReviewSheet(
          context: context,
          ref: ref,
          source: 'receipt',
          extraction: ReceiptExtraction(
            merchant: '',
            amount: 0,
            currency: 'USD',
            date: localDateYYYYMMDD(),
            category: 'Other',
            notes: 'From photo — enter the amount and details you see.',
          ),
        );
        if (saved) await _afterSave();
        return;
      }

      final local = await _copyPickedFile(picked);
      final bytes = await local.length();
      if (bytes > AppConstants.maxReceiptBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That photo is too large. Use one under 8 MB.'),
          ),
        );
        return;
      }

      setState(() {
        _loading = true;
        _busyMessage = 'Reading your receipt…';
      });
      final text = await ReceiptOcr().extractText(local.path);
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

  Future<XFile> _copyPickedFile(XFile picked) async {
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';
    final dest = File(
      '${Directory.systemTemp.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await dest.writeAsBytes(await picked.readAsBytes(), flush: true);
    return XFile(dest.path);
  }

  bool _isPickerCancel(PlatformException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();
    return code.contains('cancel') ||
        message.contains('cancel') ||
        message.contains('canceled');
  }

  String _pickerErrorMessage(PlatformException e) {
    final blob = '${e.code} ${e.message ?? ''}'.toLowerCase();
    if (blob.contains('camera') && blob.contains('permission')) {
      return 'Allow camera access in system settings, or choose a photo from the gallery.';
    }
    if (blob.contains('photo') && blob.contains('permission')) {
      return 'Allow photo access in system settings, then try again.';
    }
    if (blob.contains('camera')) {
      return 'Could not open the camera. Choose a photo from the gallery instead.';
    }
    return 'Could not open that photo. Try the gallery, or add it manually.';
  }

  Future<void> _runComposerContinue() async {
    await _stopVoiceIfNeeded();
    final text = _composer.text.trim();
    if (text.isEmpty || _loading) return;

    final asSms = looksLikeBankSms(text);
    setState(() {
      _loading = true;
      _busyMessage = asSms
          ? 'Picking out the amount and details…'
          : 'Understanding that note…';
    });
    try {
      final extraction = asSms
          ? await ref.read(aiRepositoryProvider).parseSms(text)
          : await ref.read(aiRepositoryProvider).parseQuickText(text);
      if (!mounted) return;
      setState(() => _loading = false);
      final saved = await showAiReviewSheet(
        context: context,
        ref: ref,
        source: asSms ? 'sms' : 'text',
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
                          'Use AI to describe it, or + to enter the details',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    CaptureModeGrid(
                      compact: true,
                      modes: [
                        CaptureMode(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Add with AI — type, paste, speak, or scan',
                          iconOnly: true,
                          selected: _path == 'smart',
                          onTap: () => _switchPath('smart'),
                        ),
                        CaptureMode(
                          icon: Icons.add_rounded,
                          label: 'Enter details yourself',
                          iconOnly: true,
                          selected: _path == 'manual',
                          onTap: () => _switchPath('manual'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: AppDuration.normal,
                      switchInCurve: Curves.easeOutCubic,
                      child: _path == 'smart'
                          ? _SmartComposer(
                              key: const ValueKey('smart'),
                              controller: _composer,
                              listening: _listening,
                              voiceAvailable: _voiceAvailable,
                              loading: _loading,
                              onToggleVoice: _toggleVoice,
                              onPaste: _pasteClipboard,
                              onCamera: () =>
                                  _pickReceipt(source: ImageSource.camera),
                              onGallery: () =>
                                  _pickReceipt(source: ImageSource.gallery),
                              onContinue: _runComposerContinue,
                            )
                          : _ManualForm(
                              key: const ValueKey('manual'),
                              type: _type,
                              onTypeChanged: (t) {
                                setState(() {
                                  _type = t;
                                  _categoryId = null;
                                });
                              },
                              amount: _amount,
                              merchant: _merchant,
                              notes: _notes,
                              date: _date,
                              onDateChanged: (v) => setState(() => _date = v),
                              accountId: _accountId,
                              accounts: accounts,
                              onAccountChanged: (v) =>
                                  setState(() => _accountId = v),
                              categories: filtered,
                              categoryId: _categoryId,
                              onCategoryChanged: (id) =>
                                  setState(() => _categoryId = id),
                              loading: _loading,
                              onSave: _saveManual,
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
                        const IndeterminateBar(width: 120),
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

class _SmartComposer extends StatefulWidget {
  const _SmartComposer({
    super.key,
    required this.controller,
    required this.listening,
    required this.voiceAvailable,
    required this.loading,
    required this.onToggleVoice,
    required this.onPaste,
    required this.onCamera,
    required this.onGallery,
    required this.onContinue,
  });

  final TextEditingController controller;
  final bool listening;
  final bool? voiceAvailable;
  final bool loading;
  final VoidCallback onToggleVoice;
  final VoidCallback onPaste;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onContinue;

  @override
  State<_SmartComposer> createState() => _SmartComposerState();
}

class _SmartComposerState extends State<_SmartComposer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant _SmartComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.listening;
    final loading = widget.loading;
    final borderColor = listening
        ? context.colors.error
        : context.colors.outlineVariant;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tell us what happened',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Type or paste a note or bank SMS, speak it, or attach a receipt photo',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: borderColor, width: listening ? 1.5 : 1),
            ),
            child: Column(
              children: [
                TextField(
                  controller: widget.controller,
                  enabled: !loading,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Coffee 450 · or paste a bank SMS…',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                  ),
                ),
                Divider(height: 1, color: context.colors.outlineVariant),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Take receipt photo',
                        onPressed: loading ? null : widget.onCamera,
                        icon: const Icon(Icons.photo_camera_outlined),
                      ),
                      IconButton(
                        tooltip: 'Choose from gallery',
                        onPressed: loading ? null : widget.onGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                      ),
                      IconButton(
                        tooltip: 'Paste from clipboard',
                        onPressed: loading ? null : widget.onPaste,
                        icon: const Icon(Icons.content_paste_rounded),
                      ),
                      if (widget.voiceAvailable != false)
                        IconButton(
                          tooltip:
                              listening ? 'Stop listening' : 'Speak to fill',
                          onPressed: loading ? null : widget.onToggleVoice,
                          icon: Icon(
                            listening
                                ? Icons.mic_off_rounded
                                : Icons.mic_none_rounded,
                            color: listening ? context.colors.error : null,
                          ),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed:
                            loading || widget.controller.text.trim().isEmpty
                                ? null
                                : widget.onContinue,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Continue'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            listening
                ? 'Listening… tap the mic when you’re done'
                : 'Short notes use Smart Add text. Long bank alerts are read as SMS. Receipts use the camera or gallery.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: listening
                      ? context.colors.primary
                      : context.colors.onSurfaceVariant,
                  fontWeight: listening ? FontWeight.w600 : FontWeight.w400,
                ),
          ),
        ],
      ),
    );
  }
}

class _ManualForm extends StatelessWidget {
  const _ManualForm({
    super.key,
    required this.type,
    required this.onTypeChanged,
    required this.amount,
    required this.merchant,
    required this.notes,
    required this.date,
    required this.onDateChanged,
    required this.accountId,
    required this.accounts,
    required this.onAccountChanged,
    required this.categories,
    required this.categoryId,
    required this.onCategoryChanged,
    required this.loading,
    required this.onSave,
  });

  final String type;
  final ValueChanged<String> onTypeChanged;
  final TextEditingController amount;
  final TextEditingController merchant;
  final TextEditingController notes;
  final String date;
  final ValueChanged<String> onDateChanged;
  final String? accountId;
  final List<Account> accounts;
  final ValueChanged<String?> onAccountChanged;
  final List<Category> categories;
  final String? categoryId;
  final ValueChanged<String?> onCategoryChanged;
  final bool loading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'expense', label: Text('Expense')),
            ButtonSegment(value: 'income', label: Text('Income')),
          ],
          selected: {type},
          onSelectionChanged: (s) => onTypeChanged(s.first),
        ),
        const SizedBox(height: 20),
        AmountField(controller: amount, autofocus: true),
        const SizedBox(height: 16),
        Text(
          'Category',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        CategoryChipRow(
          categories: categories,
          selectedId: categoryId,
          onSelected: onCategoryChanged,
        ),
        const SizedBox(height: 16),
        DateField(
          value: date,
          onChanged: onDateChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: accountId,
          decoration: const InputDecoration(labelText: 'Account'),
          items: accounts
              .map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name} (${a.currency})'),
                ),
              )
              .toList(),
          onChanged: onAccountChanged,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: merchant,
          label: 'Description (optional)',
          hint: 'Where or what',
          prefixIcon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: notes,
          label: 'Notes (optional)',
          maxLines: 3,
          prefixIcon: Icons.notes_rounded,
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Save',
          loading: loading,
          onPressed: onSave,
          icon: Icons.check_rounded,
        ),
      ],
    );
  }
}
