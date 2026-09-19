import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/activities/domain/activity_model.dart';
import 'package:app/features/tracking/domain/time_allocation_model.dart';
import 'package:app/features/tracking/domain/time_block_model.dart';
import 'package:app/features/tracking/domain/time_summary_model.dart';
import 'package:app/features/tracking/presentation/tracking_controller.dart';
import 'package:app/features/tracking/presentation/widgets/live_tracking_card.dart';
import 'package:app/features/tracking/presentation/widgets/today_summary_card.dart';
import 'package:app/features/tracking/presentation/widgets/today_timeline_card.dart';
import 'package:app/shared/theme/chronolog_theme.dart';
import 'package:app/shared/utils/color_utils.dart';
import 'package:app/shared/utils/time_utils.dart';

void main() {
  group('TimeUtils Tests', () {
    test('formatDigital formats seconds properly', () {
      expect(TimeUtils.formatDigital(0), '00:00');
      expect(TimeUtils.formatDigital(59), '00:59');
      expect(TimeUtils.formatDigital(65), '01:05');
      expect(TimeUtils.formatDigital(3665), '01:01:05');
    });

    test('formatHumanShort formats human descriptions', () {
      expect(TimeUtils.formatHumanShort(0), 'less than a minute');
      expect(TimeUtils.formatHumanShort(45), 'less than a minute');
      expect(TimeUtils.formatHumanShort(120), '2m');
      expect(TimeUtils.formatHumanShort(3600), '1h');
      expect(TimeUtils.formatHumanShort(5400), '1h 30m');
    });

    test('startOfDay and endOfDay create accurate day window', () {
      final dt = DateTime(2026, 9, 19, 14, 30, 45);
      final start = TimeUtils.startOfDay(dt);
      final end = TimeUtils.endOfDay(dt);

      expect(start.hour, 0);
      expect(start.minute, 0);
      expect(start.second, 0);
      expect(end.difference(start), const Duration(days: 1));
    });
  });

  group('ColorUtils Tests', () {
    test('parses 6-digit hex and 3-digit hex strings', () {
      expect(ColorUtils.parseHexColor('#22D3EE'), const Color(0xFF22D3EE));
      expect(ColorUtils.parseHexColor('22D3EE'), const Color(0xFF22D3EE));
      expect(ColorUtils.parseHexColor('#FFF'), const Color(0xFFFFFFFF));
    });

    test('falls back safely on invalid colors', () {
      const fallback = ChronologTheme.cyan400;
      expect(ColorUtils.parseHexColor(null, fallback: fallback), fallback);
      expect(ColorUtils.parseHexColor('', fallback: fallback), fallback);
      expect(ColorUtils.parseHexColor('invalid-color', fallback: fallback), fallback);
    });
  });

  group('Tracking Models Tests', () {
    test('ActivityModel deserializes and serializes JSON', () {
      final json = {
        'id': 10,
        'name': 'Deep Work',
        'color': '#3b82f6',
        'userId': 1,
      };

      final act = ActivityModel.fromJson(json);
      expect(act.id, 10);
      expect(act.name, 'Deep Work');
      expect(act.color, '#3b82f6');
      expect(act.userId, 1);
    });

    test('TimeBlockModel and TimeAllocationModel parse nested structure', () {
      final json = {
        'id': 101,
        'startTime': '2026-09-19T10:00:00.000Z',
        'endTime': '2026-09-19T11:00:00.000Z',
        'createdAt': '2026-09-19T11:00:05.000Z',
        'elapsedSeconds': 3600,
        'allocations': [
          {
            'id': 1,
            'activityId': 10,
            'percentage': 60,
            'durationSeconds': 2160,
            'activity': {
              'id': 10,
              'name': 'Coding',
              'color': '#06b6d4',
            },
          },
          {
            'id': 2,
            'activityId': 11,
            'percentage': 40,
            'durationSeconds': 1440,
            'activity': {
              'id': 11,
              'name': 'Reading',
              'color': '#10b981',
            },
          },
        ],
      };

      final block = TimeBlockModel.fromJson(json);
      expect(block.id, 101);
      expect(block.elapsedSeconds, 3600);
      expect(block.allocations.length, 2);
      expect(block.allocations[0].percentage, 60);
      expect(block.allocations[0].activity?.name, 'Coding');
      expect(block.allocations[1].percentage, 40);
      expect(block.allocations[1].activity?.name, 'Reading');
    });

    test('TimeSummaryModel parses aggregated daily breakdown', () {
      final json = {
        'startDate': '2026-09-19T00:00:00.000Z',
        'endDate': '2026-09-20T00:00:00.000Z',
        'totalTrackedSeconds': 5400,
        'finalizedSeconds': 3600,
        'activeTrackingSeconds': 1800,
        'hasActiveTracking': true,
        'activeTrackingStartedAt': '2026-09-19T11:00:00.000Z',
        'activities': [
          {
            'id': 10,
            'name': 'Coding',
            'color': '#06b6d4',
            'totalSeconds': 3600,
            'percentage': 67,
          },
        ],
      };

      final summary = TimeSummaryModel.fromJson(json);
      expect(summary.totalTrackedSeconds, 5400);
      expect(summary.hasActiveTracking, isTrue);
      expect(summary.activities.length, 1);
      expect(summary.activities.first.name, 'Coding');
      expect(summary.activities.first.percentage, 67);
    });
  });

  group('Equal Allocation Algorithm', () {
    List<int> buildEqualAllocations(int n) {
      if (n == 0) return [];
      final base = 100 ~/ n;
      final remainder = 100 - (base * n);
      return List.generate(n, (i) => base + (i == 0 ? remainder : 0));
    }

    test('guarantees allocations sum to 100% across arbitrary item counts', () {
      for (int n = 1; n <= 10; n++) {
        final allocs = buildEqualAllocations(n);
        expect(allocs.length, n);
        expect(allocs.reduce((a, b) => a + b), 100);
      }
      expect(buildEqualAllocations(1), [100]);
      expect(buildEqualAllocations(2), [50, 50]);
      expect(buildEqualAllocations(3), [34, 33, 33]);
      expect(buildEqualAllocations(4), [25, 25, 25, 25]);
    });
  });

  group('Tracking Widget Tests', () {
    testWidgets('LiveTrackingCard renders READY TO TRACK state when idle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ChronologTheme.darkTheme,
          home: const Scaffold(
            body: ProviderScope(
              child: LiveTrackingCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('READY TO TRACK'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('Start Tracking'), findsOneWidget);
    });

    testWidgets('TodaySummaryCard renders daily summary and activity progress', (
      WidgetTester tester,
    ) async {
      final summary = TimeSummaryModel(
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        totalTrackedSeconds: 7200,
        finalizedSeconds: 7200,
        activeTrackingSeconds: 0,
        hasActiveTracking: false,
        activities: const [
          ActivitySummaryItem(
            id: 1,
            name: 'Engineering',
            color: '#22d3ee',
            totalSeconds: 5400,
            percentage: 75,
          ),
          ActivitySummaryItem(
            id: 2,
            name: 'Planning',
            color: '#34d399',
            totalSeconds: 1800,
            percentage: 25,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ChronologTheme.darkTheme,
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                todaySummaryProvider.overrideWith((ref) => summary),
              ],
              child: const TodaySummaryCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Today's Summary"), findsOneWidget);
      expect(find.text('2h'), findsOneWidget);
      expect(find.text('Engineering'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('Planning'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('TodayTimelineCard renders time blocks and duration pills', (
      WidgetTester tester,
    ) async {
      final blocks = [
        TimeBlockModel(
          id: 1,
          startTime: DateTime(2026, 9, 19, 10, 0),
          endTime: DateTime(2026, 9, 19, 11, 30),
          createdAt: DateTime(2026, 9, 19, 11, 30),
          elapsedSeconds: 5400,
          allocations: const [
            TimeAllocationModel(
              id: 1,
              activityId: 1,
              percentage: 100,
              durationSeconds: 5400,
              activity: ActivityModel(
                id: 1,
                name: 'Sprint Execution',
                color: '#22d3ee',
              ),
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ChronologTheme.darkTheme,
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                todayTimeBlocksProvider.overrideWith((ref) => blocks),
              ],
              child: const TodayTimelineCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Today's Timeline"), findsOneWidget);
      expect(find.text('1h 30m'), findsOneWidget);
      expect(find.text('Sprint Execution'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });
  });
}
