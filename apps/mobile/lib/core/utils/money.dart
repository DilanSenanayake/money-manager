import 'package:intl/intl.dart';

const _currencyLocales = <String, String>{
  'USD': 'en_US',
  'EUR': 'de_DE',
  'GBP': 'en_GB',
  'LKR': 'en_LK',
  'INR': 'en_IN',
  'JPY': 'ja_JP',
  'AUD': 'en_AU',
  'CAD': 'en_CA',
  'CHF': 'de_CH',
  'SGD': 'en_SG',
};

String formatMoney(num amount, [String currency = 'USD']) {
  final locale = _currencyLocales[currency] ?? 'en_US';
  try {
    return NumberFormat.currency(
      locale: locale,
      symbol: _symbolFor(currency),
      decimalDigits: currency == 'JPY' ? 0 : 2,
    ).format(amount);
  } catch (_) {
    return '${amount.toStringAsFixed(2)} $currency';
  }
}

String _symbolFor(String currency) {
  switch (currency) {
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    case 'INR':
      return '₹';
    case 'LKR':
      return 'Rs ';
    default:
      return '$currency ';
  }
}

String budgetStatus(num spent, num limit) {
  if (limit <= 0) return 'none';
  final ratio = spent / limit;
  if (ratio >= 1) return 'over';
  if (ratio >= 0.8) return 'warn';
  return 'ok';
}
