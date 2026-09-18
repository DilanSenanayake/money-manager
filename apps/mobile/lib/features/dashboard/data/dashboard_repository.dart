import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/exception_mapper.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';
import '../../../shared/models/models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(ledgerlyApiProvider));
});

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) {
  return ref.watch(dashboardRepositoryProvider).getDashboardData();
});

final analyticsProvider = FutureProvider.autoDispose<AnalyticsData>((ref) {
  return ref.watch(dashboardRepositoryProvider).getAnalyticsData();
});

final budgetsProvider =
    FutureProvider.autoDispose<List<BudgetProgress>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getBudgets();
});

class DashboardRepository {
  DashboardRepository(this._api);

  final LedgerlyApi _api;

  Future<DashboardData> getDashboardData() async {
    try {
      return await _api.get<DashboardData>(
        '/v1/dashboard',
        parse: (json) => DashboardData.fromJson(asMap(json)),
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<AnalyticsData> getAnalyticsData() async {
    try {
      return await _api.get<AnalyticsData>(
        '/v1/dashboard/analytics',
        parse: (json) => AnalyticsData.fromJson(asMap(json)),
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<List<BudgetProgress>> getBudgets() async {
    try {
      return await _api.get<List<BudgetProgress>>(
        '/v1/dashboard/budgets',
        parse: (json) => parseList(json, BudgetProgress.fromJson),
      );
    } catch (e) {
      throw mapException(e);
    }
  }
}
