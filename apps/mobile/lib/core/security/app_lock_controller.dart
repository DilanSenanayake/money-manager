import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'app_secure_store.dart';

class AppLockSnapshot {
  const AppLockSnapshot({
    this.ready = false,
    this.enabled = false,
    this.biometric = false,
    this.locked = false,
    this.error,
  });

  final bool ready;
  final bool enabled;
  final bool biometric;
  final bool locked;
  final String? error;

  AppLockSnapshot copyWith({
    bool? ready,
    bool? enabled,
    bool? biometric,
    bool? locked,
    String? error,
    bool clearError = false,
  }) {
    return AppLockSnapshot(
      ready: ready ?? this.ready,
      enabled: enabled ?? this.enabled,
      biometric: biometric ?? this.biometric,
      locked: locked ?? this.locked,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AppLockController extends Notifier<AppLockSnapshot> {
  static const _enabledKey = 'app_lock_enabled';
  static const _pinKey = 'app_lock_pin';
  static const _biometricKey = 'app_lock_biometric';

  DateTime? _suppressUntil;
  bool _armOnResume = false;

  @override
  AppLockSnapshot build() => const AppLockSnapshot();

  Future<void> load() async {
    try {
      final enabled = await AppSecureStore.read(_enabledKey) == '1';
      final biometric = await AppSecureStore.read(_biometricKey) == '1';
      state = AppLockSnapshot(
        ready: true,
        enabled: enabled,
        biometric: biometric,
        locked: enabled,
      );
    } catch (_) {
      state = const AppLockSnapshot(
        ready: true,
        enabled: true,
        locked: true,
        error: 'App lock could not be read. Enter your PIN, or sign out.',
      );
    }
  }

  /// Camera, gallery, and speech leave the app briefly. Do not lock for that.
  void suppressFor(Duration duration) {
    final until = DateTime.now().add(duration);
    if (_suppressUntil == null || until.isAfter(_suppressUntil!)) {
      _suppressUntil = until;
    }
  }

  bool get _suppressed =>
      _suppressUntil != null && DateTime.now().isBefore(_suppressUntil!);

  void onPause() {
    if (!state.enabled || _suppressed) return;
    _armOnResume = true;
  }

  void onResume() {
    if (!_armOnResume) return;
    _armOnResume = false;
    if (!state.enabled || _suppressed) return;
    state = state.copyWith(locked: true, clearError: true);
  }

  Future<String?> enable({
    required String pin,
    required bool biometric,
  }) async {
    final error = validatePin(pin);
    if (error != null) return error;
    await AppSecureStore.write(_pinKey, pin);
    await AppSecureStore.write(_enabledKey, '1');
    await AppSecureStore.write(_biometricKey, biometric ? '1' : '0');
    state = state.copyWith(
      ready: true,
      enabled: true,
      biometric: biometric,
      locked: false,
      clearError: true,
    );
    return null;
  }

  Future<String?> changePin({
    required String current,
    required String next,
  }) async {
    if (!await _pinMatches(current)) return 'Current PIN is incorrect';
    final error = validatePin(next);
    if (error != null) return error;
    await AppSecureStore.write(_pinKey, next);
    return null;
  }

  Future<String?> setBiometric(bool enabled, String pin) async {
    if (!await _pinMatches(pin)) return 'PIN is incorrect';
    await AppSecureStore.write(_biometricKey, enabled ? '1' : '0');
    state = state.copyWith(biometric: enabled);
    return null;
  }

  Future<String?> disable(String pin) async {
    if (!await _pinMatches(pin)) return 'PIN is incorrect';
    await clear();
    return null;
  }

  Future<void> clear() async {
    await AppSecureStore.delete(_pinKey);
    await AppSecureStore.delete(_enabledKey);
    await AppSecureStore.delete(_biometricKey);
    state = const AppLockSnapshot(ready: true);
  }

  Future<bool> unlockWithPin(String pin) async {
    if (!await _pinMatches(pin)) return false;
    state = state.copyWith(locked: false, clearError: true);
    return true;
  }

  Future<bool> unlockWithBiometric() async {
    if (!state.biometric) return false;
    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      if (!supported) return false;
      final ok = await auth
          .authenticate(
            localizedReason: 'Unlock Smart Money Manager',
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: true,
              useErrorDialogs: true,
            ),
          )
          .timeout(const Duration(seconds: 30), onTimeout: () => false);
      if (!ok) return false;
      state = state.copyWith(locked: false, clearError: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deviceHasBiometrics() async {
    if (kIsWeb) return false;
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return false;
      final enrolled = await auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _pinMatches(String pin) async {
    final stored = await AppSecureStore.read(_pinKey);
    if (stored == null) return false;
    return constantTimeEquals(stored, pin);
  }
}

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockSnapshot>(AppLockController.new);

String? validatePin(String pin) {
  if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
    return 'Use 4 to 6 digits';
  }
  return null;
}

bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
