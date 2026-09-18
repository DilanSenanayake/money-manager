import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/exception_mapper.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';
import '../../../shared/models/models.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(ledgerlyApiProvider));
});

final profileProvider = FutureProvider.autoDispose<Profile>((ref) {
  return ref.watch(settingsRepositoryProvider).getProfile();
});

final exchangeRatesProvider =
    FutureProvider.autoDispose<List<ExchangeRate>>((ref) {
  return ref.watch(settingsRepositoryProvider).getExchangeRates();
});

class SettingsRepository {
  SettingsRepository(this._api);

  final LedgerlyApi _api;

  Future<Profile> getProfile() async {
    try {
      return await _api.get<Profile>(
        '/v1/settings/profile',
        parse: (json) => Profile.fromJson(asMap(json)),
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> updateProfile({
    required String displayName,
    required String baseCurrency,
  }) async {
    try {
      await _api.mutate(
        '/v1/settings/profile',
        method: 'PATCH',
        body: {
          'display_name': displayName,
          'base_currency': baseCurrency,
        },
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<List<ExchangeRate>> getExchangeRates() async {
    try {
      return await _api.get<List<ExchangeRate>>(
        '/v1/settings/exchange-rates',
        parse: (json) => parseList(json, ExchangeRate.fromJson),
      );
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
      await _api.mutate(
        '/v1/settings/exchange-rates',
        method: 'PUT',
        body: {
          'from_currency': fromCurrency,
          'to_currency': toCurrency,
          'rate': rate,
        },
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> deleteExchangeRate(String id) async {
    try {
      await _api.mutate(
        '/v1/settings/exchange-rates/$id',
        method: 'DELETE',
      );
    } catch (e) {
      throw mapException(e);
    }
  }
}
