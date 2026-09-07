import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/core/utils/category_match.dart';
import 'package:ledgerly/shared/models/models.dart';

void main() {
  final categories = [
    const Category(
      id: 'dining',
      userId: 'u',
      name: 'Dining',
      icon: 'utensils',
      type: 'expense',
    ),
    const Category(
      id: 'other',
      userId: 'u',
      name: 'Other',
      icon: 'circle',
      type: 'expense',
    ),
    const Category(
      id: 'salary',
      userId: 'u',
      name: 'Salary',
      icon: 'wallet',
      type: 'income',
    ),
  ];

  test('matches alias keywords', () {
    expect(
      matchCategoryId(categories, 'expense', ['Starbucks coffee']),
      'dining',
    );
  });

  test('Other label does not block merchant dining aliases', () {
    expect(
      matchCategoryId(categories, 'expense', ['Other', 'Starbucks']),
      'dining',
    );
  });

  test('falls back to Other', () {
    expect(
      matchCategoryId(categories, 'expense', ['zzzz unknown']),
      'other',
    );
  });

  test('matches income aliases', () {
    expect(
      matchCategoryId(categories, 'income', ['monthly paycheck']),
      'salary',
    );
  });
}
