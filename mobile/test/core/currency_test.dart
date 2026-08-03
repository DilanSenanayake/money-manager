import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/core/utils/currency.dart';
import 'package:ledgerly/shared/models/models.dart';

void main() {
  group('convertToBase', () {
    test('same currency returns amount', () {
      expect(convertToBase(100, 'USD', 'USD', const []), 100);
    });

    test('uses direct rate', () {
      final rates = [
        const ExchangeRate(
          id: '1',
          userId: 'u',
          fromCurrency: 'USD',
          toCurrency: 'LKR',
          rate: 300,
        ),
      ];
      expect(convertToBase(2, 'USD', 'LKR', rates), 600);
    });

    test('uses inverse rate', () {
      // Rate stored as LKR → USD = 1/300; converting USD → LKR uses amount / rate.
      final rates = [
        const ExchangeRate(
          id: '1',
          userId: 'u',
          fromCurrency: 'LKR',
          toCurrency: 'USD',
          rate: 1 / 300,
        ),
      ];
      expect(convertToBase(2, 'USD', 'LKR', rates), closeTo(600, 0.001));
    });
  });

  group('computeNetWorth', () {
    test('subtracts credit balances', () {
      final accounts = [
        const Account(
          id: 'a',
          userId: 'u',
          name: 'Cash',
          type: 'cash',
          balance: 1000,
          currency: 'USD',
        ),
        const Account(
          id: 'b',
          userId: 'u',
          name: 'Card',
          type: 'credit',
          balance: 200,
          currency: 'USD',
        ),
      ];
      expect(computeNetWorth(accounts, 'USD', const []), 800);
    });
  });
}
