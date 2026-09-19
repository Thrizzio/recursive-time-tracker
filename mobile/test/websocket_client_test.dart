import 'dart:async';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/networking/api_client.dart';
import 'package:app/core/networking/websocket_client.dart';
import 'package:app/features/auth/data/auth_repository.dart';
import 'package:app/features/auth/domain/user_model.dart';
import 'package:app/features/auth/presentation/auth_controller.dart';
import 'package:app/features/auth/presentation/auth_state.dart';
import 'package:app/features/tracking/data/tracking_repository.dart';
import 'package:app/features/tracking/presentation/tracking_controller.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user});
  final UserModel? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<UserModel?> checkCurrentUser() async => user;

  @override
  Future<void> logout() async {}
}

class FakeTrackingRepository implements TrackingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final testClientRefProvider = Provider<Ref>((ref) => ref);

void main() {
  group('WebSocketClient URL Transformation Tests', () {
    test('converts http to ws and appends /ws', () {
      final uri = WebSocketClient.toWebSocketUri('http://10.0.2.2:3000');
      expect(uri.scheme, 'ws');
      expect(uri.host, '10.0.2.2');
      expect(uri.port, 3000);
      expect(uri.path, '/ws');
      expect(uri.toString(), 'ws://10.0.2.2:3000/ws');
    });

    test('handles trailing slash on http base URL', () {
      final uri = WebSocketClient.toWebSocketUri('http://10.0.2.2:3000/');
      expect(uri.scheme, 'ws');
      expect(uri.path, '/ws');
      expect(uri.toString(), 'ws://10.0.2.2:3000/ws');
    });

    test('converts https to wss and appends /ws', () {
      final uri = WebSocketClient.toWebSocketUri('https://tunnel.ngrok.app');
      expect(uri.scheme, 'wss');
      expect(uri.host, 'tunnel.ngrok.app');
      expect(uri.path, '/ws');
      expect(uri.toString(), 'wss://tunnel.ngrok.app/ws');
    });

    test('preserves existing ws/wss scheme', () {
      final uri1 = WebSocketClient.toWebSocketUri('ws://localhost:3000');
      expect(uri1.scheme, 'ws');
      expect(uri1.path, '/ws');

      final uri2 = WebSocketClient.toWebSocketUri('wss://tunnel.ngrok.app/ws');
      expect(uri2.scheme, 'wss');
      expect(uri2.path, '/ws');
    });
  });

  group('WebSocketClient Event Handling Tests', () {
    late ProviderContainer container;
    late CookieJar cookieJar;
    late WebSocketClient client;

    final testUser = UserModel(
      id: 1,
      email: 'test@example.com',
      name: 'Test User',
      trackingStartedAt: null,
    );

    setUp(() async {
      cookieJar = CookieJar();
      final fakeAuth = FakeAuthRepository(user: testUser);
      final fakeTracking = FakeTrackingRepository();

      container = ProviderContainer(
        overrides: [
          cookieJarProvider.overrideWithValue(cookieJar),
          authRepositoryProvider.overrideWithValue(fakeAuth),
          trackingRepositoryProvider.overrideWithValue(fakeTracking),
        ],
      );

      // Authenticate via checkSession
      await container.read(authNotifierProvider.notifier).checkSession();

      client = WebSocketClient(
        cookieJar: cookieJar,
        ref: container.read(testClientRefProvider),
      );
    });

    tearDown(() {
      client.disconnect();
      container.dispose();
    });

    test('handles tracking.started event and updates user + tracking state', () {
      final timestampStr = '2026-09-19T13:30:00.000Z';
      client.handleRawMessage('''
        {
          "event": "tracking.started",
          "data": {
            "trackingStartedAt": "$timestampStr"
          }
        }
      ''');

      final trackingState = container.read(trackingControllerProvider);
      expect(trackingState.isTracking, isTrue);
      expect(trackingState.trackingStartedAt, DateTime.parse(timestampStr));

      final authState = container.read(authNotifierProvider);
      expect(authState, isA<Authenticated>());
      expect(
        (authState as Authenticated).user.trackingStartedAt,
        DateTime.parse(timestampStr),
      );
    });

    test('handles tracking.reset event and clears tracking state', () {
      // First set tracking
      client.handleEvent('tracking.started', {
        'trackingStartedAt': '2026-09-19T13:30:00.000Z',
      });
      expect(container.read(trackingControllerProvider).isTracking, isTrue);

      // Now send reset
      client.handleRawMessage('''
        {
          "event": "tracking.reset",
          "data": {
            "trackingStartedAt": null
          }
        }
      ''');

      final trackingState = container.read(trackingControllerProvider);
      expect(trackingState.isTracking, isFalse);
      expect(trackingState.trackingStartedAt, isNull);

      final authState = container.read(authNotifierProvider);
      expect((authState as Authenticated).user.trackingStartedAt, isNull);
    });

    test('handles time-block.created event and updates tracking start time', () {
      final newStartStr = '2026-09-19T14:15:00.000Z';
      client.handleRawMessage('''
        {
          "event": "time-block.created",
          "data": {
            "block": {
              "id": 10,
              "startTime": "2026-09-19T13:00:00.000Z",
              "endTime": "$newStartStr",
              "elapsedSeconds": 4500,
              "allocations": []
            },
            "trackingStartedAt": "$newStartStr"
          }
        }
      ''');

      final trackingState = container.read(trackingControllerProvider);
      expect(trackingState.isTracking, isTrue);
      expect(trackingState.trackingStartedAt, DateTime.parse(newStartStr));
    });
  });

  group('WebSocketClient Backoff & Cookie Handshake Tests', () {
    late CookieJar cookieJar;
    late FakeAuthRepository fakeAuth;

    setUp(() {
      cookieJar = CookieJar();
      fakeAuth = FakeAuthRepository();
    });

    test('skips connection if no chronolog_session cookie exists', () async {
      final container = ProviderContainer(
        overrides: [
          cookieJarProvider.overrideWithValue(cookieJar),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
      );

      await container.read(authNotifierProvider.notifier).checkSession();

      var connectorCalled = false;
      final client = WebSocketClient(
        cookieJar: cookieJar,
        ref: container.read(testClientRefProvider),
        baseUrl: 'http://10.0.2.2:3000',
        connector: (uri, headers) async {
          connectorCalled = true;
          throw const SocketException('Should not be called');
        },
      );

      await client.connect();
      expect(connectorCalled, isFalse);
      expect(client.status, WebSocketStatus.disconnected);

      client.disconnect();
      container.dispose();
    });

    test('passes Cookie header when chronolog_session cookie exists in CookieJar', () async {
      final baseUrl = 'http://10.0.2.2:3000';
      await cookieJar.saveFromResponse(
        Uri.parse(baseUrl),
        [
          Cookie('chronolog_session', 'sess_test_12345'),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          cookieJarProvider.overrideWithValue(cookieJar),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
      );

      await container.read(authNotifierProvider.notifier).checkSession();

      Uri? connectedUri;
      Map<String, dynamic>? receivedHeaders;

      final client = WebSocketClient(
        cookieJar: cookieJar,
        ref: container.read(testClientRefProvider),
        baseUrl: baseUrl,
        connector: (uri, headers) async {
          connectedUri = uri;
          receivedHeaders = headers;
          // Simulate failure after verifying headers
          throw const SocketException('Connection aborted for test verification');
        },
      );

      await client.connect();

      expect(connectedUri, isNotNull);
      expect(connectedUri.toString(), 'ws://10.0.2.2:3000/ws');
      expect(receivedHeaders, isNotNull);
      expect(receivedHeaders!['Cookie'], contains('chronolog_session=sess_test_12345'));

      client.disconnect();
      container.dispose();
    });

    test('exponential backoff configuration', () async {
      final container = ProviderContainer(
        overrides: [
          cookieJarProvider.overrideWithValue(cookieJar),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
      );

      await container.read(authNotifierProvider.notifier).checkSession();

      final client = WebSocketClient(
        cookieJar: cookieJar,
        ref: container.read(testClientRefProvider),
      );

      expect(client.currentBackoff, const Duration(seconds: 1));
      expect(WebSocketClient.initialBackoff, const Duration(seconds: 1));
      expect(WebSocketClient.maxBackoff, const Duration(seconds: 30));

      client.disconnect();
      container.dispose();
    });
  });
}

