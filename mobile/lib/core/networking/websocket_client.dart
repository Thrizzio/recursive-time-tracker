import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/tasks/presentation/tasks_controller.dart';
import '../../features/tracking/presentation/tracking_controller.dart';
import 'api_client.dart';

/// Current lifecycle status of the WebSocket connection.
enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Pluggable signature for creating WebSocket connections (enables unit testing).
typedef WebSocketConnector = Future<WebSocket> Function(
  Uri uri,
  Map<String, dynamic>? headers,
);

/// WebSocket client managing user-scoped realtime communication with the Chronolog backend.
/// Handles session cookie handshake, auto-reconnect with exponential backoff,
/// event routing, and REST state resynchronization.
class WebSocketClient {
  WebSocketClient({
    required this.cookieJar,
    required this.ref,
    String? baseUrl,
    WebSocketConnector? connector,
  })  : _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _connector = connector ?? _defaultConnector;

  final CookieJar cookieJar;
  final Ref ref;
  final String _baseUrl;
  final WebSocketConnector _connector;

  static Future<WebSocket> _defaultConnector(
    Uri uri,
    Map<String, dynamic>? headers,
  ) {
    return WebSocket.connect(
      uri.toString(),
      headers: headers,
    );
  }

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;

  WebSocketStatus _status = WebSocketStatus.disconnected;
  WebSocketStatus get status => _status;

  final _statusController = StreamController<WebSocketStatus>.broadcast();
  Stream<WebSocketStatus> get statusStream => _statusController.stream;

  bool _isDisposed = false;
  bool _wasConnected = false;
  bool _isConnecting = false;

  // Backoff parameters
  static const Duration initialBackoff = Duration(seconds: 1);
  static const Duration maxBackoff = Duration(seconds: 30);
  Duration _currentBackoff = initialBackoff;
  Duration get currentBackoff => _currentBackoff;

  /// Transforms an HTTP/HTTPS API base URL into a WebSocket URI with `/ws` path.
  static Uri toWebSocketUri(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    final isSecure = uri.scheme == 'https' || uri.scheme == 'wss';
    final scheme = isSecure ? 'wss' : 'ws';

    var path = uri.path;
    if (path.isEmpty || path == '/') {
      path = '/ws';
    } else if (!path.endsWith('/ws')) {
      path = path.endsWith('/') ? '${path}ws' : '$path/ws';
    }

    return uri.replace(
      scheme: scheme,
      path: path,
    );
  }

