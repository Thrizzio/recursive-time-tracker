import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';

/// Provider for the global CookieJar instance.
final cookieJarProvider = Provider<CookieJar>((ref) {
  throw UnimplementedError('cookieJarProvider must be initialized in main()');
});

/// Provider for ApiClient.
final apiClientProvider = Provider<ApiClient>((ref) {
  final cookieJar = ref.watch(cookieJarProvider);
  return ApiClient(cookieJar: cookieJar);
});

/// Central API client for Chronolog backend communication.
/// Handles base URL, cookie persistence via [CookieJar], timeouts, and logging.
class ApiClient {
  ApiClient({
    required this.cookieJar,
    String? baseUrl,
    Dio? customDio,
    this.onUnauthorized,
  }) : dio = customDio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.baseUrl,
                connectTimeout: ApiConfig.connectTimeout,
                receiveTimeout: ApiConfig.receiveTimeout,
                sendTimeout: ApiConfig.sendTimeout,
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    dio.interceptors.add(CookieManager(cookieJar));

    // Handle 401 Unauthorized globally (session expired)
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          if (e.response?.statusCode == 401) {
            final path = e.requestOptions.path;
            if (!path.contains('/auth/me') && !path.contains('/auth/mobile/google')) {
              onUnauthorized?.call();
            }
          }
          return handler.next(e);
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint('[API] => ${options.method} ${options.uri}');
            return handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint(
              '[API] <= ${response.statusCode} ${response.requestOptions.uri}',
            );
            return handler.next(response);
          },
          onError: (DioException e, handler) {
            debugPrint(
              '[API] !! Error [${e.response?.statusCode}] on ${e.requestOptions.uri}: ${e.message}',
            );
            return handler.next(e);
          },
        ),
      );
    }
  }

  final Dio dio;
  final CookieJar cookieJar;
  final void Function()? onUnauthorized;

  /// Helper factory to initialize [PersistCookieJar] with device document directory.
  static Future<CookieJar> createDefaultCookieJar() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final cookiePath = '${appDocDir.path}/.cookies';
      final dir = Directory(cookiePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return PersistCookieJar(
        storage: FileStorage(cookiePath),
        ignoreExpires: false,
      );
    } catch (e) {
      debugPrint('[ApiClient] Falling back to in-memory CookieJar: $e');
      return CookieJar();
    }
  }

  /// Perform a GET request.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Perform a POST request.
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Perform a PATCH request.
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Perform a DELETE request.
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Check backend health status (`/health`).
  Future<bool> checkHealth() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/health');
      return res.statusCode == 200 && res.data?['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }
}

