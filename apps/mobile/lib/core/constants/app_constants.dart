class AppConstants {
  static const appName = 'Smart Money Manager';
  static const tagline = 'Spend smarter. Save better. Live better.';
  static const minPasswordLength = 8;
  static const maxReceiptBytes = 8 * 1024 * 1024;
  static const currencies = [
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
  ];

  static const accountTypes = ['cash', 'checking', 'savings', 'credit'];
  static const transactionLimit = 200;
  static const recentTransactionLimit = 8;
}

class RoutePaths {
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const activity = '/activity';
  static const add = '/add';
  static const more = '/more';
  static const accounts = '/accounts';
  static const budgets = '/budgets';
  static const analytics = '/analytics';
  static const recurring = '/recurring';
  static const settings = '/settings';
}
