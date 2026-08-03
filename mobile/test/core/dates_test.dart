import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/core/utils/dates.dart';

void main() {
  test('localDateYYYYMMDD formats local calendar date', () {
    expect(localDateYYYYMMDD(DateTime(2026, 8, 4)), '2026-08-04');
  });

  test('month bounds', () {
    final d = DateTime(2026, 2, 15);
    expect(localMonthStartYYYYMMDD(d), '2026-02-01');
    expect(localMonthEndYYYYMMDD(d), '2026-02-28');
  });

  test('addFrequency monthly', () {
    expect(addFrequency('2026-01-15', 'monthly'), '2026-02-15');
  });
}
