import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../security/secure_session_storage.dart';

class SupabaseBootstrap {
  static Future<void> init() async {
    final sessionKey = supabaseSessionKey(AppConfig.supabaseUrl);
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: SecureSessionStorage(persistSessionKey: sessionKey),
        pkceAsyncStorage: SecureGotrueStorage(),
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

