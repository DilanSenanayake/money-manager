import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/auth_repository.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _needsUnlock = false;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final session = ref.read(authRepositoryProvider).currentSession;
    if (session == null) {
      context.go(RoutePaths.login);
      return;
    }

    final unlocked = await _authenticate();
    if (!mounted) return;
    if (!unlocked) {
      setState(() => _needsUnlock = true);
      return;
    }
    context.go(RoutePaths.home);
  }

  /// Huawei EMUI / Android 9 FingerprintManager can block the UI thread
  /// inside [LocalAuthentication.authenticate], so Dart timeouts never fire.
  /// Skip the lock on Android; keep a guarded prompt on iOS only.
  Future<bool> _authenticate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }
    try {
      final auth = LocalAuthentication();
      final supported = await auth
          .isDeviceSupported()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      if (!supported) return true;

      final enrolled = await auth
          .getAvailableBiometrics()
          .timeout(const Duration(seconds: 2), onTimeout: () => <BiometricType>[]);
      if (enrolled.isEmpty) return true;

      return await auth
          .authenticate(
            localizedReason: 'Unlock ${AppConstants.appName}',
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: false,
              useErrorDialogs: false,
            ),
          )
          .timeout(const Duration(seconds: 8), onTimeout: () => true);
    } on TimeoutException {
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _retryUnlock() async {
    setState(() => _unlocking = true);
    final unlocked = await _authenticate();
    if (!mounted) return;
    setState(() => _unlocking = false);
    if (unlocked) {
      context.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: context.isDark
                ? [
                    const Color(0xFF0F2A28),
                    scheme.surface,
                    scheme.surface,
                  ]
                : const [
                    AppColors.teal50,
                    Color(0xFFE2E8F0),
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.88, end: 1),
                  duration: AppDuration.slow + const Duration(milliseconds: 80),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: ((value - 0.88) / 0.12).clamp(0.0, 1.0),
                      child: Transform.scale(scale: value, child: child),
                    );
                  },
                  child: Image.asset(
                    'assets/icons/logo.png',
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 80),
                  child: Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeUp(
                  delay: const Duration(milliseconds: 140),
                  child: Text(
                    AppConstants.tagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (_needsUnlock) ...[
                  const Text(
                    'Unlock to continue',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Unlock',
                    loading: _unlocking,
                    onPressed: _retryUnlock,
                    icon: Icons.lock_open_rounded,
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go(RoutePaths.login);
                    },
                    child: const Text('Sign out'),
                  ),
                ] else
                  const IndeterminateBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
