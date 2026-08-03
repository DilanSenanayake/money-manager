import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
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
    final budgetCtrl = TextEditingController(
      text: monthlyBudget?.toStringAsFixed(0) ?? '',
    );
    final nameCtrl = TextEditingController(text: name);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
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
                'Edit ${type == 'expense' ? 'budget' : 'category'}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              AppTextField(controller: nameCtrl, label: 'Name'),
              if (type == 'expense') ...[
                const SizedBox(height: 12),
                AppTextField(
                  controller: budgetCtrl,
                  label: 'Monthly budget',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              const SizedBox(height: 16),
              AppButton(
                label: 'Save',
                onPressed: () async {
                  await ref.read(categoriesRepositoryProvider).updateCategory(
                        id: id,
                        name: nameCtrl.text.trim(),
                        icon: icon,
                        type: type,
                        monthlyBudget: budgetCtrl.text.trim().isEmpty
                            ? null
                            : double.tryParse(budgetCtrl.text),
                      );
                  ref.invalidate(categoriesProvider);
                  ref.invalidate(dashboardProvider);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
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
              final nameCtrl = TextEditingController();
              final budgetCtrl = TextEditingController();
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (context) => Padding(
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
                        'New expense category',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(controller: nameCtrl, label: 'Name'),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: budgetCtrl,
                        label: 'Monthly budget (optional)',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Create',
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          await ref
                              .read(categoriesRepositoryProvider)
                              .createCategory(
                                name: nameCtrl.text.trim(),
                                icon: 'circle',
                                type: 'expense',
                                monthlyBudget: budgetCtrl.text.trim().isEmpty
                                    ? null
                                    : double.tryParse(budgetCtrl.text),
                              );
                          ref.invalidate(categoriesProvider);
                          ref.invalidate(dashboardProvider);
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: dash.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is Failure ? e.message : e.toString(),
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
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'This month',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                if (data.budgets.isEmpty)
                  const AppCard(
                    child: Text(
                      'Set a monthly budget on expense categories to see progress.',
                    ),
                  )
                else
                  ...data.budgets.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BudgetBar(progress: b),
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
                                  c.type,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.slate),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            c.monthlyBudget == null
                                ? 'No limit'
                                : c.monthlyBudget!.toStringAsFixed(0),
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
