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
    'mcdonalds',
    'kfc',
    'pizza',
    'uber eats',
    'doordash',
    'burger',
    'sushi',
    'bistro',
    'takeaway',
    'takeout',
    'eatery',
  ],
  'Groceries': [
    'grocery',
    'groceries',
    'supermarket',
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
};

const incomeAliases = <String, List<String>>{
  'Salary': ['salary', 'paycheck', 'wage', 'payroll'],
  'Freelance': ['freelance', 'contract', 'gig', 'client'],
  'Investments': ['investment', 'dividend', 'interest', 'stock'],
};

const _weakLabels = {'other', 'misc', 'general', 'unknown', 'n/a', 'na'};

String _normalize(String s) => s.toLowerCase().trim();

bool _hasWord(String haystack, String needle) {
  if (needle.isEmpty) return false;
  if (haystack == needle) return true;
  return haystack
      .split(RegExp(r'[^a-z0-9]+'))
      .where((p) => p.isNotEmpty)
      .any((p) => p == needle || (needle.length >= 5 && p.startsWith(needle)));
}

bool _isWeakLabel(String value) => _weakLabels.contains(_normalize(value));

bool _isOtherCategory(String name) => name.toLowerCase() == 'other';

/// Resolve a category id from LLM/user labels and optional merchant text.
/// "Other" never wins early — merchant aliases can still map to Dining, etc.
String? matchCategoryId(
  List<Category> categories,
  String type,
  List<String?> hints,
) {
  final pool = categories.where((c) => c.type == type).toList();
  if (pool.isEmpty) return null;

  final other =
      pool.where((c) => _isOtherCategory(c.name)).firstOrNull;

  final cleaned = hints
      .whereType<String>()
      .map(_normalize)
      .where((h) => h.isNotEmpty)
      .where((h) => !h.startsWith('from receipt:'))
      .toList();

  final joined = cleaned.join(' ');
  if (joined.isEmpty || cleaned.every(_isWeakLabel)) {
    return other?.id;
  }

  final byLength = pool
      .where((c) => !_isOtherCategory(c.name))
      .toList()
    ..sort((a, b) => b.name.length.compareTo(a.name.length));

  for (final hint in cleaned) {
    if (_isWeakLabel(hint)) continue;
    for (final c in byLength) {
      final name = c.name.toLowerCase();
      if (hint == name || _hasWord(hint, name)) {
        return c.id;
      }
    }
  }

  for (final c in byLength) {
    final name = c.name.toLowerCase();
    if (joined == name || _hasWord(joined, name)) {
      return c.id;
    }
  }

  final aliases = type == 'expense' ? expenseAliases : incomeAliases;
  final ranked = <({String canonical, String word})>[
    for (final entry in aliases.entries)
      for (final word in entry.value) (canonical: entry.key, word: word),
  ]..sort((a, b) => b.word.length.compareTo(a.word.length));

  for (final item in ranked) {
    final matched = item.word.contains(' ')
        ? joined.contains(item.word)
        : _hasWord(joined, item.word);
    if (!matched) continue;
    final found = pool
        .where((c) => c.name.toLowerCase() == item.canonical.toLowerCase())
        .firstOrNull;
    if (found != null) return found.id;
  }

  final tokens = joined
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.length > 2)
      .toList();
  for (final c in byLength) {
    final name = c.name.toLowerCase();
    if (tokens.any(
      (t) => name == t || (t.length >= 4 && (name.contains(t) || t.contains(name))),
    )) {
      return c.id;
    }
  }

  return other?.id ?? pool.last.id;
}
