import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/exception_mapper.dart';
import '../../../core/network/supabase_client.dart';
import '../../../shared/models/models.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(SupabaseBootstrap.client);
});

final profileProvider = FutureProvider.autoDispose<Profile>((ref) {
  return ref.watch(settingsRepositoryProvider).getProfile();
});

final exchangeRatesProvider =
    FutureProvider.autoDispose<List<ExchangeRate>>((ref) {
  return ref.watch(settingsRepositoryProvider).getExchangeRates();
});

class SettingsRepository {
  SettingsRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Unauthorized');
    return id;
  }

  Future<Profile> getProfile() async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', _uid)
          .single();
      return Profile.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> updateProfile({
    required String displayName,
    required String baseCurrency,
  }) async {
    try {
      final current = await getProfile();
      await _client.from('profiles').update({
        'display_name': displayName,
        'base_currency': baseCurrency,
      }).eq('id', _uid);

      // Keep accounts on the previous base currency in sync (matches web).
      if (current.baseCurrency != baseCurrency) {
        await _client
            .from('accounts')
            .update({'currency': baseCurrency})
            .eq('user_id', _uid)
            .eq('currency', current.baseCurrency);
      }
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<List<ExchangeRate>> getExchangeRates() async {
    try {
      final data = await _client
          .from('exchange_rates')
          .select()
          .eq('user_id', _uid)
          .order('from_currency');
      return (data as List)
          .map(
            (e) => ExchangeRate.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> upsertExchangeRate({
    required String fromCurrency,
    required String toCurrency,
    required double rate,
  }) async {
    try {
      await _client.from('exchange_rates').upsert({
        'user_id': _uid,
        'from_currency': fromCurrency,
        'to_currency': toCurrency,
        'rate': rate,
      }, onConflict: 'user_id,from_currency,to_currency');
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> deleteExchangeRate(String id) async {
    try {
      await _client
          .from('exchange_rates')
          .delete()
          .eq('id', id)
          .eq('user_id', _uid);
    } catch (e) {
      throw mapException(e);
    }
  }
}
