import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/app.dart';
import 'package:app/core/networking/api_client.dart';
import 'package:app/features/auth/domain/user_model.dart';
import 'package:app/features/auth/presentation/auth_controller.dart';
import 'package:app/features/auth/presentation/auth_state.dart';

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(this.initialState);
  final AuthState initialState;

  @override
  AuthState build() => initialState;
}

void main() {
  testWidgets('Unauthenticated app launch redirects to LoginScreen', (
    WidgetTester tester,
  ) async {
    final testCookieJar = CookieJar();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cookieJarProvider.overrideWithValue(testCookieJar),
          authNotifierProvider.overrideWith(
            () => FakeAuthNotifier(const Unauthenticated()),
          ),
        ],
        child: const ChronologApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify LoginScreen is shown
    expect(find.text('CHRONOLOG'), findsOneWidget);
    expect(find.text('Log in to Chronolog'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('Authenticated app launch displays Dashboard with user profile', (
    WidgetTester tester,
  ) async {
    final testCookieJar = CookieJar();
    const testUser = UserModel(
      id: 42,
      email: 'tester@chronolog.app',
      name: 'Test Pilot',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cookieJarProvider.overrideWithValue(testCookieJar),
          authNotifierProvider.overrideWith(
            () => FakeAuthNotifier(const Authenticated(testUser)),
          ),
        ],
        child: const ChronologApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Dashboard with user details
    expect(find.text('Time Tracker'), findsOneWidget);
    expect(find.text('Test Pilot'), findsOneWidget);
    expect(find.text('tester@chronolog.app'), findsOneWidget);
    expect(find.text('Session Active'), findsOneWidget);
  });
}
