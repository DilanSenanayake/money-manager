import 'package:supabase_flutter/supabase_flutter.dart';

import 'failures.dart';

Failure mapException(Object error) {
  if (error is Failure) return error;
  if (error is AuthException) {
    return AuthFailure(_authMessage(error));
  }
  if (error is PostgrestException) {
    return ServerFailure(error.message);
  }
  if (error is FunctionException) {
    return ServerFailure(error.details?.toString() ?? 'Request failed');
  }
  if (error is StateError) {
    return AuthFailure(error.message);
  }
  return UnexpectedFailure(error.toString());
}

String _authMessage(AuthException error) {
  final code = (error.code ?? '').toLowerCase();
  final msg = error.message.toLowerCase();

  if (code.contains('email_address_invalid') ||
      (msg.contains('email address') && msg.contains('invalid'))) {
    return 'That email looks invalid. Use a real inbox address (not example.com).';
  }
  if (code.contains('over_email_send_rate_limit') ||
      msg.contains('rate limit')) {
    return 'Too many signup emails sent. Wait a minute and try again.';
  }
  if (code.contains('user_already_exists') ||
      msg.contains('already registered') ||
      msg.contains('already been registered')) {
    return 'An account with this email already exists. Try signing in.';
  }
  if (code.contains('email_not_confirmed') || msg.contains('email not confirmed')) {
    return 'Confirm your email from the link we sent, then sign in.';
  }
  if (code.contains('invalid_credentials') ||
      msg.contains('invalid login credentials')) {
    return 'Incorrect email or password.';
  }
  if (error.message.trim().isEmpty) {
    return 'Authentication failed. Please try again.';
  }
  return error.message;
}
