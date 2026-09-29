import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl => _required('SUPABASE_URL');

  static String get supabaseAnonKey => _required('SUPABASE_ANON_KEY');

  static String get apiBaseUrl {
    final value = (dotenv.env['API_BASE_URL'] ?? '').trim().replaceAll(
      RegExp(r'/$'),
      '',
    );
    if (value.isEmpty || value.contains('your-')) {
      throw StateError(
        'Missing API_BASE_URL. Copy apps/mobile/.env.example to '
        'apps/mobile/.env and point it at Ledgerly.Api '
        '(http://localhost:5080 or http://10.0.2.2:5080 on the Android emulator).',
      );
    }
    _requireHttpsInRelease(value, 'API_BASE_URL');
    return value;
  }

  static String get siteUrl {
    final value = (dotenv.env['SITE_URL'] ?? '').trim().replaceAll(
      RegExp(r'/$'),
      '',
    );
    if (value.isEmpty) return 'https://www.smoneymanager.com';
    return value;
  }

  static const operatorName = 'Dilan Senanayake';
  static const contactEmail = 'diladws@gmail.com';

  static String get termsUrl => '$siteUrl/terms';

  static String get privacyUrl => '$siteUrl/privacy';

  static String get disclaimerUrl => '$siteUrl/disclaimer';

  static String get accountDeletionUrl => '$siteUrl/account-deletion';

  static String get licensesUrl => '$siteUrl/licenses';

  static String get mailtoUrl => 'mailto:$contactEmail';

  static void validate() {
    supabaseUrl;
    supabaseAnonKey;
    apiBaseUrl;
  }

  static String _required(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty || value.contains('your-project')) {
      throw StateError(
        'Missing $key. Copy apps/mobile/.env.example to apps/mobile/.env.',
      );
    }
    if (key == 'SUPABASE_URL') {
      _requireHttpsInRelease(value, key);
    }
    return value;
  }

  static void _requireHttpsInRelease(String value, String key) {
    if (kReleaseMode && !value.startsWith('https://')) {
      throw StateError('$key must start with https:// in release builds.');
    }
  }
}
