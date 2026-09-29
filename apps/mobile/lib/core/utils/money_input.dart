/// Decimal strings for money sent to the API. Never built with binary floating point.
String? canonicalMoney(String raw, {bool allowZero = false}) {
  var text = raw.trim().replaceAll(',', '').replaceAll(' ', '');
  if (text.startsWith('+')) text = text.substring(1);
  if (text.startsWith('.')) text = '0$text';
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) return null;
  final whole = match.group(1)!.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final frac = (match.group(2) ?? '').padRight(2, '0');
  if (!allowZero && whole == '0' && frac == '00') return null;
  return '$whole.$frac';
}

/// Exchange rates allow up to 8 decimal places.
String? canonicalRate(String raw) {
  var text = raw.trim().replaceAll(',', '').replaceAll(' ', '');
  if (text.startsWith('+')) text = text.substring(1);
  if (text.startsWith('.')) text = '0$text';
  final match = RegExp(r'^(\d+)(?:\.(\d{1,8}))?$').firstMatch(text);
  if (match == null) return null;
  final whole = match.group(1)!.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final fracRaw = match.group(2);
  if (fracRaw == null) {
    if (whole == '0') return null;
    return whole;
  }
  final frac = fracRaw.replaceFirst(RegExp(r'0+$'), '');
  if (whole == '0' && frac.isEmpty) return null;
  if (frac.isEmpty) return whole;
  return '$whole.$frac';
}
