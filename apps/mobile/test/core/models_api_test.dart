import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/core/error/exception_mapper.dart';
import 'package:ledgerly/core/error/failures.dart';
import 'package:ledgerly/shared/models/models.dart';

void main() {
  group('DashboardData.fromJson', () {
    test('reads mixed camelCase and snake_case keys', () {
      final data = DashboardData.fromJson({
        'profile': {
          'id': 'user-1',
          'base_currency': 'LKR',
          'display_name': 'Dilan',
        },
        'accounts': [
          {
            'id': 'acc-1',
            'user_id': 'user-1',
            'name': 'Cash',
            'type': 'cash',
            'balance': 1200.5,
            'currency': 'LKR',
          },
        ],
        'rates': [],
        'netWorth': 1200.5,
        'income': 10,
        'expense': 4,
        'budgets': [
          {
            'category': {
              'id': 'cat-1',
              'user_id': 'user-1',
              'name': 'Dining',
              'icon': 'utensils',
              'type': 'expense',
              'monthly_budget': 200,
            },
            'spent': 80,
            'limit': 200,
            'ratio': 0.4,
            'status': 'ok',
          },
        ],
        'recent': [],
        'baseCurrency': 'LKR',
        'monthStart': '2026-09-01',
        'monthEnd': '2026-09-30',
      });

      expect(data.baseCurrency, 'LKR');
      expect(data.netWorth, 1200.5);
      expect(data.profile?.displayName, 'Dilan');
      expect(data.accounts.single.name, 'Cash');
      expect(data.budgets.single.status, 'ok');
    });
  });

  group('AI models', () {
    test('SMS credit maps to income', () {
      final sms = SmsExtraction.fromJson({
        'amount': 5000,
        'type': 'Credit',
        'merchant': 'Payroll',
        'date': '2026-09-18',
      });
      expect(sms.isIncome, isTrue);
      expect(sms.amount, 5000);
    });

    test('receipt envelope parser', () {
      final receipt = parseDataEnvelope(
        {
          'data': {
            'merchant': 'Cafe',
            'amount': 450,
            'currency': 'LKR',
            'date': '2026-09-18',
            'category': 'Dining',
            'line_items': [
              {'name': 'Latte', 'quantity': 1, 'price': 450},
            ],
          },
        },
        ReceiptExtraction.fromJson,
      );
      expect(receipt.merchant, 'Cafe');
      expect(receipt.lineItems.single.name, 'Latte');
    });
  });

  group('mapHttpError', () {
    test('maps 401 to AuthFailure', () {
      expect(
        mapHttpError(status: 401, data: {'error': 'Unauthorized'}),
        isA<AuthFailure>(),
      );
    });

    test('maps 429 to RateLimitFailure', () {
      expect(mapHttpError(status: 429, data: null), isA<RateLimitFailure>());
    });

    test('maps 400 error string to ValidationFailure', () {
      final failure = mapHttpError(
        status: 400,
        data: {'error': 'Amount must be positive'},
      );
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Amount must be positive');
    });

    test('maps 500 to ServerFailure', () {
      expect(mapHttpError(status: 500, data: null), isA<ServerFailure>());
    });
  });

  test('TransactionInput serializes API fields', () {
    const input = TransactionInput(
      accountId: 'a',
      amount: 12.5,
      type: 'expense',
      date: '2026-09-18',
      merchant: 'Cafe',
    );
    expect(input.toJson()['account_id'], 'a');
    expect(input.toJson()['amount'], 12.5);
    expect(input.toJson()['is_recurring'], isFalse);
  });
}
