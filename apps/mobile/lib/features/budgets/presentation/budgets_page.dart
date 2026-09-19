import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/category_visuals.dart';
import '../../../core/utils/labels.dart';
import '../../../core/utils/money.dart';
import '../../../shared/components/components.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/categories_repository.dart';

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref, {
    required String id,
    required String name,
    required String icon,
    required String type,
    double? monthlyBudget,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CategoryEditorSheet(
        title: 'Edit ${type == 'expense' ? 'budget' : 'category'}',
        submitLabel: 'Save',
        initialName: name,
        initialIcon: icon,
        type: type,
        initialBudget: monthlyBudget,
        onSubmit: (nextName, nextIcon, nextBudget) async {
          await ref.read(categoriesRepositoryProvider).updateCategory(
                id: id,
                name: nextName,
                icon: nextIcon,
                type: type,
                monthlyBudget: nextBudget,
              );
          ref.invalidate(categoriesProvider);
          ref.invalidate(dashboardProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final cats = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (context) => _CategoryEditorSheet(
                  title: 'New expense category',
                  submitLabel: 'Create',
                  initialName: '',
                  initialIcon: 'circle',
                  type: 'expense',
                  onSubmit: (name, icon, budget) async {
                    await ref.read(categoriesRepositoryProvider).createCategory(
                          name: name,
                          icon: icon,
                          type: 'expense',
                          monthlyBudget: budget,
                        );
                    ref.invalidate(categoriesProvider);
                    ref.invalidate(dashboardProvider);
                  },
                ),
              );
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: dash.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(
          message: e is Failure ? e.message : "Couldn't load your budgets.",
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (data) {
          final categories = cats.valueOrNull ?? [];
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardProvider);
              ref.invalidate(categoriesProvider);
            },
            child: ListView(
              padding: AppSpacing.page,
              children: [
                Text(
                  'This month',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                if (data.budgets.isEmpty)
                  EmptyState(
                    icon: Icons.pie_chart_outline_rounded,
                    title: 'No budgets yet',
                    message:
                        'Set a monthly limit on an expense category to see if spending is on track.',
                  )
                else
                  ...data.budgets.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BudgetBar(
                        progress: b,
                        currency: data.baseCurrency,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'All categories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                ...categories.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => _editCategory(
                        context,
                        ref,
                        id: c.id,
                        name: c.name,
                        icon: c.icon,
                        type: c.type,
                        monthlyBudget: c.monthlyBudget,
                      ),
                      child: Row(
                        children: [
                          CategoryMark(
                            icon: c.icon,
                            name: c.name,
                            framed: true,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  labelForTxType(c.type),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            c.monthlyBudget == null
                                ? 'No limit'
                                : formatMoney(
                                    c.monthlyBudget!,
                                    data.baseCurrency,
                                  ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryEditorSheet extends StatefulWidget {
  const _CategoryEditorSheet({
    required this.title,
    required this.submitLabel,
    required this.initialName,
    required this.initialIcon,
    required this.type,
    this.initialBudget,
    required this.onSubmit,
  });

  final String title;
  final String submitLabel;
  final String initialName;
  final String initialIcon;
  final String type;
  final double? initialBudget;
  final Future<void> Function(String name, String icon, double? budget)
      onSubmit;

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _budgetCtrl;
  late String _icon;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _budgetCtrl = TextEditingController(
      text: widget.initialBudget?.toStringAsFixed(0) ?? '',
    );
    _icon = widget.initialIcon;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          AppTextField(controller: _nameCtrl, label: 'Name'),
          const SizedBox(height: 12),
          Text(
            'Icon',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          CategoryIconPicker(
            value: _icon,
            onChanged: (id) => setState(() => _icon = id),
          ),
          if (widget.type == 'expense') ...[
            const SizedBox(height: 12),
            AppTextField(
              controller: _budgetCtrl,
              label: widget.initialName.isEmpty
                  ? 'Monthly budget (optional)'
                  : 'Monthly budget',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: widget.submitLabel,
            loading: _saving,
            onPressed: () async {
              final name = _nameCtrl.text.trim();
              if (name.isEmpty) return;
              setState(() => _saving = true);
              try {
                await widget.onSubmit(
                  name,
                  _icon,
                  _budgetCtrl.text.trim().isEmpty
                      ? null
                      : double.tryParse(_budgetCtrl.text),
                );
                if (context.mounted) Navigator.pop(context);
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
          ),
        ],
        ),
      ),
    );
  }
}
