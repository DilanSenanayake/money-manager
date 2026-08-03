import '../../shared/models/models.dart';

const expenseAliases = <String, List<String>>{
  'Dining': [
    'dining',
    'restaurant',
    'cafe',
    'coffee',
    'starbucks',
    'food',
    'lunch',
    'dinner',
    'breakfast',
    'mcdonald',
    'kfc',
    'pizza',
    'uber eats',
    'doordash',
  ],
  'Groceries': [
    'grocery',
    'groceries',
    'supermarket',
    'market',
    'walmart',
    'costco',
    'whole foods',
    'trader joe',
  ],
  'Transport': [
    'transport',
    'uber',
    'lyft',
    'taxi',
    'fuel',
    'gas',
    'petrol',
    'parking',
    'metro',
    'bus',
    'train',
    'grab',
  ],
  'Shopping': [
    'shopping',
    'amazon',
    'mall',
    'clothing',
    'apparel',
    'store',
    'retail',
  ],
  'Utilities': [
    'utility',
    'utilities',
    'electric',
    'water',
    'internet',
    'wifi',
    'phone',
    'bill',
    'gas bill',
  ],
  'Health': [
    'health',
    'pharmacy',
    'medical',
    'doctor',
    'hospital',
    'dental',
    'clinic',
  ],
  'Entertainment': [
    'entertainment',
    'movie',
    'netflix',
    'spotify',
    'game',
    'cinema',
    'concert',
  ],
  'Rent': ['rent', 'mortgage', 'housing', 'lease'],
  'Other': ['other', 'misc', 'general'],
};

const incomeAliases = <String, List<String>>{
  'Salary': ['salary', 'paycheck', 'wage', 'payroll'],
  'Freelance': ['freelance', 'contract', 'gig', 'client'],
  'Investments': ['investment', 'dividend', 'interest', 'stock'],
};

String _normalize(String s) => s.toLowerCase().trim();

/// Resolve a category id from LLM/user labels and optional merchant text.
String? matchCategoryId(
  List<Category> categories,
  String type,
  List<String?> hints,
) {
  final pool = categories.where((c) => c.type == type).toList();
  if (pool.isEmpty) return null;

  final joined = hints
      .whereType<String>()
      .map(_normalize)
      .where((h) => h.isNotEmpty)
      .join(' ');

  if (joined.isEmpty) {
    return pool.where((c) => c.name.toLowerCase() == 'other').firstOrNull?.id;
  }

  for (final c in pool) {
    final name = c.name.toLowerCase();
    if (joined == name || joined.contains(name) || name.contains(joined)) {
      return c.id;
    }
  }

  final aliases = type == 'expense' ? expenseAliases : incomeAliases;
  for (final entry in aliases.entries) {
    if (entry.value.any(joined.contains)) {
      final found = pool
          .where((c) => c.name.toLowerCase() == entry.key.toLowerCase())
          .firstOrNull;
      if (found != null) return found.id;
    }
  }

  final tokens = joined
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.length > 2)
      .toList();
  for (final c in pool) {
    final name = c.name.toLowerCase();
    if (tokens.any((t) => name.contains(t) || t.contains(name))) {
      return c.id;
    }
  }

  return pool.where((c) => c.name.toLowerCase() == 'other').firstOrNull?.id ??
      pool.last.id;
}
