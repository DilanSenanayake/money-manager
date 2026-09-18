import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/open_url.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../authentication/data/auth_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/settings_repository.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _name = TextEditingController();
  String _currency = 'USD';
  bool _loaded = false;
  bool _saving = false;

  final _from = TextEditingController(text: 'USD');
  final _to = TextEditingController(text: 'LKR');
  final _rate = TextEditingController();

  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _savingPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _from.dispose();
    _to.dispose();
    _rate.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider).updateProfile(
            displayName: _name.text.trim(),
            baseCurrency: _currency,
          );
      ref.invalidate(profileProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(analyticsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile updated. Wallet currencies are unchanged — add an exchange rate if needed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is Failure ? e.message : e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPassword.text != _confirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: _currentPassword.text,
            newPassword: _newPassword.text,
          );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is Failure ? e.message : e.toString())),
      );
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _deleteAccount() async {
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This removes your login, wallets, and transactions. It cannot be undone.',
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: password,
                label: 'Password',
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await ref.read(authRepositoryProvider).deleteAccount(
            password: password.text,
          );
      if (!mounted) return;
      context.go(RoutePaths.login);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is Failure ? e.message : e.toString())),
      );
    } finally {
      password.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final email = ref.watch(currentUserProvider)?.email ?? '';

    profileAsync.whenData((profile) {
      if (!_loaded) {
        _name.text = profile.displayName ?? '';
        _currency = profile.baseCurrency;
        _loaded = true;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profileAsync.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(
          message: e is Failure ? e.message : e.toString(),
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (_) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                'Profile',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _name,
                label: 'Display name',
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                child: Text(email.isEmpty ? '—' : email),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(
                  labelText: 'Base currency',
                  prefixIcon: Icon(Icons.public_outlined),
                ),
                items: AppConstants.currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _currency = v ?? 'USD'),
              ),
              const SizedBox(height: 8),
              Text(
                'Changing base currency does not relabel wallet balances. Add an exchange rate instead.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate,
                    ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Save profile',
                loading: _saving,
                onPressed: _saveProfile,
              ),
              const SizedBox(height: 28),
              Text(
                'Password',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _currentPassword,
                label: 'Current password',
                obscureText: true,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _newPassword,
                label: 'New password',
                obscureText: true,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _confirmPassword,
                label: 'Confirm new password',
                obscureText: true,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Update password',
                loading: _savingPassword,
                onPressed: _changePassword,
              ),
              const SizedBox(height: 28),
              Text(
                'Exchange rates',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manual rates used for net worth and analytics. Missing rates fall back to 1:1.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: AppConstants.currencies.contains(_from.text)
                          ? _from.text
                          : 'USD',
                      decoration: const InputDecoration(labelText: 'From'),
                      items: AppConstants.currencies
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => _from.text = v ?? 'USD',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: AppConstants.currencies.contains(_to.text)
                          ? _to.text
                          : 'LKR',
                      decoration: const InputDecoration(labelText: 'To'),
                      items: AppConstants.currencies
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => _to.text = v ?? 'LKR',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _rate,
                label: 'Rate',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Save rate',
                onPressed: () async {
                  final rate = double.tryParse(_rate.text.trim());
                  if (rate == null || rate <= 0) return;
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref.read(settingsRepositoryProvider).upsertExchangeRate(
                          fromCurrency: _from.text.trim().toUpperCase(),
                          toCurrency: _to.text.trim().toUpperCase(),
                          rate: rate,
                        );
                    ref.invalidate(exchangeRatesProvider);
                    ref.invalidate(dashboardProvider);
                    _rate.clear();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(e is Failure ? e.message : e.toString()),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              ratesAsync.when(
                loading: () => const LoadingView(),
                error: (e, _) => Text(e is Failure ? e.message : e.toString()),
                data: (rates) {
                  if (rates.isEmpty) {
                    return const AppCard(
                      child: Text('No custom rates yet.'),
                    );
                  }
                  return Column(
                    children: rates
                        .map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '1 ${r.fromCurrency} = ${r.rate} ${r.toCurrency}',
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      await ref
                                          .read(settingsRepositoryProvider)
                                          .deleteExchangeRate(r.id);
                                      ref.invalidate(exchangeRatesProvider);
                                      ref.invalidate(dashboardProvider);
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 28),
              Text(
                'Delete account',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This removes your login, wallets, and transactions. It cannot be undone.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate,
                    ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _deleteAccount,
                child: const Text('Delete account'),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => openExternalUrl(AppConfig.termsUrl),
                child: const Text('Terms of Use'),
              ),
              TextButton(
                onPressed: () => openExternalUrl(AppConfig.privacyUrl),
                child: const Text('Privacy Policy'),
              ),
            ],
          );
        },
      ),
    );
  }
}