  void _setStatus(WebSocketStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
      debugPrint('[WS] Status changed to: $newStatus');
    }
  }

  /// Initiates connection to WebSocket server.
  Future<void> connect() async {
    if (_isDisposed || _isConnecting) return;
    if (_socket != null && _status == WebSocketStatus.connected) return;

    _isConnecting = true;
    _setStatus(
      _wasConnected ? WebSocketStatus.reconnecting : WebSocketStatus.connecting,
    );

    try {
      // 1. Retrieve session cookie from CookieJar using HTTP base URL
      final cookies = await cookieJar.loadForRequest(Uri.parse(_baseUrl));
      final sessionCookie = cookies.cast<Cookie?>().firstWhere(
            (c) => c?.name == 'chronolog_session',
            orElse: () => null,
          );

      if (sessionCookie == null) {
        debugPrint('[WS] No chronolog_session cookie found; aborting connection.');
        _setStatus(WebSocketStatus.disconnected);
        _isConnecting = false;
        return;
      }

      final cookieHeader =
          cookies.map((c) => '${c.name}=${c.value}').join('; ');
      final wsUri = toWebSocketUri(_baseUrl);

      debugPrint('[WS] Connecting to $wsUri with session cookie...');

      final headers = <String, dynamic>{
        'Cookie': cookieHeader,
      };

      // 2. Perform WebSocket handshake
      _socket = await _connector(wsUri, headers).timeout(
        const Duration(seconds: 15),
      );

      _setStatus(WebSocketStatus.connected);
      _isConnecting = false;

      // If reconnecting after a dropped connection, fetch authoritative REST state
      if (_wasConnected) {
        debugPrint('[WS] Reconnected successfully. Triggering REST resync...');
        await resync();
      }

      _wasConnected = true;
      _currentBackoff = initialBackoff;

      // 3. Listen to incoming messages and socket events
      _subscription = _socket!.listen(
        _onMessageReceived,
        onError: (error) {
          debugPrint('[WS] Socket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[WS] Socket connection closed by server');
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[WS] Connection attempt failed: $e');
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  void _onMessageReceived(dynamic message) {
    try {
      final text = message is String ? message : utf8.decode(message as List<int>);
      handleRawMessage(text);
    } catch (e) {
      debugPrint('[WS] Error processing incoming message: $e');
    }
  }

  /// Parses and routes raw JSON message payload.
  void handleRawMessage(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final event = decoded['event'] as String?;
      final data = decoded['data'] as Map<String, dynamic>?;

      if (event != null) {
        handleEvent(event, data);
      }
    } catch (e) {
      debugPrint('[WS] Invalid message JSON: $rawJson ($e)');
    }
  }

  /// Dispatches structured WebSocket event to application state.
  void handleEvent(String event, Map<String, dynamic>? data) {
    debugPrint('[WS] Event received: $event (payload: $data)');

    switch (event) {
      case 'connected':
        debugPrint('[WS] Authenticated connection acknowledged for user: ${data?['userId']}');
        break;

      case 'tracking.started':
        final startedAtStr = data?['trackingStartedAt'] as String?;
        final startedAt =
            startedAtStr != null ? DateTime.tryParse(startedAtStr) : null;
        if (startedAt != null) {
          _updateTrackingState(startedAt);
        }
        break;

      case 'tracking.reset':
        _updateTrackingState(null);
        break;

      case 'time-block.created':
        final startedAtStr = data?['trackingStartedAt'] as String?;
        final startedAt =
            startedAtStr != null ? DateTime.tryParse(startedAtStr) : null;
        _updateTrackingState(startedAt);

        // Invalidate time blocks and summary
        ref.invalidate(todaySummaryProvider);
        ref.invalidate(todayTimeBlocksProvider);
        ref.read(authNotifierProvider.notifier).refreshUser();
        break;

      case 'task.completed':
        ref.invalidate(tasksProvider);
        break;

      default:
        debugPrint('[WS] Unhandled event type: $event');
    }
  }

  void _updateTrackingState(DateTime? startedAt) {
    final authState = ref.read(authNotifierProvider);
    if (authState is Authenticated) {
      ref.read(authNotifierProvider.notifier).updateUser(
            authState.user.copyWith(
              trackingStartedAt: startedAt,
              clearTrackingStartedAt: startedAt == null,
            ),
          );
    }

    ref
        .read(trackingControllerProvider.notifier)
        .setTrackingStartedAt(startedAt);

    ref.invalidate(todaySummaryProvider);
  }

  /// Fetches authoritative state from REST endpoints and invalidates cached providers.
  Future<void> resync() async {
    try {
      debugPrint('[WS] Executing REST resync across modules...');
      await ref.read(authNotifierProvider.notifier).refreshUser();
      ref.invalidate(todaySummaryProvider);
      ref.invalidate(todayTimeBlocksProvider);
      ref.invalidate(tasksProvider);
    } catch (e) {
      debugPrint('[WS] Error during REST resync: $e');
    }
  }

  void _handleDisconnect() {
    _cleanupSocket();

    if (_isDisposed) return;

    _setStatus(WebSocketStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    // Check if user is still authenticated before scheduling reconnect
    final authState = ref.read(authNotifierProvider);
    if (authState is! Authenticated) {
      debugPrint('[WS] User is not authenticated; skipping reconnect.');
      return;
    }

    debugPrint('[WS] Reconnecting in ${_currentBackoff.inSeconds}s (backoff)...');
    _setStatus(WebSocketStatus.reconnecting);

    _reconnectTimer = Timer(_currentBackoff, () {
      connect();
    });

    // Exponential backoff calculation: min(current * 2, maxBackoff)
    final nextSeconds = math.min(
      _currentBackoff.inSeconds * 2,
      maxBackoff.inSeconds,
    );
    _currentBackoff = Duration(seconds: nextSeconds == 0 ? 1 : nextSeconds);
  }

  /// Called when application transitions to foreground (`AppLifecycleState.resumed`).
  Future<void> handleAppResumed() async {
    final authState = ref.read(authNotifierProvider);
    if (authState is! Authenticated) return;

    debugPrint('[WS] App resumed from background. Checking connection status...');

    // If disconnected or socket is dead, reconnect immediately with reset backoff
    if (_status != WebSocketStatus.connected || _socket == null) {
      _reconnectTimer?.cancel();
      _currentBackoff = initialBackoff;
      await connect();
    }

    // Resync REST state on foregrounding
    await resync();
  }

  void _cleanupSocket() {
    try {
      _subscription?.cancel();
      _subscription = null;
      _socket?.close();
      _socket = null;
    } catch (e) {
      debugPrint('[WS] Error cleaning up socket: $e');
    }
  }

  /// Explicitly disconnects and halts reconnect attempts (e.g. on logout).
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _wasConnected = false;
    _currentBackoff = initialBackoff;
    _cleanupSocket();
    _setStatus(WebSocketStatus.disconnected);
    debugPrint('[WS] Disconnected explicitly.');
  }

  /// Cleans up all resources on disposal.
  void dispose() {
    _isDisposed = true;
    disconnect();
    _statusController.close();
  }
}

/// Provider for the [WebSocketClient] singleton.
final webSocketClientProvider = Provider<WebSocketClient>((ref) {
  final cookieJar = ref.watch(cookieJarProvider);
  final client = WebSocketClient(
    cookieJar: cookieJar,
    ref: ref,
  );
  ref.onDispose(() => client.dispose());
  return client;
});

/// Bridge provider that automatically connects/disconnects [WebSocketClient]
/// in response to authentication lifecycle changes.
final webSocketSyncProvider = Provider<void>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final wsClient = ref.watch(webSocketClientProvider);

  if (authState is Authenticated) {
    wsClient.connect();
  } else if (authState is Unauthenticated) {
    wsClient.disconnect();
  }
});
