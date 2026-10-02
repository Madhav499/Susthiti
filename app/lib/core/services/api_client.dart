
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../errors/failures.dart';
import 'token_storage.dart';

typedef Json = Map<String, dynamic>;

/// Single HTTP entry point. Attaches the session token, maps every error to a [Failure],
/// and never logs bodies, tokens or medical content.
class ApiClient {
  ApiClient({required this.tokenStorage, Dio? dio, this.onUnauthorized})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.read();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) debugPrint('[api] ${response.requestOptions.method} ${_route(response.requestOptions.path)} -> ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) {
        if (kDebugMode) debugPrint('[api] ${error.requestOptions.method} ${_route(error.requestOptions.path)} -> ${error.response?.statusCode ?? error.type.name}');
        handler.next(error);
      },
    ));
  }

  final TokenStorage tokenStorage;
  final Dio _dio;

  /// Called when the server says the session is no longer valid.
  void Function()? onUnauthorized;

  static String _route(String path) => path.replaceAll(RegExp(r'[0-9a-f]{32}'), ':id');

  Future<Json> get(String path, {Map<String, dynamic>? query}) => _send(() => _dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<Json> post(String path, {Object? body, Duration? timeout}) =>
      _send(() => _dio.post<dynamic>(path, data: body ?? const <String, dynamic>{}, options: Options(receiveTimeout: timeout)));

  Future<Json> put(String path, {Object? body}) => _send(() => _dio.put<dynamic>(path, data: body));

  Future<Json> patch(String path, {Object? body}) => _send(() => _dio.patch<dynamic>(path, data: body));

  Future<Json> upload(String path, {required Map<String, dynamic> fields, required String fileField, required Uint8List bytes, required String filename, String method = 'POST'}) {
    final form = FormData.fromMap({
      ..._clean(fields)!,
      fileField: MultipartFile.fromBytes(bytes, filename: filename),
    });
    return _send(
      () => _dio.request<dynamic>(path, data: form, options: Options(method: method, sendTimeout: AppConfig.uploadTimeout, receiveTimeout: AppConfig.uploadTimeout)),
      isUpload: true,
    );
  }

  Future<Uint8List> getBytes(String path) async {
    try {
      final response = await _dio.get<List<int>>(path, options: Options(responseType: ResponseType.bytes, receiveTimeout: AppConfig.uploadTimeout));
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<Json> _send(Future<Response<dynamic>> Function() call, {bool isUpload = false}) async {
    try {
      final response = await call();
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{};
    } on DioException catch (e) {
      final failure = _map(e);
      if (isUpload && failure is NetworkFailure) throw const FileUploadFailure();
      throw failure;
    }
  }

  Failure _map(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        // No connection was ever made: the server address is unreachable from this device (wrong
        // address, other network, firewall). Not a slow server, so not a TimeoutFailure.
        return NetworkFailure(_withServer("Can't reach SUSTHITI's server. Please check your connection and try again."));
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutFailure();
      case DioExceptionType.connectionError:
        return NetworkFailure(_withServer(const NetworkFailure().message));
      case DioExceptionType.cancel:
        return const NetworkFailure('The request was cancelled.');
      default:
        break;
    }
    final response = e.response;
    if (response == null) return const NetworkFailure();
    return mapResponseError(response.statusCode ?? 0, response.data, onUnauthorized);
  }

  /// Development builds name the server they tried, so a wrong or stale address is obvious.
  /// Release builds never show it.
  static String _withServer(String message) => kDebugMode ? '$message\n(Development build: no answer from ${AppConfig.serverOrigin})' : message;

  static Map<String, dynamic>? _clean(Map<String, dynamic>? map) {
    if (map == null) return null;
    return {for (final entry in map.entries) if (entry.value != null && entry.value != '') entry.key: entry.value};
  }
}

/// Maps HTTP status + the backend's {detail: {code, message}} envelope to a [Failure].
Failure mapResponseError(int status, Object? data, [void Function()? onUnauthorized]) {
  String? code;
  String? message;
  String? field;
  if (data is Map && data['detail'] is Map) {
    final detail = data['detail'] as Map;
    code = detail['code'] as String?;
    message = detail['message'] as String?;
    final details = detail['details'];
    if (details is Map) field = details['field'] as String?;
  }
  if (code != null && code.startsWith('ai_')) {
    return AIServiceFailure(message ?? 'AI summary unavailable right now.', code: code);
  }
  if (code != null && code.startsWith('model_')) return ModelServiceFailure(message ?? 'The assessment service is temporarily unavailable. Please try again later.', code);
  switch (status) {
    case 400:
    case 422:
      return ValidationFailure(message ?? 'Please check the information you entered.', field: field);
    case 401:
      onUnauthorized?.call();
      return AuthenticationFailure(message ?? 'Please sign in again.');
    case 403:
      return AuthorizationFailure(message ?? "You don't have permission to access this information.");
    case 404:
      return NotFoundFailure(message ?? "We couldn't find that record.");
    case 409:
      return ConflictFailure(message ?? 'This record has changed. Please refresh.');
    case 502:
    case 503:
    case 504:
      return const NetworkFailure('The service is temporarily unavailable. Please try again shortly.');
    default:
      return DatabaseFailure(message ?? 'Something went wrong. Please try again.');
  }
}
