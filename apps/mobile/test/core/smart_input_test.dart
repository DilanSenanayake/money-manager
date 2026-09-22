import 'package:flutter_test/flutter_test.dart';

import 'package:ledgerly/core/utils/smart_input.dart';

void main() {
  group('looksLikeBankSms', () {
    test('treats short notes as text', () {
      expect(looksLikeBankSms('Coffee 450'), isFalse);
      expect(looksLikeBankSms('Salary 150000'), isFalse);
    });

    test('detects typical bank alerts', () {
      expect(
        looksLikeBankSms(
          'LKR 4,500.00 debited from A/C **4521 at CITY MARKET on 17 Sep. Avl bal 1,210.00',
        ),
        isTrue,
      );
    });
  });
}
