import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/core/utils/money_input.dart';

void main() {
  test('canonical money keeps two decimal places from text', () {
    expect(canonicalMoney('10.10'), '10.10');
    expect(canonicalMoney('10'), '10.00');
    expect(canonicalMoney('0.5'), '0.50');
    expect(canonicalMoney('1,250.5'), '1250.50');
    expect(canonicalMoney('0'), isNull);
    expect(canonicalMoney('0', allowZero: true), '0.00');
    expect(canonicalMoney('10.999'), isNull);
  });

  test('canonical rate keeps significant decimals', () {
    expect(canonicalRate('1.2500'), '1.25');
    expect(canonicalRate('0.00000001'), '0.00000001');
    expect(canonicalRate('0'), isNull);
  });
}
