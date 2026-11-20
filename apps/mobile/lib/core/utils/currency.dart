import 'package:intl/intl.dart';

import '../../shared/models/models.dart';

String appliedRateLabel(ExchangeRate rate) {
  final parsed = DateTime.tryParse(rate.updatedAt);
  final when = parsed == null
      ? ''
      : ', entered ${DateFormat('d MMM y').format(parsed.toLocal())}';
  return 'Using your rate 1 ${rate.fromCurrency} = ${rate.rate} ${rate.toCurrency}$when.';
}

double? convertToBase(
  num amount,
  String fromCurrency,
  String baseCurrency,
  List<ExchangeRate> rates,
) {
  if (fromCurrency == baseCurrency) return amount.toDouble();

  final direct = rates.where(
    (r) => r.fromCurrency == fromCurrency && r.toCurrency == baseCurrency,
  );
  if (direct.isNotEmpty) {
    return amount.toDouble() * direct.first.rate;
  }

  final inverse = rates.where(
    (r) => r.fromCurrency == baseCurrency && r.toCurrency == fromCurrency,
  );
  if (inverse.isNotEmpty && inverse.first.rate != 0) {
    return amount.toDouble() / inverse.first.rate;
  }

  return null;
}

List<ExchangeRate> ratesCovering(
  Iterable<String> currencies,
  String baseCurrency,
  List<ExchangeRate> rates,
) {
  final used = <ExchangeRate>[];
  for (final currency in currencies.toSet()) {
    if (currency.isEmpty || currency == baseCurrency) continue;
    final direct = rates.where(
      (r) => r.fromCurrency == currency && r.toCurrency == baseCurrency,
    );
    if (direct.isNotEmpty) {
      used.add(direct.first);
      continue;
    }
    final inverse = rates.where(
      (r) =>
          r.fromCurrency == baseCurrency &&
          r.toCurrency == currency &&
          r.rate != 0,
    );
    if (inverse.isNotEmpty) used.add(inverse.first);
  }
  return used;
}

Map<String, String> accountCurrencyMap(List<Account> accounts) {
  return {for (final a in accounts) a.id: a.currency};
}

double? txAmountInBase(
  num amount,
  String accountId,
  Map<String, String> currencyByAccount,
  String baseCurrency,
  List<ExchangeRate> rates,
) {
  final from = currencyByAccount[accountId] ?? baseCurrency;
  return convertToBase(amount, from, baseCurrency, rates);
}

double? computeNetWorth(
  List<Account> accounts,
  String baseCurrency,
  List<ExchangeRate> rates,
) {
  var sum = 0.0;
  for (final account in accounts) {
    final converted = convertToBase(
      account.balance,
      account.currency,
      baseCurrency,
      rates,
    );
    if (converted == null) return null;
    sum += account.type == 'credit' ? -converted : converted;
  }
  return sum;
}

bool hasMissingExchangeRate(
  List<Account> accounts,
  String baseCurrency,
  List<ExchangeRate> rates,
) {
  for (final account in accounts) {
    if (account.currency == baseCurrency) continue;
    final hasDirect = rates.any(
      (r) =>
          r.fromCurrency == account.currency &&
          r.toCurrency == baseCurrency,
    );
    final hasInverse = rates.any(
      (r) =>
          r.fromCurrency == baseCurrency &&
          r.toCurrency == account.currency,
    );
    if (!hasDirect && !hasInverse) return true;
  }
  return false;
}
