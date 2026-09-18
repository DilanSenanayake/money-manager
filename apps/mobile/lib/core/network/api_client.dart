import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../error/exception_mapper.dart';
import '../error/failures.dart';

typedef TokenProvider = Future<String?> Function();
typedef TokenRefresher = Future<String?> Function();

final ledgerlyApiProvider = Provider<LedgerlyApi>((ref) {
  return LedgerlyApi(
    baseUrl: AppConfig.apiBaseUrl,
    tokenProvider: () async {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    },
    refreshToken: () async {
      final response = await Supabase.instance.client.auth.refreshSession();
      return response.session?.accessToken;
    },
  );
});

class LedgerlyApi {
  LedgerlyApi({
    required String baseUrl,
    required TokenProvider tokenProvider,
    TokenRefresher? refreshToken,
    Dio? dio,
  }) : _tokenProvider = tokenProvider {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 40),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        );
    _dio.interceptors.add(
      _AuthInterceptor(
        dio: _dio,
        tokenProvider: tokenProvider,
        refreshToken: refreshToken,
      ),
    );
  }

  late final Dio _dio;
  final TokenProvider _tokenProvider;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic json)? parse,
  }) {
    return _send(
      () => _dio.get<dynamic>(path, queryParameters: _cleanQuery(query)),
      parse: parse,
    );
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(dynamic json)? parse,
  }) {
    return _send(
      () => _dio.post<dynamic>(path, data: body),
      parse: parse,
    );
  }

  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(dynamic json)? parse,
  }) {
    return _send(
      () => _dio.patch<dynamic>(path, data: body),
      parse: parse,
    );
  }

  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(dynamic json)? parse,
  }) {
    return _send(
      () => _dio.put<dynamic>(path, data: body),
      parse: parse,
    );
  }

  Future<T> delete<T>(
    String path, {
    T Function(dynamic json)? parse,
  }) {
    return _send(
      () => _dio.delete<dynamic>(path),
      parse: parse,
    );
  }

  Future<void> mutate(
    String path, {
    String method = 'POST',
    Object? body,
  }) async {
    await _send<dynamic>(() {
      switch (method) {
        case 'PATCH':
          return _dio.patch<dynamic>(path, data: body);
        case 'PUT':
          return _dio.put<dynamic>(path, data: body);
        case 'DELETE':
          return _dio.delete<dynamic>(path);
        default:
          return _dio.post<dynamic>(path, data: body);
      }
    });
  }

  Future<T> _send<T>(
    Future<Response<dynamic>> Function() request, {
    T Function(dynamic json)? parse,
  }) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('Please sign in again.');
    }

    try {
      final response = await request();
      final data = response.data;
      if (parse != null) return parse(data);
      return data as T;
    } catch (error) {
      throw mapException(error);
    }
  }

  Map<String, dynamic>? _cleanQuery(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      cleaned[entry.key] = value;
    }
    return cleaned.isEmpty ? null : cleaned;
  }
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor({
    required this.dio,
    required this.tokenProvider,
    this.refreshToken,
  });

  final Dio dio;
  final TokenProvider tokenProvider;
  final TokenRefresher? refreshToken;

  static const _retriedKey = 'ledgerly_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenProvider();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;
    if (err.response?.statusCode != 401 ||
        alreadyRetried ||
        refreshToken == null) {
      handler.next(err);
      return;
    }

    try {
      final token = await refreshToken!();
      if (token == null || token.isEmpty) {
        handler.next(err);
        return;
      }
      final request = err.requestOptions;
      request.headers['Authorization'] = 'Bearer $token';
      request.extra[_retriedKey] = true;
      final response = await dio.fetch<dynamic>(request);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }
}
