import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/consent_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/auth_repository.dart';

class ConsentPage extends ConsumerStatefulWidget {
  const ConsentPage({super.key});

  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> {
  bool _agreed = false;
  bool _saving = false;

  Future<void> _accept() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms and Privacy Policy.')),
      );
      return;
    }
    setState(() => _saving = true);
    await ConsentStore().accept();
    ref.read(consentAcceptedProvider.notifier).state = true;
    if (!mounted) return;
    final loggedIn = ref.read(isAuthenticatedProvider);
    context.go(loggedIn ? RoutePaths.home : RoutePaths.login);
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Before you continue, please read the Terms of Use and the Privacy Policy. They explain what this budgeting app stores and that it is not financial advice.',
            ),
            const SizedBox(height: 8),
            Text(
              'The hosted copies are drafts until a qualified lawyer reviews them. Operator: ${AppConfig.operatorName}.',
              style: TextStyle(color: context.muted),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.push('/legal/terms'),
              child: const Text('Read Terms of Use'),
            ),
            TextButton(
              onPressed: () => context.push('/legal/privacy'),
              child: const Text('Read Privacy Policy'),
            ),
            TextButton(
              onPressed: () => context.push('/legal/disclaimer'),
              child: const Text('Read the financial disclaimer'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _agreed,
              onChanged: (value) => setState(() => _agreed = value ?? false),
              title: const Text('I agree to the Terms of Use and Privacy Policy'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Continue',
              loading: _saving,
              onPressed: _saving ? null : _accept,
            ),
          ],
        ),
      ),
    );
  }
}
