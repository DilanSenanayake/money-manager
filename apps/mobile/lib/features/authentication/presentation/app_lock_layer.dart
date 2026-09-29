import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/security/app_lock_controller.dart';
import '../data/auth_repository.dart';

class AppLockLayer extends ConsumerStatefulWidget {
  const AppLockLayer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockLayer> createState() => _AppLockLayerState();
}

class _AppLockLayerState extends ConsumerState<AppLockLayer>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(
      () => ref.read(appLockControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockControllerProvider.notifier);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      lock.onPause();
    } else if (state == AppLifecycleState.resumed) {
      lock.onResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockControllerProvider);
    if (!lock.ready) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (lock.locked) {
      return _LockScreen(message: lock.error);
    }
    return widget.child;
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen({this.message});

  final String? message;

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    final lock = ref.read(appLockControllerProvider);
    if (!lock.biometric) return;
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await _biometric();
  }

  Future<void> _biometric() async {
    setState(() => _busy = true);
    final ok =
        await ref.read(appLockControllerProvider.notifier).unlockWithBiometric();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : 'Biometrics did not unlock the app. Enter your PIN.';
    });
  }

  Future<void> _submit(String pin) async {
    final ok =
        await ref.read(appLockControllerProvider.notifier).unlockWithPin(pin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _pin = '';
        _error = 'Incorrect PIN';
      });
    }
  }

  void _press(String digit) {
    if (_pin.length >= 6 || _busy) return;
    final next = '$_pin$digit';
    setState(() {
      _pin = next;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final biometric = ref.watch(appLockControllerProvider).biometric;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.lock_outline, size: 36, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                'Unlock ${AppConstants.appName}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                widget.message ?? _error ?? 'Enter your PIN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _error == null && widget.message == null
                      ? scheme.onSurfaceVariant
                      : scheme.error,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final filled = index < _pin.length;
                  return Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? scheme.primary : scheme.outlineVariant,
                    ),
                  );
                }),
              ),
              const Spacer(),
              if (biometric)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextButton.icon(
                    onPressed: _busy ? null : _biometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use biometrics'),
                  ),
                ),
              _PinPad(
                onDigit: _press,
                onBackspace: _pin.isEmpty
                    ? null
                    : () => setState(() => _pin = _pin.substring(0, _pin.length - 1)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _pin.length < 4 || _busy ? null : () => _submit(_pin),
                  child: const Text('Unlock'),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go(RoutePaths.login);
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback? onBackspace;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        for (final key in keys)
          if (key.isEmpty)
            const SizedBox.shrink()
          else if (key == 'del')
            IconButton(
              onPressed: onBackspace,
              iconSize: 28,
              tooltip: 'Delete',
              icon: const Icon(Icons.backspace_outlined),
            )
          else
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onDigit(key);
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              child: Text(key),
            ),
      ],
    );
  }
}

class AppLockSettings extends ConsumerWidget {
  const AppLockSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App lock',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ask for a PIN when you open the app or come back to it. Biometrics can unlock it on this phone. The PIN stays until you turn this off.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Lock with a PIN'),
          value: lock.enabled,
          onChanged: (value) async {
            if (value) {
              await _enable(context, ref);
            } else {
              final pin = await _askPin(context, 'Enter your PIN to turn off app lock');
              if (pin == null) return;
              final error =
                  await ref.read(appLockControllerProvider.notifier).disable(pin);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
              }
            }
          },
        ),
        if (lock.enabled)
          TextButton(
            onPressed: () => _change(context, ref),
            child: const Text('Change PIN'),
          ),
      ],
    );
  }

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final created = await _createPin(context);
    if (created == null || !context.mounted) return;
    final biometric = await ref
        .read(appLockControllerProvider.notifier)
        .deviceHasBiometrics();
    var useBiometric = false;
    if (biometric && context.mounted) {
      useBiometric = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Use biometrics?'),
              content: const Text(
                'You can unlock with fingerprint or face as well as the PIN. If that fails, the PIN is still required.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('PIN only'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Use biometrics'),
                ),
              ],
            ),
          ) ??
          false;
    }
    final error = await ref.read(appLockControllerProvider.notifier).enable(
          pin: created,
          biometric: useBiometric,
        );
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _change(BuildContext context, WidgetRef ref) async {
    final current = await _askPin(context, 'Current PIN');
    if (current == null || !context.mounted) return;
    final next = await _createPin(context);
    if (next == null) return;
    final error = await ref.read(appLockControllerProvider.notifier).changePin(
          current: current,
          next: next,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'PIN updated')),
    );
  }
}

Future<String?> _askPin(BuildContext context, String title) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'PIN'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<String?> _createPin(BuildContext context) async {
  final first = await _askPin(context, 'Choose a 4 to 6 digit PIN');
  if (first == null) return null;
  final error = validatePin(first);
  if (error != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
    return null;
  }
  if (!context.mounted) return null;
  final second = await _askPin(context, 'Confirm PIN');
  if (second == null) return null;
  if (first != second) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match')),
      );
    }
    return null;
  }
  return first;
}
