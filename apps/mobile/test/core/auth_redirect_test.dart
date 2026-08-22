import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/core/constants/app_constants.dart';
import 'package:ledgerly/core/router/auth_redirect.dart';

void main() {
  test('splash never redirects', () {
    expect(
      authRedirect(loggedIn: false, location: RoutePaths.splash),
      isNull,
    );
    expect(
      authRedirect(loggedIn: true, location: RoutePaths.splash),
      isNull,
    );
  });

  test('guests are sent to login for protected routes', () {
    expect(
      authRedirect(loggedIn: false, location: RoutePaths.home),
      RoutePaths.login,
    );
  });

  test('signed-in users leave auth screens', () {
    expect(
      authRedirect(loggedIn: true, location: RoutePaths.login),
      RoutePaths.home,
    );
    expect(
      authRedirect(loggedIn: true, location: RoutePaths.signup),
      RoutePaths.home,
    );
  });

  test('valid locations stay put', () {
    expect(
      authRedirect(loggedIn: true, location: RoutePaths.activity),
      isNull,
    );
    expect(
      authRedirect(loggedIn: false, location: RoutePaths.login),
      isNull,
    );
  });
}
