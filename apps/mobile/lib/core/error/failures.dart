import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([
    super.message = 'That took too long. Check your connection and try again.',
  ]);
}

class RateLimitFailure extends Failure {
  const RateLimitFailure([
    super.message = 'Too many requests. Please wait a moment and try again.',
  ]);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something went wrong']);
}
