import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/exception_mapper.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref.watch(ledgerlyApiProvider));
});

final accountsProvider = FutureProvider.autoDispose<List<Account>>((ref) {
  return ref.watch(accountsRepositoryProvider).getAccounts();
});

class AccountsRepository {
  AccountsRepository(this._api);

  final LedgerlyApi _api;

  Future<List<Account>> getAccounts() async {
    try {
      return await _api.get<List<Account>>(
        '/v1/accounts',
        parse: (json) => parseList(json, Account.fromJson),
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> createAccount({
    required String name,
    required String type,
    required double balance,
    required String currency,
  }) async {
    try {
      await _api.mutate(
        '/v1/accounts',
        body: {
          'name': name,
          'type': type,
          'balance': balance,
          'currency': currency,
        },
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> updateAccount({
    required String id,
    required String name,
    required String type,
    required String currency,
  }) async {
    try {
      await _api.mutate(
        '/v1/accounts/$id',
        method: 'PATCH',
        body: {
          'name': name,
          'type': type,
          'currency': currency,
        },
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> deleteAccount(String id) async {
    try {
      await _api.mutate('/v1/accounts/$id', method: 'DELETE');
    } catch (e) {
      throw mapException(e);
    }
  }
}
