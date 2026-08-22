import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
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

  @override
  void dispose() {
    _name.dispose();
    _from.dispose();
    _to.dispose();
    _rate.dispose();
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final ratesAsync = ref.watch(exchangeRatesProvider);

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
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is Failure ? e.message : e.toString(),
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (_) {
          return ListView(
            padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 16),
              AppButton(
                label: 'Save profile',
                loading: _saving,
                onPressed: _saveProfile,
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
                'Manual rates used for net worth and analytics.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(controller: _from, label: 'From'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppTextField(controller: _to, label: 'To'),
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
                label: 'Upsert rate',
                onPressed: () async {
                  final rate = double.tryParse(_rate.text.trim());
                  if (rate == null || rate <= 0) return;
                  await ref.read(settingsRepositoryProvider).upsertExchangeRate(
                        fromCurrency: _from.text.trim().toUpperCase(),
                        toCurrency: _to.text.trim().toUpperCase(),
                        rate: rate,
                      );
                  ref.invalidate(exchangeRatesProvider);
                  ref.invalidate(dashboardProvider);
                  _rate.clear();
                },
              ),
              const SizedBox(height: 16),
              ratesAsync.when(
                loading: () => const LoadingView(),
                error: (e, _) => Text(e.toString()),
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
            ],
          );
        },
      ),
    );
  }
}
