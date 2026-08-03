import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/exception_mapper.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/supabase_client.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(SupabaseBootstrap.client);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseBootstrap.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return SupabaseBootstrap.client.auth.currentUser;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.session == null) {
        throw const AuthFailure('Unable to sign in. Please try again.');
      }
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String displayName,
    required String baseCurrency,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'display_name':
              displayName.trim().isEmpty ? email.split('@').first : displayName.trim(),
          'base_currency': baseCurrency,
        },
      );
      if (response.session != null) return null;
      return 'Account created. Check your email to confirm, then sign in.';
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw mapException(e);
    }
  }
}
