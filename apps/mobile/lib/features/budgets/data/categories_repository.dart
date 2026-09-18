import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/exception_mapper.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.watch(ledgerlyApiProvider));
});

final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) {
  return ref.watch(categoriesRepositoryProvider).getCategories();
});

class CategoriesRepository {
  CategoriesRepository(this._api);

  final LedgerlyApi _api;

  Future<List<Category>> getCategories() async {
    try {
      return await _api.get<List<Category>>(
        '/v1/categories',
        parse: (json) => parseList(json, Category.fromJson),
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> createCategory({
    required String name,
    required String icon,
    required String type,
    double? monthlyBudget,
  }) async {
    try {
      await _api.mutate(
        '/v1/categories',
        body: {
          'name': name,
          'icon': icon,
          'type': type,
          'monthly_budget': monthlyBudget,
        },
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String icon,
    required String type,
    double? monthlyBudget,
  }) async {
    try {
      await _api.mutate(
        '/v1/categories/$id',
        method: 'PATCH',
        body: {
          'name': name,
          'icon': icon,
          'type': type,
          'monthly_budget': monthlyBudget,
        },
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _api.mutate('/v1/categories/$id', method: 'DELETE');
    } catch (e) {
      throw mapException(e);
    }
  }
}
