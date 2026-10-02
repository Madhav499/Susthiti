/// Typed failures. Repositories throw these; the UI turns them into calm, human messages.
sealed class Failure implements Exception {
  const Failure(this.message, {this.code});

  /// Message suitable to show to the user.
  final String message;
  final String? code;

  bool get isRetryable => true;

  @override
  String toString() => '$runtimeType($code): $message';
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Unable to reach SUSTHITI. Please check your connection.']) : super(code: 'network');
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'This is taking longer than expected. Please try again.']) : super(code: 'timeout');
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure([super.message = 'Please sign in again.']) : super(code: 'authentication_error');
  @override
  bool get isRetryable => false;
}

class AuthorizationFailure extends Failure {
  const AuthorizationFailure([super.message = "You don't have permission to access this information."]) : super(code: 'authorization_error');
  @override
  bool get isRetryable => false;
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.field}) : super(code: 'validation_error');
  final String? field;
  @override
  bool get isRetryable => false;
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = "We couldn't find that record."]) : super(code: 'not_found');
  @override
  bool get isRetryable => false;
}

class ConflictFailure extends Failure {
  const ConflictFailure(super.message) : super(code: 'conflict');
  @override
  bool get isRetryable => false;
}

class FileUploadFailure extends Failure {
  const FileUploadFailure([super.message = "The file couldn't be uploaded. Please try again."]) : super(code: 'upload');
}

class AIServiceFailure extends Failure {
  const AIServiceFailure(super.message, {super.code});

  bool get notConfigured => code == 'ai_not_configured';
  bool get invalidResponse => code == 'ai_invalid_response';
}

/// The diabetes assessment service could not produce a result. [code] tells the cases apart:
/// model_service_unavailable, model_service_timeout, model_inference_failed.
class ModelServiceFailure extends Failure {
  const ModelServiceFailure([super.message = 'The assessment service is temporarily unavailable. Please try again later.', String? code])
      : super(code: code ?? 'model_service_unavailable');

  bool get isTimeout => code == 'model_service_timeout';
  bool get isInferenceFailure => code == 'model_inference_failed';
}

class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = 'Something went wrong. Please try again.']) : super(code: 'server_error');
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something went wrong. Please try again.']) : super(code: 'unexpected');
}

Failure asFailure(Object error) => error is Failure ? error : const UnexpectedFailure();
