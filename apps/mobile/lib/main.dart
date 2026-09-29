import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/network/supabase_client.dart';
import 'core/security/consent_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: '.env');
  AppConfig.validate();
  await SupabaseBootstrap.init();
  final consentAccepted = await ConsentStore().isCurrent();

  runApp(
    ProviderScope(
      overrides: [
        consentAcceptedProvider.overrideWith((ref) => consentAccepted),
      ],
      child: const LedgerlyApp(),
    ),
  );
}
