import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/tracking/domain/time_summary_model.dart';
import 'package:app/features/tracking/presentation/tracking_controller.dart';
import 'package:app/features/tracking/presentation/widgets/today_summary_card.dart';
import 'package:app/shared/theme/chronolog_theme.dart';

void main() {
  group("TodaySummaryCard Pixel Overflow Regression Tests", () {
    final screenWidths = [320.0, 360.0, 390.0, 412.0];

    for (final width in screenWidths) {
      testWidgets(
          'renders gracefully without overflow at width ${width}px with < 1m active tracking',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Scenario: Tracking immediately started (< 1 min elapsed)
        final summary = TimeSummaryModel(
          startDate: DateTime(2026, 9, 24),
          endDate: DateTime(2026, 9, 25),
          totalTrackedSeconds: 0,
          finalizedSeconds: 0,
          activeTrackingSeconds: 12,
          hasActiveTracking: true,
          activities: const [
            ActivitySummaryItem(
              id: 1,
              name: 'Feature Engineering & Pomodoro',
              color: '#22d3ee',
              totalSeconds: 0,
              percentage: 0,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ChronologTheme.darkTheme,
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: ProviderScope(
                  overrides: [
                    todaySummaryProvider.overrideWith((ref) => summary),
                  ],
                  child: const SingleChildScrollView(
                    child: TodaySummaryCard(),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Must not throw any RenderFlex overflow exceptions
        expect(tester.takeException(), isNull);

        // Verify active tracking chip displays seconds
        expect(find.text('+ 12s active'), findsOneWidget);
        expect(find.text('tracked today'), findsOneWidget);
      });

      testWidgets(
          'renders gracefully at width ${width}px when totalTracked is 45s (< 1m)',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final summary = TimeSummaryModel(
          startDate: DateTime(2026, 9, 24),
          endDate: DateTime(2026, 9, 25),
          totalTrackedSeconds: 45,
          finalizedSeconds: 45,
          activeTrackingSeconds: 30,
          hasActiveTracking: true,
          activities: const [
            ActivitySummaryItem(
              id: 1,
              name: 'Deep Work Development',
              color: '#22d3ee',
              totalSeconds: 45,
              percentage: 100,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ChronologTheme.darkTheme,
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: ProviderScope(
                  overrides: [
                    todaySummaryProvider.overrideWith((ref) => summary),
                  ],
                  child: const SingleChildScrollView(
                    child: TodaySummaryCard(),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('< 1m'), findsAtLeastNWidgets(1));
        expect(find.text('+ 30s active'), findsOneWidget);
      });

      testWidgets(
          'renders gracefully at width ${width}px with large durations (5h 45m)',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final summary = TimeSummaryModel(
          startDate: DateTime(2026, 9, 24),
          endDate: DateTime(2026, 9, 25),
          totalTrackedSeconds: 20700, // 5h 45m
          finalizedSeconds: 17100,
          activeTrackingSeconds: 3600, // 1h
          hasActiveTracking: true,
          activities: const [
            ActivitySummaryItem(
              id: 1,
              name: 'Deep Work Development',
              color: '#22d3ee',
              totalSeconds: 20700,
              percentage: 100,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ChronologTheme.darkTheme,
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: ProviderScope(
                  overrides: [
                    todaySummaryProvider.overrideWith((ref) => summary),
                  ],
                  child: const SingleChildScrollView(
                    child: TodaySummaryCard(),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('5h 45m'), findsAtLeastNWidgets(1));
        expect(find.text('+ 1h active'), findsOneWidget);
      });
    }
  });
}
