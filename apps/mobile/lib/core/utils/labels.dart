import 'package:flutter/material.dart';

String labelForAccountType(String type) {
  switch (type) {
    case 'cash':
      return 'Cash';
    case 'checking':
      return 'Checking';
    case 'savings':
      return 'Savings';
    case 'credit':
      return 'Credit card';
    default:
      return type;
  }
}

String labelForTxType(String type) {
  switch (type) {
    case 'expense':
      return 'Expense';
    case 'income':
      return 'Income';
    case 'transfer':
      return 'Transfer';
    default:
      return type;
  }
}

IconData iconForAccountType(String type) {
  switch (type) {
    case 'credit':
      return Icons.credit_card_rounded;
    case 'savings':
      return Icons.savings_outlined;
    case 'checking':
      return Icons.account_balance_outlined;
    default:
      return Icons.payments_outlined;
  }
}
