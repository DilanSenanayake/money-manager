import 'package:equatable/equatable.dart';

class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.baseCurrency,
    this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String baseCurrency;
  final String? displayName;
  final String createdAt;
  final String updatedAt;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      baseCurrency: json['base_currency'] as String? ?? 'USD',
      displayName: json['display_name'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
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
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'cash',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toInsertJson(String userId) => {
        'user_id': userId,
        'name': name,
        'type': type,
        'balance': balance,
        'currency': currency,
      };

  Map<String, dynamic> toUpdateJson() => {
        'name': name,
        'type': type,
        'currency': currency,
      };

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
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? 'circle',
      type: json['type'] as String? ?? 'expense',
      monthlyBudget: (json['monthly_budget'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toInsertJson(String userId) => {
        'user_id': userId,
        'name': name,
        'icon': icon,
        'type': type,
        'monthly_budget': monthlyBudget,
      };

  Map<String, dynamic> toUpdateJson() => {
        'name': name,
        'icon': icon,
        'type': type,
        'monthly_budget': monthlyBudget,
      };

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

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      accountId: json['account_id'] as String,
      categoryId: json['category_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      type: json['type'] as String? ?? 'expense',
      date: json['date'] as String? ?? '',
      merchant: json['merchant'] as String?,
      notes: json['notes'] as String?,
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurringFrequency: json['recurring_frequency'] as String?,
      transferPairId: json['transfer_pair_id'] as String?,
      transferDirection: json['transfer_direction'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      account: json['account'] is Map<String, dynamic>
          ? Account.fromJson(json['account'] as Map<String, dynamic>)
          : null,
      category: json['category'] is Map<String, dynamic>
          ? Category.fromJson(json['category'] as Map<String, dynamic>)
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
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      fromCurrency: json['from_currency'] as String,
      toCurrency: json['to_currency'] as String,
      rate: (json['rate'] as num?)?.toDouble() ?? 1,
      updatedAt: json['updated_at'] as String? ?? '',
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

  @override
  List<Object?> get props => [category, spent, limit, ratio, status];
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
  }) {
    return TransactionFilter(
      q: q ?? this.q,
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      type: clearType ? null : (type ?? this.type),
      from: from ?? this.from,
      to: to ?? this.to,
    );
  }
}
