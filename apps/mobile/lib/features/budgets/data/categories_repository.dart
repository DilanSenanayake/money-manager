import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/exception_mapper.dart';
import '../../../core/network/supabase_client.dart';
import '../../../shared/models/models.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(SupabaseBootstrap.client);
});

final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) {
  return ref.watch(categoriesRepositoryProvider).getCategories();
});

class CategoriesRepository {
  CategoriesRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Unauthorized');
    return id;
  }

  Future<List<Category>> getCategories() async {
    try {
      final data = await _client
          .from('categories')
          .select()
          .eq('user_id', _uid)
          .order('name');
      return (data as List)
          .map((e) => Category.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
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
      await _client.from('categories').insert({
        'user_id': _uid,
        'name': name,
        'icon': icon,
        'type': type,
        'monthly_budget': monthlyBudget,
      });
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
      await _client.from('categories').update({
        'name': name,
        'icon': icon,
        'type': type,
        'monthly_budget': monthlyBudget,
      }).eq('id', id).eq('user_id', _uid);
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _client.from('categories').delete().eq('id', id).eq('user_id', _uid);
    } catch (e) {
      throw mapException(e);
    }
  }
}
