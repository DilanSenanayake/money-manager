import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exception_mapper.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/models.dart';

class DashboardData {
  const DashboardData({
    required this.profile,
    required this.accounts,
    required this.rates,
    required this.netWorth,
    required this.income,
    required this.expense,
    required this.budgets,
    required this.recent,
    required this.baseCurrency,
  });

  final Profile profile;
  final List<Account> accounts;
  final List<ExchangeRate> rates;
  final double netWorth;
  final double income;
  final double expense;
  final List<BudgetProgress> budgets;
  final List<Transaction> recent;
  final String baseCurrency;
}

class AnalyticsData {
  const AnalyticsData({
    required this.trend,
    required this.categorySpend,
    required this.baseCurrency,
  });

  final List<({String month, double income, double expense})> trend;
  final List<({String name, double value})> categorySpend;
  final String baseCurrency;
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(SupabaseBootstrap.client);
});

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) {
  return ref.watch(dashboardRepositoryProvider).getDashboardData();
});

final analyticsProvider = FutureProvider.autoDispose<AnalyticsData>((ref) {
  return ref.watch(dashboardRepositoryProvider).getAnalyticsData();
});

class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Unauthorized');
    return id;
  }

  Future<DashboardData> getDashboardData() async {
    try {
      final profileRaw = _client.from('profiles').select().eq('id', _uid).single();
      final accountsRaw = _client.from('accounts').select().eq('user_id', _uid);
      final categoriesRaw =
          _client.from('categories').select().eq('user_id', _uid);
      final ratesRaw =
          _client.from('exchange_rates').select().eq('user_id', _uid);

      final results = await Future.wait<dynamic>([
        profileRaw,
        accountsRaw,
        categoriesRaw,
        ratesRaw,
      ]);

      final profile =
          Profile.fromJson(Map<String, dynamic>.from(results[0] as Map));
      final accounts = (results[1] as List)
          .map((e) => Account.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final categories = (results[2] as List)
          .map((e) => Category.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final rates = (results[3] as List)
          .map(
            (e) => ExchangeRate.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      final monthStart = localMonthStartYYYYMMDD();
      final monthEnd = localMonthEndYYYYMMDD();

      final monthTxRaw = await _client
          .from('transactions')
          .select()
          .eq('user_id', _uid)
          .gte('date', monthStart)
          .lte('date', monthEnd);
      final recentRaw = await _client
          .from('transactions')
          .select('*, account:accounts(*), category:categories(*)')
          .eq('user_id', _uid)
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .limit(AppConstants.recentTransactionLimit);

      final monthTx = (monthTxRaw as List)
          .map(
            (e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      final recent = (recentRaw as List)
          .map(
            (e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      final baseCurrency = profile.baseCurrency;
      final currencyByAccount = accountCurrencyMap(accounts);
      final netWorth = computeNetWorth(accounts, baseCurrency, rates);

      double toBase(Transaction t) => txAmountInBase(
            t.amount,
            t.accountId,
            currencyByAccount,
            baseCurrency,
            rates,
          );

      final income = monthTx
          .where((t) => t.type == 'income')
          .fold<double>(0, (s, t) => s + toBase(t));
      final expense = monthTx
          .where((t) => t.type == 'expense')
          .fold<double>(0, (s, t) => s + toBase(t));

      final budgets = categories
          .where(
            (c) =>
                c.type == 'expense' &&
                c.monthlyBudget != null &&
                c.monthlyBudget! > 0,
          )
          .map((category) {
            final spent = monthTx
                .where(
                  (t) =>
                      t.type == 'expense' && t.categoryId == category.id,
                )
                .fold<double>(0, (s, t) => s + toBase(t));
            final limit = category.monthlyBudget ?? 0;
            final ratio = limit > 0 ? spent / limit : 0.0;
            return BudgetProgress(
              category: category,
              spent: spent,
              limit: limit,
              ratio: ratio,
              status: budgetStatus(spent, limit),
            );
          })
          .toList()
        ..sort((a, b) => b.ratio.compareTo(a.ratio));

      return DashboardData(
        profile: profile,
        accounts: accounts,
        rates: rates,
        netWorth: netWorth,
        income: income,
        expense: expense,
        budgets: budgets,
        recent: recent,
        baseCurrency: baseCurrency,
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<AnalyticsData> getAnalyticsData() async {
    try {
      final now = DateTime.now();
      final months = List.generate(6, (i) {
        final d = DateTime(now.year, now.month - (5 - i), 1);
        return (
          key: DateFormat('yyyy-MM').format(d),
          label: DateFormat('MMM').format(d),
          from: localMonthStartYYYYMMDD(d),
          to: localMonthEndYYYYMMDD(d),
        );
      });

      final txRaw = _client
          .from('transactions')
          .select()
          .eq('user_id', _uid)
          .gte('date', months.first.from)
          .lte('date', months.last.to);
      final categoriesRaw = _client
          .from('categories')
          .select()
          .eq('user_id', _uid)
          .eq('type', 'expense');
      final accountsRaw =
          _client.from('accounts').select('id, currency').eq('user_id', _uid);
      final profileRaw =
          _client.from('profiles').select().eq('id', _uid).single();
      final ratesRaw =
          _client.from('exchange_rates').select().eq('user_id', _uid);

      final results = await Future.wait<dynamic>([
        txRaw,
        categoriesRaw,
        accountsRaw,
        profileRaw,
        ratesRaw,
      ]);

      final tx = (results[0] as List)
          .map(
            (e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      final categories = (results[1] as List)
          .map((e) => Category.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final accounts = (results[2] as List)
          .map((e) => Account.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final profile =
          Profile.fromJson(Map<String, dynamic>.from(results[3] as Map));
      final rates = (results[4] as List)
          .map(
            (e) => ExchangeRate.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      final baseCurrency = profile.baseCurrency;
      final currencyByAccount = accountCurrencyMap(accounts);
      double toBase(Transaction t) => txAmountInBase(
            t.amount,
            t.accountId,
            currencyByAccount,
            baseCurrency,
            rates,
          );

      final trend = months.map((m) {
        final inMonth =
            tx.where((t) => t.date.compareTo(m.from) >= 0 && t.date.compareTo(m.to) <= 0);
        return (
          month: m.label,
          income: inMonth
              .where((t) => t.type == 'income')
              .fold<double>(0, (s, t) => s + toBase(t)),
          expense: inMonth
              .where((t) => t.type == 'expense')
              .fold<double>(0, (s, t) => s + toBase(t)),
        );
      }).toList();

      final thisMonth = months.last;
      final categorySpend = categories
          .map((cat) {
            final spent = tx
                .where(
                  (t) =>
                      t.type == 'expense' &&
                      t.categoryId == cat.id &&
                      t.date.compareTo(thisMonth.from) >= 0 &&
                      t.date.compareTo(thisMonth.to) <= 0,
                )
                .fold<double>(0, (s, t) => s + toBase(t));
            return (name: cat.name, value: spent);
          })
          .where((c) => c.value > 0)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return AnalyticsData(
        trend: trend,
        categorySpend: categorySpend,
        baseCurrency: baseCurrency,
      );
    } catch (e) {
      throw mapException(e);
    }
  }
}
