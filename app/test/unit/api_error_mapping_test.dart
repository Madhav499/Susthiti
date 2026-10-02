import 'package:flutter_test/flutter_test.dart';
import 'package:susthiti/core/errors/failures.dart';
import 'package:susthiti/core/services/api_client.dart';

Map<String, dynamic> envelope(String code, String message, [Map<String, dynamic>? details]) => {
      'detail': {'code': code, 'message': message, 'details': ?details},
    };

void main() {
  test('maps HTTP statuses to typed failures', () {
    expect(mapResponseError(403, null), isA<AuthorizationFailure>());
    expect(mapResponseError(404, null), isA<NotFoundFailure>());
    expect(mapResponseError(409, null), isA<ConflictFailure>());
    expect(mapResponseError(503, null), isA<NetworkFailure>());
    expect(mapResponseError(500, null), isA<DatabaseFailure>());
  });

  test('validation failures keep the server message and field', () {
    final f = mapResponseError(422, envelope('validation_error', 'Enter a valid phone number.', {'field': 'phone'}));
    expect(f, isA<ValidationFailure>());
    expect(f.message, 'Enter a valid phone number.');
  });

  test('401 signs the user out', () {
    var called = false;
    expect(mapResponseError(401, null, () => called = true), isA<AuthenticationFailure>());
    expect(called, isTrue);
  });

  test('AI and model-service errors are distinguishable', () {
    final notConfigured = mapResponseError(503, envelope('ai_not_configured', 'AI is not configured.'));
    expect(notConfigured, isA<AIServiceFailure>());
    expect((notConfigured as AIServiceFailure).notConfigured, isTrue);

    final invalid = mapResponseError(502, envelope('ai_invalid_response', 'Bad output.'));
    expect((invalid as AIServiceFailure).invalidResponse, isTrue);
    expect(invalid.isRetryable, isTrue);

    expect(mapResponseError(503, envelope('model_service_unavailable', 'Model unavailable.')), isA<ModelServiceFailure>());
  });

  test('permission failures are not offered a retry', () {
    expect(mapResponseError(403, null).isRetryable, isFalse);
    expect(const NetworkFailure().isRetryable, isTrue);
  });
}
