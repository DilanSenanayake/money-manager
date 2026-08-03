import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/accounts_page.dart';
import '../../features/analytics/presentation/analytics_page.dart';
import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/presentation/login_page.dart';
import '../../features/authentication/presentation/signup_page.dart';
import '../../features/authentication/presentation/splash_page.dart';
import '../../features/budgets/presentation/budgets_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/more/presentation/more_page.dart';
import '../../features/more/presentation/shell_page.dart';
import '../../features/quick_add/presentation/quick_add_page.dart';
import '../../features/recurring/presentation/recurring_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/transactions/presentation/transactions_page.dart';
import '../constants/app_constants.dart';
import 'auth_redirect.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class GoRouterRefresh extends ChangeNotifier {
  GoRouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

final goRouterRefreshProvider = Provider<GoRouterRefresh>((ref) {
  final refresh = GoRouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(goRouterRefreshProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RoutePaths.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      return authRedirect(
        loggedIn: ref.read(isAuthenticatedProvider),
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: RoutePaths.signup,
        builder: (_, __) => const SignupPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellPage(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (_, __) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.activity,
                builder: (_, __) => const TransactionsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.add,
                builder: (_, __) => const QuickAddPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.more,
                builder: (_, __) => const MorePage(),
                routes: [
                  GoRoute(
                    path: 'accounts',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, __) => const AccountsPage(),
                  ),
                  GoRoute(
                    path: 'budgets',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, __) => const BudgetsPage(),
                  ),
                  GoRoute(
                    path: 'analytics',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, __) => const AnalyticsPage(),
                  ),
                  GoRoute(
                    path: 'recurring',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, __) => const RecurringPage(),
                  ),
                  GoRoute(
                    path: 'settings',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, __) => const SettingsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Absolute convenience routes (deep links / More hub)
      GoRoute(
        path: RoutePaths.accounts,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const AccountsPage(),
      ),
      GoRoute(
        path: RoutePaths.budgets,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const BudgetsPage(),
      ),
      GoRoute(
        path: RoutePaths.analytics,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const AnalyticsPage(),
      ),
      GoRoute(
        path: RoutePaths.recurring,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const RecurringPage(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SettingsPage(),
      ),
    ],
  );
});
