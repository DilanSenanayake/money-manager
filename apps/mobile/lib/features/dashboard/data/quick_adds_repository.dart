import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/exception_mapper.dart';
import '../../../core/network/api_client.dart';

final quickAddsRepositoryProvider = Provider<QuickAddsRepository>((ref) {
  return QuickAddsRepository(ref.watch(ledgerlyApiProvider));
});

class QuickAddsRepository {
  QuickAddsRepository(this._api);

  final LedgerlyApi _api;

  Future<void> create({
    required String merchant,
    String? notes,
    required String categoryId,
    required String amount,
  }) async {
    try {
      await _api.mutate(
        '/v1/quick-adds',
        body: {
          'merchant': merchant,
          'notes': notes,
          'category_id': categoryId,
          'amount': amount,
        },
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _api.mutate('/v1/quick-adds/$id', method: 'DELETE');
    } catch (e) {
      throw mapException(e);
    }
  }
}
