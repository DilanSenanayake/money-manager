import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/exception_mapper.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository(ref.watch(ledgerlyApiProvider));
});

final transactionsProvider = FutureProvider.autoDispose
    .family<List<Transaction>, TransactionFilter>((ref, filter) {
  return ref.watch(transactionsRepositoryProvider).getTransactions(filter);
});

class TransactionsRepository {
  TransactionsRepository(this._api);

  final LedgerlyApi _api;

  Future<List<Transaction>> getTransactions([
    TransactionFilter filter = const TransactionFilter(),
  ]) async {
    try {
      return await _api.get<List<Transaction>>(
        '/v1/transactions',
        query: filter.toQuery(),
        parse: (json) => parseList(json, Transaction.fromJson),
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<List<Transaction>> getRecurring() async {
    try {
      return await _api.get<List<Transaction>>(
        '/v1/transactions/recurring',
        parse: (json) => parseList(json, Transaction.fromJson),
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> createTransaction(TransactionInput input) async {
    if (input.amount <= 0) {
      throw const ValidationFailure('Amount must be greater than zero');
    }
    try {
      await _api.mutate('/v1/transactions', body: input.toJson());
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> updateTransaction(String id, TransactionInput input) async {
    if (input.type == 'transfer') {
      throw const ValidationFailure(
        'Edit transfers by deleting and recreating them',
      );
    }
    if (input.amount <= 0) {
      throw const ValidationFailure('Amount must be greater than zero');
    }
    try {
      await _api.mutate(
        '/v1/transactions/$id',
        method: 'PATCH',
        body: input.toJson(),
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> deleteTransaction(Transaction tx) async {
    try {
      await _api.mutate('/v1/transactions/${tx.id}', method: 'DELETE');
    } catch (e) {
      throw mapException(e);
    }
  }
}
