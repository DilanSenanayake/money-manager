import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exception_mapper.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/utils/category_match.dart';
import '../../../shared/models/models.dart';
import '../../budgets/data/categories_repository.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository(
    SupabaseBootstrap.client,
    ref.watch(categoriesRepositoryProvider),
  );
});

final transactionsProvider =
    FutureProvider.autoDispose.family<List<Transaction>, TransactionFilter>(
        (ref, filter) {
  return ref.watch(transactionsRepositoryProvider).getTransactions(filter);
});

class TransactionsRepository {
  TransactionsRepository(this._client, this._categories);

  final SupabaseClient _client;
  final CategoriesRepository _categories;
  final _uuid = const Uuid();

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Unauthorized');
    return id;
  }

  Future<List<Transaction>> getTransactions([
    TransactionFilter filter = const TransactionFilter(),
  ]) async {
    try {
      var query = _client
          .from('transactions')
          .select('*, account:accounts(*), category:categories(*)')
          .eq('user_id', _uid);

      if (filter.accountId != null) {
        query = query.eq('account_id', filter.accountId!);
      }
      if (filter.categoryId != null) {
        query = query.eq('category_id', filter.categoryId!);
      }
      if (filter.type != null) {
        query = query.eq('type', filter.type!);
      }
      if (filter.from != null) {
        query = query.gte('date', filter.from!);
      }
      if (filter.to != null) {
        query = query.lte('date', filter.to!);
      }
      if (filter.q != null && filter.q!.trim().isNotEmpty) {
        final safe = filter.q!.replaceAll(RegExp(r'[%_,]'), '').trim();
        if (safe.isNotEmpty) {
          query = query.or('merchant.ilike.%$safe%,notes.ilike.%$safe%');
        }
      }

      final data = await query
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .limit(AppConstants.transactionLimit);

      return (data as List)
          .map(
            (e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<List<Transaction>> getRecurring() async {
    try {
      final data = await _client
          .from('transactions')
          .select('*, account:accounts(*), category:categories(*)')
          .eq('user_id', _uid)
          .eq('is_recurring', true)
          .order('date', ascending: false);
      return (data as List)
          .map(
            (e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> createTransaction(TransactionInput input) async {
    try {
      if (input.amount <= 0) {
        throw const ValidationFailure('Amount must be greater than zero');
      }

      if (input.type == 'transfer') {
        final toId = input.transferToAccountId;
        if (toId == null || toId.isEmpty) {
          throw const ValidationFailure('Choose where the money should go');
        }
        if (toId == input.accountId) {
          throw const ValidationFailure(
            'Pick two different accounts for a transfer',
          );
        }

        final pairId = _uuid.v4();
        final base = {
          'user_id': _uid,
          'amount': input.amount,
          'type': 'transfer',
          'date': input.date,
          'merchant': input.merchant ?? 'Transfer',
          'notes': input.notes,
          'is_recurring': false,
          'recurring_frequency': null,
          'transfer_pair_id': pairId,
          'category_id': null,
        };

        await _client.from('transactions').insert([
          {
            ...base,
            'account_id': input.accountId,
            'transfer_direction': 'out',
          },
          {
            ...base,
            'account_id': toId,
            'transfer_direction': 'in',
          },
        ]);
        return;
      }

      var categoryId = input.categoryId;
      if (categoryId == null &&
          (input.type == 'expense' || input.type == 'income')) {
        final categories = await _categories.getCategories();
        categoryId = matchCategoryId(
          categories,
          input.type,
          [input.merchant, input.notes],
        );
      }

      await _client.from('transactions').insert({
        'user_id': _uid,
        'account_id': input.accountId,
        'category_id': categoryId,
        'amount': input.amount,
        'type': input.type,
        'date': input.date,
        'merchant': input.merchant,
        'notes': input.notes,
        'is_recurring': input.isRecurring,
        'recurring_frequency':
            input.isRecurring ? (input.recurringFrequency ?? 'monthly') : null,
      });
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> deleteTransaction(Transaction tx) async {
    try {
      if (tx.transferPairId != null) {
        await _client
            .from('transactions')
            .delete()
            .eq('transfer_pair_id', tx.transferPairId!)
            .eq('user_id', _uid);
      } else {
        await _client
            .from('transactions')
            .delete()
            .eq('id', tx.id)
            .eq('user_id', _uid);
      }
    } catch (e) {
      throw mapException(e);
    }
  }
}
