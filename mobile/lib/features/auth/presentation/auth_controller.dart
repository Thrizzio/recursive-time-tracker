import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';
import 'auth_state.dart';

/// Riverpod notifier managing global authentication state.
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Proactively verify existing session on boot
    Future.microtask(() => checkSession());
    return const AuthLoading(message: 'Checking existing session...');
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Validates session cookie with backend `GET /auth/me`.
  Future<void> checkSession() async {
    try {
      final user = await _repository.checkCurrentUser();
      if (!ref.mounted) return;
      if (user != null) {
        state = Authenticated(user);
      } else {
        state = const Unauthenticated();
      }
    } catch (e) {
      if (!ref.mounted) return;
      debugPrint('[AuthNotifier] Session verification error: $e');
      state = Unauthenticated(errorMessage: 'Unable to verify session: $e');
    }
  }

  /// Initiates interactive Google Sign-In and server auth code exchange.
  Future<void> signInWithGoogle() async {
    state = const AuthLoading(message: 'Signing in with Google...');
    try {
      final user = await _repository.signInWithGoogle();
      if (!ref.mounted) return;
      state = Authenticated(user);
    } catch (e) {
      if (!ref.mounted) return;
      debugPrint('[AuthNotifier] Sign-in failed: $e');
      state = Unauthenticated(errorMessage: e.toString());
    }
  }

  /// Logs out of server session and Google account, and resets state.
  Future<void> logout() async {
    state = const AuthLoading(message: 'Logging out...');
    try {
      await _repository.logout();
    } catch (e) {
      debugPrint('[AuthNotifier] Logout warning: $e');
    } finally {
      if (ref.mounted) {
        state = const Unauthenticated();
      }
    }
  }

  /// Called when an API request returns 401 Unauthorized outside of initial check.
  void handleSessionExpired([String? message]) {
    state = Unauthenticated(
      errorMessage: message ?? 'Session expired. Please log in again.',
    );
  }

  /// Updates authenticated user state locally (e.g. after setting task list preference).
  void updateUser(UserModel updated) {
    if (state is Authenticated) {
      state = Authenticated(updated);
    }
  }

  /// Refreshes user profile from backend without full auth reload screen.
  Future<void> refreshUser() async {
    try {
      final user = await _repository.checkCurrentUser();
      if (!ref.mounted) return;
      if (user != null) {
        state = Authenticated(user);
      }
    } catch (e) {
      debugPrint('[AuthNotifier] Refresh user error: $e');
    }
  }
}

