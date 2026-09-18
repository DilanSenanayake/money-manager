import 'package:equatable/equatable.dart';

import '../../core/utils/json.dart';

class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.baseCurrency,
    this.displayName,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String baseCurrency;
  final String? displayName;
  final String createdAt;
  final String updatedAt;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: asString(json['id']),
      baseCurrency: asString(json['base_currency'], 'USD'),
      displayName: asNullableString(json['display_name']),
      createdAt: asString(json['created_at']),
      updatedAt: asString(json['updated_at']),
    );
  }

  Map<String, dynamic> toUpdateJson() => {
        'base_currency': baseCurrency,
        'display_name': displayName,
      };

  Profile copyWith({String? baseCurrency, String? displayName}) {
    return Profile(
      id: id,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, baseCurrency, displayName];
}

class Account extends Equatable {
  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
    required this.currency,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String userId;
  final String name;
  final String type;
  final double balance;
  final String currency;
  final String createdAt;
  final String updatedAt;

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: asString(json['id']),
      userId: asString(json['user_id']),
      name: asString(json['name']),
      type: asString(json['type'], 'cash'),
      balance: asDouble(json['balance']),
      currency: asString(json['currency'], 'USD'),
      createdAt: asString(json['created_at']),
      updatedAt: asString(json['updated_at']),
    );
  }

  @override
  List<Object?> get props => [id, name, type, balance, currency];
}

class Category extends Equatable {
  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.type,
    this.monthlyBudget,
    this.createdAt = '',
  });

  final String id;
  final String userId;
  final String name;
  final String icon;
  final String type;
  final double? monthlyBudget;
  final String createdAt;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: asString(json['id']),
      userId: asString(json['user_id']),
      name: asString(json['name']),
      icon: asString(json['icon'], 'circle'),
      type: asString(json['type'], 'expense'),
      monthlyBudget: json['monthly_budget'] == null
          ? null
          : asDouble(json['monthly_budget']),
      createdAt: asString(json['created_at']),
    );
  }

  @override
  List<Object?> get props => [id, name, icon, type, monthlyBudget];
}

class Transaction extends Equatable {
  const Transaction({
    required this.id,
    required this.userId,
    required this.accountId,
    this.categoryId,
    required this.amount,
    required this.type,
    required this.date,
    this.merchant,
    this.notes,
    this.isRecurring = false,
    this.recurringFrequency,
    this.transferPairId,
    this.transferDirection,
    this.createdAt = '',
    this.account,
    this.category,
  });

  final String id;
  final String userId;
  final String accountId;
  final String? categoryId;
  final double amount;
  final String type;
  final String date;
  final String? merchant;
  final String? notes;
  final bool isRecurring;
  final String? recurringFrequency;
  final String? transferPairId;
  final String? transferDirection;
  final String createdAt;
  final Account? account;
  final Category? category;

  bool get isTransfer => type == 'transfer' || transferPairId != null;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: asString(json['id']),
      userId: asString(json['user_id']),
      accountId: asString(json['account_id']),
      categoryId: asNullableString(json['category_id']),
      amount: asDouble(json['amount']),
      type: asString(json['type'], 'expense'),
      date: asString(json['date']),
      merchant: asNullableString(json['merchant']),
      notes: asNullableString(json['notes']),
      isRecurring: asBool(json['is_recurring']),
      recurringFrequency: asNullableString(json['recurring_frequency']),
      transferPairId: asNullableString(json['transfer_pair_id']),
      transferDirection: asNullableString(json['transfer_direction']),
      createdAt: asString(json['created_at']),
      account: json['account'] is Map
          ? Account.fromJson(asMap(json['account']))
          : null,
      category: json['category'] is Map
          ? Category.fromJson(asMap(json['category']))
          : null,
    );
  }

  @override
  List<Object?> get props => [id, amount, type, date, merchant];
}

class ExchangeRate extends Equatable {
  const ExchangeRate({
    required this.id,
    required this.userId,
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    this.updatedAt = '',
  });

  final String id;
  final String userId;
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final String updatedAt;

  factory ExchangeRate.fromJson(Map<String, dynamic> json) {
    return ExchangeRate(
      id: asString(json['id']),
      userId: asString(json['user_id']),
      fromCurrency: asString(json['from_currency']),
      toCurrency: asString(json['to_currency']),
      rate: asDouble(json['rate'], 1),
      updatedAt: asString(json['updated_at']),
    );
  }

  @override
  List<Object?> get props => [id, fromCurrency, toCurrency, rate];
}

class BudgetProgress extends Equatable {
  const BudgetProgress({
    required this.category,
    required this.spent,
    required this.limit,
    required this.ratio,
    required this.status,
  });

  final Category category;
  final double spent;
  final double limit;
  final double ratio;
  final String status;

