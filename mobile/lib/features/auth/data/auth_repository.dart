import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/config/auth_config.dart';
import '../../../core/networking/api_client.dart';
import '../domain/user_model.dart';

/// Provider for AuthRepository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient: apiClient);
});

/// Repository coordinating Google Sign-In and Chronolog session management.
class AuthRepository {
  AuthRepository({
    required this.apiClient,
    GoogleSignIn? googleSignIn,
  }) : googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final ApiClient apiClient;
  final GoogleSignIn googleSignIn;
  bool _initialized = false;

  /// Initializes the singleton [GoogleSignIn] instance with [AuthConfig.serverClientId].
  /// Must be called once before any sign-in operations.
  Future<void> initGoogleSignIn() async {
    if (_initialized) return;
    try {
      final serverClientId = AuthConfig.serverClientId.trim();
      await googleSignIn.initialize(
        serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('[AuthRepository] GoogleSignIn.initialize error: $e');
    }
  }

  /// Verifies current session with backend `GET /auth/me`.
  /// Returns [UserModel] if authenticated, or `null` if unauthenticated/expired.
  Future<UserModel?> checkCurrentUser() async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>('/auth/me');
      if (response.statusCode == 200 && response.data != null) {
        return UserModel.fromJson(response.data!);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint('[AuthRepository] Session missing or expired (401)');
        return null;
      }
      debugPrint('[AuthRepository] Check user failed with DioException: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[AuthRepository] Check user unexpected error: $e');
      return null;
    }
  }

  /// Interactive Google Sign-In using v7 `authenticate()` and `authorizeServer()`.
  /// Exchanges `serverAuthCode` via backend `POST /auth/mobile/google`.
  Future<UserModel> signInWithGoogle() async {
    await initGoogleSignIn();

    if (AuthConfig.serverClientId.trim().isEmpty) {
      throw StateError(
        'SERVER_CLIENT_ID is not configured. Run the app with:\n'
        '--dart-define=SERVER_CLIENT_ID=<WebClientIdFromEnv>',
      );
    }

    // Step 1: Interactive authentication (v7)
    final account = await googleSignIn.authenticate();

    // Step 2: Request server authorization code for required backend scopes
    final serverAuth = await account.authorizationClient.authorizeServer(AuthConfig.scopes);
    final code = serverAuth?.serverAuthCode;

    if (code == null || code.isEmpty) {
      throw StateError(
        'Failed to obtain server authorization code from Google. '
        'Please ensure the Google Web Client ID is correctly configured.',
      );
    }

    // Step 3: Send { code } to backend POST /auth/mobile/google
    // Dio automatically persists the session cookie into the CookieJar
    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/mobile/google',
      data: {'code': code},
    );

    final data = response.data;
    if (data == null || data['user'] == null) {
      throw StateError('Invalid authentication response received from server.');
    }

    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Logs out of Chronolog session and Google Sign-In, and clears persisted cookies.
  Future<void> logout() async {
    try {
      await apiClient.post('/auth/logout');
    } catch (e) {
      debugPrint('[AuthRepository] Server logout warning: $e');
    }

    try {
      await googleSignIn.signOut();
    } catch (e) {
      debugPrint('[AuthRepository] Google signOut warning: $e');
    }

    try {
      await apiClient.cookieJar.deleteAll();
    } catch (e) {
      debugPrint('[AuthRepository] Cookie cleanup warning: $e');
    }
  }
}

