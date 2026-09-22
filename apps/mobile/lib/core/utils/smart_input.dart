/// Heuristic: long bank-style alerts vs short “Coffee 450” notes.
/// User can still correct on the review sheet.
bool looksLikeBankSms(String text) {
  final value = text.trim();
  if (value.length < 48) return false;

  final signals = <RegExp>[
    RegExp(r'debited|credited|withdrawn|deposited', caseSensitive: false),
    RegExp(r'\ba\/c\b|\bacct\b|\baccount\b', caseSensitive: false),
    RegExp(r'avl\.?\s*bal|available balance|bal\.?\s*:', caseSensitive: false),
    RegExp(r'\b(upi|neft|imps|rtgs|pos)\b', caseSensitive: false),
    RegExp(r'\b(txn|transaction|ref\.?\s*no)\b', caseSensitive: false),
    RegExp(r'\b(rs\.?|lkr|inr|usd)\s*[\d,]', caseSensitive: false),
    RegExp(r'\*{2,}\d{2,}'),
  ];

  var hits = 0;
  for (final re in signals) {
    if (re.hasMatch(value)) hits += 1;
  }
  return hits >= 2 || (value.length >= 120 && hits >= 1);
}