  factory BudgetProgress.fromJson(Map<String, dynamic> json) {
    return BudgetProgress(
      category: Category.fromJson(asMap(json['category'])),
      spent: asDouble(json['spent']),
      limit: asDouble(json['limit']),
      ratio: asDouble(json['ratio']),
      status: asString(json['status'], 'none'),
    );
  }

  @override
  List<Object?> get props => [category, spent, limit, ratio, status];
}

class TrendPoint extends Equatable {
  const TrendPoint({
    required this.month,
    required this.income,
    required this.expense,
  });

  final String month;
  final double income;
  final double expense;

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      month: asString(json['month']),
      income: asDouble(json['income']),
      expense: asDouble(json['expense']),
    );
  }

  @override
  List<Object?> get props => [month, income, expense];
}

class CategorySpendPoint extends Equatable {
  const CategorySpendPoint({
    required this.name,
    required this.value,
  });

  final String name;
  final double value;

  factory CategorySpendPoint.fromJson(Map<String, dynamic> json) {
    return CategorySpendPoint(
      name: asString(json['name']),
      value: asDouble(json['value']),
    );
  }

  @override
  List<Object?> get props => [name, value];
}

class DashboardData extends Equatable {
  const DashboardData({
    this.profile,
    required this.accounts,
    required this.rates,
    required this.netWorth,
    required this.income,
    required this.expense,
    required this.budgets,
    required this.recent,
    required this.baseCurrency,
    this.monthStart = '',
    this.monthEnd = '',
  });

  final Profile? profile;
  final List<Account> accounts;
  final List<ExchangeRate> rates;
  final double netWorth;
  final double income;
  final double expense;
  final List<BudgetProgress> budgets;
  final List<Transaction> recent;
  final String baseCurrency;
  final String monthStart;
  final String monthEnd;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      profile: json['profile'] is Map
          ? Profile.fromJson(asMap(json['profile']))
          : null,
      accounts: asList(json['accounts'])
          .whereType<Map>()
          .map((e) => Account.fromJson(asMap(e)))
          .toList(),
      rates: asList(json['rates'])
          .whereType<Map>()
          .map((e) => ExchangeRate.fromJson(asMap(e)))
          .toList(),
      netWorth: asDouble(json['netWorth'] ?? json['net_worth']),
      income: asDouble(json['income']),
      expense: asDouble(json['expense']),
      budgets: asList(json['budgets'])
          .whereType<Map>()
          .map((e) => BudgetProgress.fromJson(asMap(e)))
          .toList(),
      recent: asList(json['recent'])
          .whereType<Map>()
          .map((e) => Transaction.fromJson(asMap(e)))
          .toList(),
      baseCurrency: asString(
        json['baseCurrency'] ?? json['base_currency'],
        'USD',
      ),
      monthStart: asString(json['monthStart'] ?? json['month_start']),
      monthEnd: asString(json['monthEnd'] ?? json['month_end']),
    );
  }

  @override
  List<Object?> get props =>
      [profile, accounts, netWorth, income, expense, baseCurrency];
}

class AnalyticsData extends Equatable {
  const AnalyticsData({
    required this.trend,
    required this.categorySpend,
    required this.baseCurrency,
  });

  final List<TrendPoint> trend;
  final List<CategorySpendPoint> categorySpend;
  final String baseCurrency;

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      trend: asList(json['trend'])
          .whereType<Map>()
          .map((e) => TrendPoint.fromJson(asMap(e)))
          .toList(),
      categorySpend: asList(json['categorySpend'] ?? json['category_spend'])
          .whereType<Map>()
          .map((e) => CategorySpendPoint.fromJson(asMap(e)))
          .toList(),
      baseCurrency: asString(
        json['baseCurrency'] ?? json['base_currency'],
        'USD',
      ),
    );
  }

  @override
  List<Object?> get props => [trend, categorySpend, baseCurrency];
}

class TransactionInput {
  const TransactionInput({
    required this.accountId,
    this.categoryId,
    required this.amount,
    required this.type,
    required this.date,
    this.merchant,
    this.notes,
    this.isRecurring = false,
    this.recurringFrequency,
    this.transferToAccountId,
  });

  final String accountId;
  final String? categoryId;
  final double amount;
  final String type;
  final String date;
  final String? merchant;
  final String? notes;
  final bool isRecurring;
  final String? recurringFrequency;
  final String? transferToAccountId;

  Map<String, dynamic> toJson() => {
        'account_id': accountId,
        'category_id': categoryId,
        'amount': amount,
        'type': type,
        'date': date,
        'merchant': merchant,
        'notes': notes,
        'is_recurring': isRecurring,
        'recurring_frequency':
            isRecurring ? (recurringFrequency ?? 'monthly') : null,
        if (transferToAccountId != null)
          'transfer_to_account_id': transferToAccountId,
      };
}

class TransactionFilter {
  const TransactionFilter({
    this.q,
    this.accountId,
    this.categoryId,
    this.type,
    this.from,
    this.to,
  });

