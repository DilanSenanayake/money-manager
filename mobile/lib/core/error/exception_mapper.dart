import 'package:supabase_flutter/supabase_flutter.dart';

import 'failures.dart';

Failure mapException(Object error) {
  if (error is Failure) return error;
  if (error is AuthException) {
    return AuthFailure(error.message);
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
