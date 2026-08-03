import '../../shared/models/models.dart';

double convertToBase(
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

  return amount.toDouble();
}

Map<String, String> accountCurrencyMap(List<Account> accounts) {
  return {for (final a in accounts) a.id: a.currency};
}

double txAmountInBase(
  num amount,
  String accountId,
  Map<String, String> currencyByAccount,
  String baseCurrency,
  List<ExchangeRate> rates,
) {
  final from = currencyByAccount[accountId] ?? baseCurrency;
  return convertToBase(amount, from, baseCurrency, rates);
}

double computeNetWorth(
  List<Account> accounts,
  String baseCurrency,
  List<ExchangeRate> rates,
) {
  return accounts.fold<double>(0, (sum, account) {
    final converted = convertToBase(
      account.balance,
      account.currency,
      baseCurrency,
      rates,
    );
    if (account.type == 'credit') {
      return sum - converted;
    }
    return sum + converted;
  });
}
