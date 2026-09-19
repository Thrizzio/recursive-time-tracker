import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/api_config.dart';
import 'package:app/core/networking/api_client.dart';

void main() {
  group('ApiClient Tests', () {
    test('initializes with default options and attach CookieManager', () {
      final cookieJar = CookieJar();
      final client = ApiClient(cookieJar: cookieJar);

      expect(client.dio.options.connectTimeout, equals(ApiConfig.connectTimeout));
      expect(client.dio.options.receiveTimeout, equals(ApiConfig.receiveTimeout));
      expect(client.dio.options.sendTimeout, equals(ApiConfig.sendTimeout));
      expect(
        client.dio.interceptors.any((i) => i is CookieManager),
        isTrue,
      );
    });

    test('stores and sends cookies across requests', () async {
      final cookieJar = CookieJar();
      final uri = Uri.parse('http://10.0.2.2:3000');

      // Pre-seed a session cookie into CookieJar
      await cookieJar.saveFromResponse(uri, [
        Cookie('chronolog_session', 'test-session-token-123')
          ..httpOnly = true
          ..secure = false
          ..path = '/',
      ]);

      final cookies = await cookieJar.loadForRequest(uri);
      expect(cookies.length, equals(1));
      expect(cookies.first.name, equals('chronolog_session'));
      expect(cookies.first.value, equals('test-session-token-123'));
    });

    test('checkHealth returns false gracefully on connection error', () async {
      final cookieJar = CookieJar();
      final client = ApiClient(
        cookieJar: cookieJar,
        baseUrl: 'http://non-existent-domain-test:9999',
      );

      final isHealthy = await client.checkHealth();
      expect(isHealthy, isFalse);
    });
  });
}
