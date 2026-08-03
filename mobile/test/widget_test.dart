import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/core/utils/money.dart';

void main() {
  test('formatMoney returns a non-empty string', () {
    expect(formatMoney(12.5, 'USD'), isNotEmpty);
  });
}
