import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/auth_config.dart';
import 'package:app/features/auth/domain/user_model.dart';
import 'package:app/features/auth/presentation/auth_state.dart';

void main() {
  group('AuthConfig Tests', () {
    test('contains required Google OAuth scopes', () {
      expect(AuthConfig.scopes, contains('https://www.googleapis.com/auth/userinfo.profile'));
      expect(AuthConfig.scopes, contains('https://www.googleapis.com/auth/userinfo.email'));
      expect(AuthConfig.scopes, contains('https://www.googleapis.com/auth/tasks'));
      expect(AuthConfig.scopes, contains('https://www.googleapis.com/auth/calendar.readonly'));
    });
  });

  group('UserModel Serialization', () {
    test('parses complete user JSON successfully', () {
      final json = {
        'id': 123,
        'email': 'developer@chronolog.app',
        'name': 'Developer',
        'avatarUrl': 'https://example.com/photo.jpg',
        'trackingStartedAt': '2026-09-19T10:30:00.000Z',
        'selectedTaskListId': 'task_list_alpha',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 123);
      expect(user.email, 'developer@chronolog.app');
      expect(user.name, 'Developer');
      expect(user.avatarUrl, 'https://example.com/photo.jpg');
      expect(user.trackingStartedAt, isNotNull);
      expect(user.selectedTaskListId, 'task_list_alpha');

      final serialized = user.toJson();
      expect(serialized['id'], 123);
      expect(serialized['email'], 'developer@chronolog.app');
      expect(serialized['name'], 'Developer');
      expect(serialized['avatarUrl'], 'https://example.com/photo.jpg');
      expect(serialized['selectedTaskListId'], 'task_list_alpha');
    });

    test('handles null optional fields gracefully', () {
      final json = {
        'id': 1,
        'email': 'user@example.com',
        'name': 'User',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 1);
      expect(user.email, 'user@example.com');
      expect(user.name, 'User');
      expect(user.avatarUrl, isNull);
      expect(user.trackingStartedAt, isNull);
      expect(user.selectedTaskListId, isNull);
    });

    test('equality and hashCode match identical data', () {
      const u1 = UserModel(id: 1, email: 'a@b.com', name: 'A');
      const u2 = UserModel(id: 1, email: 'a@b.com', name: 'A');
      const u3 = UserModel(id: 2, email: 'b@b.com', name: 'B');

      expect(u1, equals(u2));
      expect(u1.hashCode, equals(u2.hashCode));
      expect(u1, isNot(equals(u3)));
    });
  });

  group('AuthState Tests', () {
    test('verifies state hierarchy and equality', () {
      const initial = AuthInitial();
      const loading = AuthLoading(message: 'Loading...');
      const user = UserModel(id: 1, email: 'test@example.com', name: 'Test');
      const authenticated = Authenticated(user);
      const unauthenticated = Unauthenticated(errorMessage: 'Expired');

      expect(initial, isA<AuthState>());
      expect(loading, isA<AuthState>());
      expect(authenticated, isA<AuthState>());
      expect(unauthenticated, isA<AuthState>());

      expect(authenticated.user, equals(user));
      expect(unauthenticated.errorMessage, 'Expired');
    });
  });
}

