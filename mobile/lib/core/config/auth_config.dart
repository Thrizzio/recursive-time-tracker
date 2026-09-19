/// Configuration for Google OAuth authentication.
class AuthConfig {
  AuthConfig._();

  /// Google OAuth Web Client ID passed via `--dart-define=SERVER_CLIENT_ID=...`.
  /// Must match the backend's `GOOGLE_CLIENT_ID`.
  static const String serverClientId = String.fromEnvironment('SERVER_CLIENT_ID');

  /// Google OAuth scopes required by Chronolog:
  /// - User profile and email for identity
  /// - Google Tasks for reading and completing synced tasks
  /// - Google Calendar (read-only) for event context
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/userinfo.profile',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/tasks',
    'https://www.googleapis.com/auth/calendar.readonly',
  ];
}