  final String? q;
  final String? accountId;
  final String? categoryId;
  final String? type;
  final String? from;
  final String? to;

  Map<String, dynamic> toQuery() => {
        'q': q,
        'account_id': accountId,
        'category_id': categoryId,
        'type': type,
        'from': from,
        'to': to,
      };

  TransactionFilter copyWith({
    String? q,
    String? accountId,
    String? categoryId,
    String? type,
    String? from,
    String? to,
    bool clearAccount = false,
    bool clearCategory = false,
    bool clearType = false,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearQ = false,
  }) {
    return TransactionFilter(
      q: clearQ ? null : (q ?? this.q),
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      type: clearType ? null : (type ?? this.type),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }
}

class ReceiptLineItem {
  const ReceiptLineItem({
    required this.name,
    this.quantity,
    this.price,
  });

  final String name;
  final double? quantity;
  final double? price;

  factory ReceiptLineItem.fromJson(Map<String, dynamic> json) {
    return ReceiptLineItem(
      name: asString(json['name']),
      quantity: json['quantity'] == null ? null : asDouble(json['quantity']),
      price: json['price'] == null ? null : asDouble(json['price']),
    );
  }
}

class ReceiptExtraction {
  const ReceiptExtraction({
    required this.merchant,
    required this.amount,
    required this.currency,
    required this.date,
    required this.category,
    this.lineItems = const [],
    this.notes,
  });

  final String merchant;
  final double amount;
  final String currency;
  final String date;
  final String category;
  final List<ReceiptLineItem> lineItems;
  final String? notes;

  factory ReceiptExtraction.fromJson(Map<String, dynamic> json) {
    return ReceiptExtraction(
      merchant: asString(json['merchant']),
      amount: asDouble(json['amount']),
      currency: asString(json['currency'], 'USD'),
      date: asString(json['date']),
      category: asString(json['category'], 'Other'),
      lineItems: asList(json['line_items'])
          .whereType<Map>()
          .map((e) => ReceiptLineItem.fromJson(asMap(e)))
          .toList(),
      notes: asNullableString(json['notes']),
    );
  }
}

class SmsExtraction {
  const SmsExtraction({
    required this.amount,
    required this.type,
    required this.merchant,
    required this.date,
    this.currency,
    this.accountHint,
    this.notes,
  });

  final double amount;
  final String type;
  final String merchant;
  final String date;
  final String? currency;
  final String? accountHint;
  final String? notes;

  bool get isIncome {
    final value = type.toLowerCase();
    return value == 'credit' || value == 'income' || value == 'cr';
  }

  factory SmsExtraction.fromJson(Map<String, dynamic> json) {
    return SmsExtraction(
      amount: asDouble(json['amount']),
      type: asString(json['type'], 'Debit'),
      merchant: asString(json['merchant'], 'Unknown'),
      date: asString(json['date']),
      currency: asNullableString(json['currency']),
      accountHint: asNullableString(json['account_hint']),
      notes: asNullableString(json['notes']),
    );
  }
}

class QuickTextExtraction {
  const QuickTextExtraction({
    required this.amount,
    required this.type,
    required this.merchant,
    required this.date,
    required this.category,
    this.currency,
    this.notes,
  });

  final double amount;
  final String type;
  final String merchant;
  final String date;
  final String category;
  final String? currency;
  final String? notes;

  factory QuickTextExtraction.fromJson(Map<String, dynamic> json) {
    return QuickTextExtraction(
      amount: asDouble(json['amount']),
      type: asString(json['type'], 'expense'),
      merchant: asString(json['merchant']),
      date: asString(json['date']),
      category: asString(json['category'], 'Other'),
      currency: asNullableString(json['currency']),
      notes: asNullableString(json['notes']),
    );
  }
}

class AiReviewSave {
  const AiReviewSave({
    required this.accountId,
    this.categoryId,
    required this.amount,
    required this.type,
    required this.date,
    this.merchant,
    this.notes,
    this.isRecurring = false,
    this.recurringFrequency,
  });

  final String accountId;
  final String? categoryId;
  final double amount;
  final String type;
  final String date;
  final String? merchant;
  final String? notes;
  final bool isRecurring;
  final String? recurringFrequency;

  Map<String, dynamic> toJson() => {
        'account_id': accountId,
        'category_id': categoryId,
        'amount': amount,
        'type': type,
        'date': date,
        'merchant': merchant,
        'notes': notes,
        'is_recurring': isRecurring,
        'recurring_frequency':
            isRecurring ? (recurringFrequency ?? 'monthly') : null,
      };
}

T parseDataEnvelope<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) {
  final map = asMap(json);
  final data = map['data'];
  if (data is Map) return fromJson(asMap(data));
  throw const FormatException('Smart add returned an empty result.');
}

List<T> parseList<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) {
  return asList(json)
      .whereType<Map>()
      .map((e) => fromJson(asMap(e)))
      .toList();
}
