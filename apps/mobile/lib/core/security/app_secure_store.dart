import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keystore / Keychain storage for the session, app-lock PIN, and consent.
class AppSecureStore {
  AppSecureStore._();

  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  static Future<String?> read(String key) => storage.read(key: key);

  static Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);

  static Future<void> delete(String key) => storage.delete(key: key);
}
