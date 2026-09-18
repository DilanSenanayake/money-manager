import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'failures.dart';

Failure mapException(Object error) {
  if (error is Failure) return error;
  if (error is DioException) return mapDioException(error);
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
  if (error is FormatException) {
    return ServerFailure(error.message);
  }
  return UnexpectedFailure(error.toString());
}

Failure mapDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    case DioExceptionType.cancel:
      return const NetworkFailure('Request cancelled');
    case DioExceptionType.badCertificate:
      return const NetworkFailure('Secure connection failed.');
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

  return mapHttpError(
    status: error.response?.statusCode,
    data: error.response?.data,
  );
}

Failure mapHttpError({int? status, dynamic data}) {
  final message = extractApiErrorMessage(data);

  if (status == 401) {
    return AuthFailure(message ?? 'Please sign in again.');
  }
  if (status == 403) {
    return const AuthFailure('You do not have permission to do that.');
  }
  if (status == 404) {
    return ServerFailure(message ?? 'Not found');
  }
  if (status == 422 || status == 400) {
    return ValidationFailure(message ?? 'Please check what you entered.');
  }
  if (status == 429) {
    return RateLimitFailure(
      message ?? 'Too many requests. Please wait a moment and try again.',
    );
  }
  if (status != null && status >= 500) {
    return ServerFailure(message ?? 'Something went wrong. Please try again.');
  }
  return ServerFailure(message ?? 'Request failed');
}

String? extractApiErrorMessage(dynamic data) {
  if (data is String && data.trim().isNotEmpty) {
    final trimmed = data.trim();
    if (trimmed.startsWith('{') || trimmed.contains(':N')) {
      return null;
    }
    return trimmed;
  }
  if (data is! Map) return null;
  final map = Map<String, dynamic>.from(data);
  final error = map['error'];
  if (error is String && error.trim().isNotEmpty) return error.trim();
  final title = map['title'];
  if (title is String && title.trim().isNotEmpty) return title.trim();
  final errors = map['errors'];
  if (errors is Map && errors.isNotEmpty) {
    final first = errors.values.first;
    if (first is List && first.isNotEmpty && first.first is String) {
      return first.first as String;
    }
    if (first is String) return first;
  }
  return null;
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
  if (code.contains('email_not_confirmed') ||
      msg.contains('email not confirmed')) {
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
