/// Configuration for Chronolog API endpoints and networking parameters.
class ApiConfig {
  ApiConfig._();

  /// Base URL configured at build time via `--dart-define=API_URL=...`.
  /// Defaults to `http://10.0.2.2:3000` (Android emulator loopback to host).
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Default timeout for network connections.
  /// 60 seconds accommodates free-tier Render backend cold-starts.
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(seconds: 60);
}

