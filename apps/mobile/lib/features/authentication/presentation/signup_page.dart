import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/open_url.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/auth_repository.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _cash = TextEditingController();
  final _checking = TextEditingController();
  final _savings = TextEditingController();
  String _currency = 'USD';
  bool _loading = false;
  bool _obscure = true;
  bool _agreed = false;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _cash.dispose();
    _checking.dispose();
    _savings.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      setState(() => _error = 'Please agree to the Terms and Privacy Policy.');
      return;
    }
    final cash = _openingBalance(_cash, 'Cash');
    final checking = _openingBalance(_checking, 'Checking');
    final savings = _openingBalance(_savings, 'Savings');
    if (cash == null || checking == null || savings == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      final message = await ref.read(authRepositoryProvider).signUp(
            email: _email.text,
            password: _password.text,
            displayName: _name.text,
            baseCurrency: _currency,
            cashBalance: cash,
            checkingBalance: checking,
            savingsBalance: savings,
          );
      if (!mounted) return;
      if (message == null) {
        await HapticFeedback.lightImpact();
        if (!mounted) return;
        context.go(RoutePaths.home);
      } else {
        setState(() => _message = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final err = e is Failure ? e.message : e.toString();
      setState(() => _error = err);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _openingBalance(TextEditingController controller, String label) {
    final text = controller.text.trim();
    if (text.isEmpty) return '0.00';
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
      setState(() => _error = 'Enter a valid starting balance for $label.');
      return null;
    }
    final value = double.tryParse(text);
    if (value == null || value > 999999999.99) {
      setState(() => _error = '$label starting balance is too large.');
      return null;
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(RoutePaths.login),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Image.asset(
                          'assets/icons/logo.png',
                          width: 72,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Create account',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use a real email address. We’ll seed starter categories and wallets. After that, AI makes a new expense take seconds — you confirm it.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      AppTextField(
                        controller: _name,
                        label: 'Display name',
                        prefixIcon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _email,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.mail_outline_rounded,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) {
                          if (v == null || !v.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _password,
                        label: 'Password',
                        obscureText: _obscure,
                        prefixIcon: Icons.lock_outline_rounded,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        suffix: IconButton(
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        validator: (v) {
                          if (v == null ||
                              v.length < AppConstants.minPasswordLength) {
                            return 'Password must be at least ${AppConstants.minPasswordLength} characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(
                          labelText: 'Base currency',
                          prefixIcon: Icon(Icons.public_outlined),
                        ),
                        items: AppConstants.currencies
                            .map(
                              (c) =>
                                  DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _currency = v ?? 'USD'),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Starting balances',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Optional. Cash and Checking open in this currency. A savings wallet is added when that balance is above zero.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _cash,
                        label: 'Cash',
                        hint: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        prefixIcon: Icons.payments_outlined,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _checking,
                        label: 'Checking',
                        hint: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        prefixIcon: Icons.account_balance_outlined,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _savings,
                        label: 'Savings',
                        hint: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        prefixIcon: Icons.savings_outlined,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _agreed,
                        onChanged: (v) =>
                            setState(() => _agreed = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Wrap(
                          children: [
                            const Text('I agree to the '),
                            GestureDetector(
                              onTap: () =>
                                  openExternalUrl(AppConfig.termsUrl),
                              child: Text(
                                'Terms of Use',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Text(' and '),
                            GestureDetector(
                              onTap: () =>
                                  openExternalUrl(AppConfig.privacyUrl),
                              child: Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Text('.'),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _message!,
                          style: const TextStyle(color: AppColors.success),
                        ),
                      ],
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'Create account',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go(RoutePaths.login),
                        child: const Text('Already have an account? Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
