String localDateYYYYMMDD([DateTime? date]) {
  final d = date ?? DateTime.now();
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String localMonthStartYYYYMMDD([DateTime? date]) {
  final d = date ?? DateTime.now();
  return localDateYYYYMMDD(DateTime(d.year, d.month, 1));
}

String localMonthEndYYYYMMDD([DateTime? date]) {
  final d = date ?? DateTime.now();
  return localDateYYYYMMDD(DateTime(d.year, d.month + 1, 0));
}

DateTime? parseLocalDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String addFrequency(String date, String frequency) {
  final d = parseLocalDate(date) ?? DateTime.now();
  switch (frequency) {
    case 'weekly':
      return localDateYYYYMMDD(d.add(const Duration(days: 7)));
    case 'yearly':
      return localDateYYYYMMDD(DateTime(d.year + 1, d.month, d.day));
    case 'monthly':
    default:
      final nextMonth = DateTime(d.year, d.month + 1, d.day);
      // Clamp overflow (e.g. Jan 31 -> Feb)
      if (nextMonth.month != ((d.month % 12) + 1) && d.month != 12) {
        return localDateYYYYMMDD(DateTime(d.year, d.month + 2, 0));
      }
      return localDateYYYYMMDD(nextMonth);
  }
}
