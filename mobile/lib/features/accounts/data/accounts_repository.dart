import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/exception_mapper.dart';
import '../../../core/network/supabase_client.dart';
import '../../../shared/models/models.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(SupabaseBootstrap.client);
});

final accountsProvider = FutureProvider.autoDispose<List<Account>>((ref) {
  return ref.watch(accountsRepositoryProvider).getAccounts();
});

class AccountsRepository {
  AccountsRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Unauthorized');
    return id;
  }

  Future<List<Account>> getAccounts() async {
    try {
      final data = await _client
          .from('accounts')
          .select()
          .eq('user_id', _uid)
          .order('created_at');
      return (data as List)
          .map((e) => Account.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
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
      await _client.from('accounts').insert({
        'user_id': _uid,
        'name': name,
        'type': type,
        'balance': balance,
        'currency': currency,
      });
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
      await _client.from('accounts').update({
        'name': name,
        'type': type,
        'currency': currency,
      }).eq('id', id).eq('user_id', _uid);
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> deleteAccount(String id) async {
    try {
      await _client.from('accounts').delete().eq('id', id).eq('user_id', _uid);
    } catch (e) {
      throw mapException(e);
    }
  }
}
