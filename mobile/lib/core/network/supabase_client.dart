import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  static Future<void> init() async {
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null ||
        url.isEmpty ||
        anonKey == null ||
        anonKey.isEmpty ||
        url.contains('your-project')) {
      throw StateError(
        'Missing Supabase config. Copy mobile/.env.example to mobile/.env '
        'and set SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }

    await Supabase.initialize(
      url: url,
      // publishableKey is the new name for the public anon/publishable key.
      publishableKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
