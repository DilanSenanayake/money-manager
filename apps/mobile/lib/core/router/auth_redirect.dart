import '../constants/app_constants.dart';

/// Pure redirect helper used by go_router (and unit tests).
String? authRedirect({
  required bool loggedIn,
  required String location,
}) {
  final isAuthRoute =
      location == RoutePaths.login || location == RoutePaths.signup;
  final isSplash = location == RoutePaths.splash;

  if (isSplash) return null;
  if (!loggedIn && !isAuthRoute) return RoutePaths.login;
  if (loggedIn && isAuthRoute) return RoutePaths.home;
  return null;
}
