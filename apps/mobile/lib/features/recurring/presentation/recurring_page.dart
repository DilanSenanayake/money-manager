import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/category_visuals.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../transactions/data/transactions_repository.dart';

final recurringProvider =
    FutureProvider.autoDispose<List<_RecurringItem>>((ref) async {
  final txs = await ref.watch(transactionsRepositoryProvider).getRecurring();
  final today = localDateYYYYMMDD();
  final seen = <String>{};
  final items = <_RecurringItem>[];

  for (final tx in txs) {
    final key =
        '${tx.merchant ?? ''}|${tx.amount}|${tx.recurringFrequency}|${tx.categoryId}';
    if (!seen.add(key)) continue;

    var next = tx.date;
    var guard = 0;
    while (next.compareTo(today) < 0 && guard < 120) {
      next = addFrequency(next, tx.recurringFrequency ?? 'monthly');
      guard++;
    }
    items.add(_RecurringItem(transaction: tx, nextDue: next));
  }

  items.sort((a, b) => a.nextDue.compareTo(b.nextDue));
  return items;
});

class _RecurringItem {
  const _RecurringItem({required this.transaction, required this.nextDue});
  final Transaction transaction;
  final String nextDue;
}

class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recurringProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(
          message: e is Failure
              ? e.message
              : "Couldn't load recurring bills.",
          onRetry: () => ref.invalidate(recurringProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.event_repeat_outlined,
              title: 'No upcoming bills yet',
              message:
                  'When you add a purchase, mark it as recurring to see the next due date here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(recurringProvider),
            child: ListView.separated(
              padding: AppSpacing.page,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = items[i];
                final tx = item.transaction;
                return AppCard(
                  child: Row(
                    children: [
                      CategoryMark(
                        icon: tx.category?.icon,
                        name: tx.category?.name,
                        framed: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.merchant?.isNotEmpty == true
                                  ? tx.merchant!
                                  : (tx.category?.name ?? 'Recurring'),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Next ${formatFriendlyDate(item.nextDue)} · ${tx.recurringFrequency ?? 'monthly'}',
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
                        formatMoney(
                          tx.amount,
                          tx.account?.currency ?? 'USD',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
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
