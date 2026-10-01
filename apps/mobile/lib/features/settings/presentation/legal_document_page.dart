import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/open_url.dart';

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final doc = _docs[kind] ?? _docs['privacy']!;
    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Text(
            'Last updated 29 September 2026. Operator: ${AppConfig.operatorName}.',
            style: TextStyle(color: context.muted),
          ),
          const SizedBox(height: 16),
          for (final section in doc.sections) ...[
            Text(
              section.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(section.body),
            const SizedBox(height: 20),
          ],
          TextButton(
            onPressed: () => openExternalUrl(doc.url),
            child: Text('Open the full page (${doc.url})'),
          ),
          TextButton(
            onPressed: () => openExternalUrl(AppConfig.mailtoUrl),
            child: Text('Contact ${AppConfig.contactEmail}'),
          ),
        ],
      ),
    );
  }
}

class _Doc {
  const _Doc({
    required this.title,
    required this.url,
    required this.sections,
  });

  final String title;
  final String url;
  final List<({String title, String body})> sections;
}

final _docs = <String, _Doc>{
  'privacy': _Doc(
    title: 'Privacy Policy',
    url: AppConfig.privacyUrl,
    sections: [
      (
        title: 'Who we are',
        body:
            '${AppConstants.appName} is operated by ${AppConfig.operatorName}, an individual, not a registered company. Contact ${AppConfig.contactEmail}. The same policy covers the Android app and the website at ${AppConfig.siteUrl}.',
      ),
      (
        title: 'What the app collects',
        body:
            'Account email, a password stored as a hash by Supabase, display name, and base currency. Money records you save: wallets, balances, transactions, categories, budgets, notes, merchants, and exchange rates you type. Smart Add text you choose to send (a typed note, a bank message you paste, or text read from a receipt photo). The photo itself stays on the phone. Voice uses the microphone. On many Android phones the speech recognizer sends that audio to Google. We do not store a recording. The app does not read your SMS inbox and does not connect to a bank.',
      ),
      (
        title: 'Who processes it',
        body:
            'Supabase stores the account and the money records. The application server runs the app logic. Groq receives Smart Add text so it can suggest an amount, merchant, and category. Nothing is saved until you confirm. Google Fonts downloads the typeface. Google ML Kit reads receipt text on the device. The website may use Vercel Web Analytics and, if configured, Google Analytics. The Android app does not include an ads or crash-reporting SDK. We do not sell personal information.',
      ),
      (
        title: 'Storage and security',
        body:
            'Connections use HTTPS in the published app. The login session is stored in the Android Keystore or iOS Keychain. Android backup of app data is turned off. You can set a PIN lock. Money records live in Supabase, protected by per-user database rules. No method of storage is perfectly secure.',
      ),
      (
        title: 'Retention, export, and deletion',
        body:
            'Records stay while the account is open. In the app, Settings, Delete account, removes the login and the money records after you confirm your password. You can also email ${AppConfig.contactEmail} from the account address. We aim to complete an emailed request within 30 days. Settings can export transactions as CSV or JSON. Backup copies at the host may remain until they expire.',
      ),
      (
        title: 'Children and your rights',
        body:
            'The service is not for anyone under 16. Depending on where you live, you may ask to access, correct, delete, or export your information, and you may complain to a public authority. We do not sell personal information. Governing context for the operator is Sri Lanka. This does not remove rights you have where you live.',
      ),
    ],
  ),
  'terms': _Doc(
    title: 'Terms of Use',
    url: AppConfig.termsUrl,
    sections: [
      (
        title: 'Agreement',
        body:
            'These terms are between you and ${AppConfig.operatorName}. By creating an account or accepting them in the app, you agree. If you do not agree, do not use ${AppConstants.appName}.',
      ),
      (
        title: 'The service',
        body:
            'The app and website are a personal budgeting tool: wallets, transactions, budgets, recurring items, and optional Smart Add. You confirm a suggestion before it is saved. You are responsible for your password and for the accuracy of what you enter.',
      ),
      (
        title: 'Acceptable use',
        body:
            'Do not misuse the service, attempt to read someone else’s records, upload malware, or submit content you have no right to use. The operator may suspend access if the service cannot be run safely.',
      ),
      (
        title: 'Your content and ours',
        body:
            'You keep your records. You allow the operator to host and process them to run the service, including sending Smart Add text to the AI provider. That permission ends when the live copy is deleted, aside from short-lived backups and what the law requires. The software, name, and design stay with the operator. You get a personal, non-exclusive right to use them for your own bookkeeping.',
      ),
      (
        title: 'Ending use',
        body:
            'You may stop at any time and delete the account in Settings, or email ${AppConfig.contactEmail}. The operator may stop the personal project. Sections on intellectual property, the disclaimer, liability, and governing law still apply.',
      ),
      (
        title: 'Liability and law',
        body:
            'The service is provided as is. To the extent the law allows, liability is limited to the greater of what you paid in the three months before a claim or 20 US dollars. Some places do not allow that limit, and it applies only as far as it legally can. These terms use the laws of Sri Lanka, without taking away consumer protections that cannot be waived where you live. Contact ${AppConfig.contactEmail} and try to resolve a dispute for 30 days before filing a claim.',
      ),
    ],
  ),
  'disclaimer': _Doc(
    title: 'Financial disclaimer',
    url: AppConfig.disclaimerUrl,
    sections: [
      (
        title: 'Not advice',
        body:
            '${AppConstants.appName} is a tracking and budgeting tool. It is not a bank, payment service, lender, broker, tax agent, or licensed adviser. Nothing in the app is financial, investment, tax, or legal advice.',
      ),
      (
        title: 'Figures can be wrong',
        body:
            'Totals, budgets, exchange rates, and Smart Add suggestions can be incomplete or inaccurate. Exchange rates are the ones you type. You are responsible for checking every entry before you rely on it. For decisions about your money, speak to a qualified person in your country.',
      ),
    ],
  ),
};
