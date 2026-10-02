import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susthiti/core/config/app_config.dart';
import 'package:susthiti/core/errors/failures.dart';
import 'package:susthiti/core/services/api_client.dart';
import 'package:susthiti/core/services/token_storage.dart';

/// An ApiClient whose every request fails the way Dio reports [type].
ApiClient failingWith(DioExceptionType type) {
  final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) => handler.reject(DioException(requestOptions: options, type: type))));
  return ApiClient(tokenStorage: MemoryTokenStorage(), dio: dio);
}

void main() {
  test('a server that never answers the connection is "cannot reach", not "taking longer"', () async {
    // What a phone built with a stale or wrong server address sees.
    final failure = await failingWith(DioExceptionType.connectionTimeout).post('/auth/register').then<Object?>((_) => null, onError: (Object e) => e);
    expect(failure, isA<NetworkFailure>());
    expect((failure as Failure).message, startsWith("Can't reach SUSTHITI's server."));
    expect(failure.message, isNot(contains('taking longer')));
    expect(failure.isRetryable, isTrue);
    // Development builds name the server they tried, so a wrong address is visible at once.
    expect(failure.message, contains(AppConfig.serverOrigin));
  });

  test('a connection error is a network failure naming the server in development', () async {
    final failure = await failingWith(DioExceptionType.connectionError).get('/auth/me').then<Object?>((_) => null, onError: (Object e) => e);
    expect(failure, isA<NetworkFailure>());
    expect((failure as Failure).message, contains(AppConfig.serverOrigin));
  });

  test('a server that was reached but answers slowly is still a timeout', () async {
    for (final type in [DioExceptionType.receiveTimeout, DioExceptionType.sendTimeout]) {
      final failure = await failingWith(type).post('/auth/register').then<Object?>((_) => null, onError: (Object e) => e);
      expect(failure, isA<TimeoutFailure>(), reason: type.name);
    }
  });

  test('serverOrigin is the API base without its path', () {
    expect(AppConfig.serverOrigin, isNot(endsWith('/')));
    expect(AppConfig.apiBaseUrl, startsWith(AppConfig.serverOrigin));
    expect(Uri.parse(AppConfig.serverOrigin).path, isEmpty);
  });
}
