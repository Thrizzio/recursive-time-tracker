import 'package:flutter/foundation.dart';
import '../domain/user_model.dart';

/// Represents all states of authentication in the Chronolog mobile app.
@immutable
sealed class AuthState {
  const AuthState();
}

/// Initial state before any auth checks have started.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Active loading state (verifying session, signing in, logging out).
class AuthLoading extends AuthState {
  const AuthLoading({this.message});
  final String? message;
}

/// User is successfully authenticated with a valid session cookie.
class Authenticated extends AuthState {
  const Authenticated(this.user);
  final UserModel user;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Authenticated && runtimeType == other.runtimeType && user == other.user;

  @override
  int get hashCode => user.hashCode;
}

/// User is unauthenticated (logged out, session expired, or failed sign-in).
class Unauthenticated extends AuthState {
  const Unauthenticated({this.errorMessage});
  final String? errorMessage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Unauthenticated &&
          runtimeType == other.runtimeType &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => errorMessage.hashCode;
}

