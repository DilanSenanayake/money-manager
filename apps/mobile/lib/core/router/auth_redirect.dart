import '../constants/app_constants.dart';

/// Pure redirect helper used by go_router (and unit tests).
String? authRedirect({
  required bool loggedIn,
  required String location,
  bool consentAccepted = true,
}) {
  final isAuthRoute =
      location == RoutePaths.login || location == RoutePaths.signup;
  final isSplash = location == RoutePaths.splash;
  final isConsent = location == RoutePaths.consent;
  final isLegal = location.startsWith('/legal/');

  if (!consentAccepted) {
    if (isConsent || isLegal || isSplash) return null;
    return RoutePaths.consent;
  }

  if (isConsent) return loggedIn ? RoutePaths.home : RoutePaths.login;
  if (isSplash) return null;
  if (!loggedIn && !isAuthRoute && !isLegal) return RoutePaths.login;
  if (loggedIn && isAuthRoute) return RoutePaths.home;
  return null;
}
