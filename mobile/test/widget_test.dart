import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/app.dart';
import 'package:app/core/networking/api_client.dart';

void main() {
  testWidgets('ChronologApp mounts and renders Dashboard', (
    WidgetTester tester,
  ) async {
    // Use an in-memory CookieJar for test environment
    final testCookieJar = CookieJar();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cookieJarProvider.overrideWithValue(testCookieJar),
        ],
        child: const ChronologApp(),
      ),
    );

    // Initial pump and settle for router
    await tester.pumpAndSettle();

    // Verify Chronolog header is rendered
    expect(find.text('CHRONOLOG'), findsWidgets);
    expect(find.text('Time Tracker'), findsOneWidget);
    expect(find.text('API Connection (Phase 2)'), findsOneWidget);
  });
}
