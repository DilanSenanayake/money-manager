const _known = {
  'USD',
  'EUR',
  'GBP',
  'LKR',
  'INR',
  'JPY',
  'AUD',
  'CAD',
  'CHF',
  'SGD',
};

final _totalLine = RegExp(
  r'\b(grand\s+total|amount\s+due|balance\s+due|total\s+due|net\s+amount|amount\s+paid|total|to\s+pay|nett)\b',
  caseSensitive: false,
);

final _token = RegExp(
  r'(?<![A-Za-z])(?:sri\s+lankan?\s+rupees?|indian\s+rupees?|us\s+dollars?|australian\s+dollars?|canadian\s+dollars?|singapore\s+dollars?|swiss\s+francs?|british\s+pounds?|pound\s+sterling|japanese\s+yen)(?![A-Za-z])|US\$|(?<![A-Za-z])USD(?![A-Za-z])|(?<![A-Za-z])DOLLARS?(?![A-Za-z])|A\$|(?<![A-Za-z])AUD(?![A-Za-z])|C\$|(?<![A-Za-z])CAD(?![A-Za-z])|S\$|(?<![A-Za-z])SGD(?![A-Za-z])|€|(?<![A-Za-z])EUR(?:O(?:S)?|S)?(?![A-Za-z])|£|(?<![A-Za-z])GBP(?![A-Za-z])|(?<![A-Za-z])POUNDS?(?![A-Za-z])|(?<![A-Za-z])STERLING(?![A-Za-z])|¥|￥|(?<![A-Za-z])JPY(?![A-Za-z])|(?<![A-Za-z])YEN(?![A-Za-z])|(?<![A-Za-z])CHF(?![A-Za-z])|(?<![A-Za-z])FRANCS?(?![A-Za-z])|(?<![A-Za-z])LKR(?![A-Za-z])|(?<![A-Za-z])SLR(?![A-Za-z])|රු\.?|₹|(?<![A-Za-z])INR(?![A-Za-z])|(?<![A-Za-z])Rs\.?(?![A-Za-z])|(?<![A-Za-z])Rupees?(?![A-Za-z])|(?<![A-Za-z])\$(?=\s*\d)',
  caseSensitive: false,
);

class _Hit {
  const _Hit({
    required this.code,
    required this.onTotal,
    required this.inParentheses,
    required this.explicit,
  });

  final String code;
  final bool onTotal;
  final bool inParentheses;
  final bool explicit;
}

String _knownCode(String? currency) {
  final code = (currency ?? '').trim().toUpperCase();
  return _known.contains(code) ? code : '';
}

String _normalize(String token) {
  var value = token.trim();
  if (value.endsWith('.')) value = value.substring(0, value.length - 1);
  return value.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
}

bool _explicit(String token) {
  final value = _normalize(token);
  return value != 'RS' && value != 'RUPEE' && value != 'RUPEES' && value != r'$';
}

String? _codeFor(String token) {
  switch (_normalize(token)) {
    case 'US\$':
    case 'USD':
    case 'US DOLLAR':
    case 'US DOLLARS':
    case 'DOLLAR':
    case 'DOLLARS':
    case r'$':
      return 'USD';
    case 'A\$':
    case 'AUD':
    case 'AUSTRALIAN DOLLAR':
    case 'AUSTRALIAN DOLLARS':
      return 'AUD';
    case 'C\$':
    case 'CAD':
    case 'CANADIAN DOLLAR':
    case 'CANADIAN DOLLARS':
      return 'CAD';
    case 'S\$':
    case 'SGD':
    case 'SINGAPORE DOLLAR':
    case 'SINGAPORE DOLLARS':
      return 'SGD';
    case '€':
    case 'EUR':
    case 'EURO':
    case 'EUROS':
      return 'EUR';
    case '£':
    case 'GBP':
    case 'POUND':
    case 'POUNDS':
    case 'STERLING':
    case 'BRITISH POUND':
    case 'BRITISH POUNDS':
    case 'POUND STERLING':
      return 'GBP';
    case '¥':
    case '￥':
    case 'JPY':
    case 'YEN':
    case 'JAPANESE YEN':
      return 'JPY';
    case 'CHF':
    case 'FRANC':
    case 'FRANCS':
    case 'SWISS FRANC':
    case 'SWISS FRANCS':
      return 'CHF';
    case 'LKR':
    case 'SLR':
    case 'රු':
    case 'SRI LANKA RUPEE':
    case 'SRI LANKA RUPEES':
    case 'SRI LANKAN RUPEE':
    case 'SRI LANKAN RUPEES':
    case 'RS':
    case 'RUPEE':
    case 'RUPEES':
      return 'LKR';
    case '₹':
    case 'INR':
    case 'INDIAN RUPEE':
    case 'INDIAN RUPEES':
      return 'INR';
    default:
      return null;
  }
}

