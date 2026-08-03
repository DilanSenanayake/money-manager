import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/core/utils/money.dart';

void main() {
  test('budgetStatus thresholds', () {
    expect(budgetStatus(50, 100), 'ok');
    expect(budgetStatus(80, 100), 'warn');
    expect(budgetStatus(100, 100), 'over');
    expect(budgetStatus(10, 0), 'none');
  });
}
