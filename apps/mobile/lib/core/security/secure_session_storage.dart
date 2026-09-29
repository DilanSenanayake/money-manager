import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_secure_store.dart';

/// Supabase session stored in secure storage.
///
/// Older installs kept the refresh token in SharedPreferences. The first
/// launch after this change moves that value and deletes the plain copy.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({required this.persistSessionKey});

  final String persistSessionKey;

  @override
  Future<void> initialize() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(persistSessionKey);
    if (legacy == null || legacy.isEmpty) return;
    final current = await AppSecureStore.read(persistSessionKey);
    if (current == null || current.isEmpty) {
      await AppSecureStore.write(persistSessionKey, legacy);
    }
    await prefs.remove(persistSessionKey);
  }

  @override
  Future<bool> hasAccessToken() async {
    final value = await accessToken();
    return value != null && value.isNotEmpty;
  }

  @override
  Future<String?> accessToken() => AppSecureStore.read(persistSessionKey);

  @override
  Future<void> removePersistedSession() =>
      AppSecureStore.delete(persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      AppSecureStore.write(persistSessionKey, persistSessionString);
}

/// PKCE code verifier. Same migration as the session token.
class SecureGotrueStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async {
    final current = await AppSecureStore.read(key);
    if (current != null) return current;
    if (kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy == null) return null;
    await AppSecureStore.write(key, legacy);
    await prefs.remove(key);
    return legacy;
  }

  @override
  Future<void> removeItem({required String key}) async {
    await AppSecureStore.delete(key);
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) =>
      AppSecureStore.write(key, value);
}

String supabaseSessionKey(String url) {
  final host = Uri.parse(url).host;
  final projectRef = host.split('.').first;
  return 'sb-$projectRef-auth-token';
}