bool _inParentheses(String line, int index) {
  final open = line.lastIndexOf('(', index);
  if (open < 0) return false;
  final close = line.indexOf(')', index);
  return close > index;
}

List<_Hit> _collect(String? ocrText) {
  if (ocrText == null || ocrText.trim().isEmpty) return const [];
  final hits = <_Hit>[];
  for (final rawLine in ocrText.replaceAll('\u00A0', ' ').split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final onTotal = _totalLine.hasMatch(line);
    for (final match in _token.allMatches(line)) {
      final code = _codeFor(match.group(0)!);
      if (code == null) continue;
      hits.add(
        _Hit(
          code: code,
          onTotal: onTotal,
          inParentheses: _inParentheses(line, match.start),
          explicit: _explicit(match.group(0)!),
        ),
      );
    }
  }
  return hits;
}

List<String> _distinct(Iterable<_Hit> hits) {
  final codes = <String>[];
  for (final hit in hits) {
    if (!codes.contains(hit.code)) codes.add(hit.code);
  }
  return codes;
}

String? _one(Iterable<_Hit> hits) {
  final codes = _distinct(hits);
  return codes.length == 1 ? codes.first : null;
}

/// Currency printed on the receipt, or null when it is ambiguous.
String? detectReceiptCurrency(String? ocrText) {
  final hits = _collect(ocrText);
  if (hits.isEmpty) return null;
  final explicitInr = hits.any((h) => h.code == 'INR' && h.explicit);
  final explicitLkr = hits.any((h) => h.code == 'LKR' && h.explicit);
  final filtered = hits.where((h) {
    if (explicitInr && h.code == 'LKR' && !h.explicit) return false;
    if (explicitLkr && h.code == 'INR' && !h.explicit) return false;
    return true;
  }).toList();
  return _one(filtered.where((h) => h.onTotal && !h.inParentheses)) ??
      _one(filtered.where((h) => !h.inParentheses)) ??
      _one(filtered.where((h) => h.onTotal)) ??
      _one(filtered);
}

List<_Hit> _filtered(String? ocrText) {
  final hits = _collect(ocrText);
  final explicitInr = hits.any((h) => h.code == 'INR' && h.explicit);
  final explicitLkr = hits.any((h) => h.code == 'LKR' && h.explicit);
  return hits.where((h) {
    if (explicitInr && h.code == 'LKR' && !h.explicit) return false;
    if (explicitLkr && h.code == 'INR' && !h.explicit) return false;
    return true;
  }).toList();
}

bool _explicitOnTotal(List<_Hit> hits, String code) {
  if (code.isEmpty) return false;
  return hits.any(
    (h) => h.onTotal && !h.inParentheses && h.explicit && h.code == code,
  );
}

String? _singleExplicit(Iterable<_Hit> hits) {
  final codes = <String>[];
  for (final hit in hits) {
    if (hit.inParentheses || !hit.explicit) continue;
    if (!codes.contains(hit.code)) codes.add(hit.code);
  }
  return codes.length == 1 ? codes.first : null;
}

/// Printed currency of the total, compared with the selected account currency.
String resolveReceiptCurrency({
  required String? modelCurrency,
  required String? ocrText,
  required String targetCurrency,
}) {
  final model = _knownCode(modelCurrency);
  final target = _knownCode(targetCurrency);
  final hits = _filtered(ocrText);

  if (_explicitOnTotal(hits, target)) {
    final foreignOnTotal = _singleExplicit(
      hits.where((h) => h.onTotal && h.code != target),
    );
    return foreignOnTotal ?? target;
  }

  final foreign = _singleExplicit(hits.where((h) => h.code != target));
  if (foreign != null) return foreign;
  if (model.isNotEmpty && model != target) return model;

  final detected = detectReceiptCurrency(ocrText);
  if (detected != null) return detected;
  if (model.isNotEmpty) return model;
  return target.isNotEmpty ? target : 'USD';
}
