import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final authed = ref.read(isAuthenticatedProvider);
    if (!authed) {
      context.go(RoutePaths.login);
      return;
    }

    // Optional biometric gate when a session already exists.
    // Failure/cancel still continues — session remains valid.
    try {
      final auth = LocalAuthentication();
      final canCheck =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (canCheck) {
        await auth.authenticate(
          localizedReason: 'Unlock Ledgerly',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );
      }
    } catch (_) {
      // Biometrics unavailable — continue with session.
    }

    if (mounted) context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.teal50, Color(0xFFE2E8F0), Colors.white],
          ),
        ),
        child: const SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ledgerly',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: AppColors.teal700,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Money, logged in seconds',
                style: TextStyle(color: AppColors.slate),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
