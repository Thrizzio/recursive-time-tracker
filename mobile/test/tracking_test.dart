import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/activities/domain/activity_model.dart';
import 'package:app/features/tasks/domain/task_model.dart';
import 'package:app/features/tasks/presentation/tasks_controller.dart';
import 'package:app/features/tracking/data/tracking_repository.dart';
import 'package:app/features/tracking/domain/time_allocation_model.dart';
import 'package:app/features/tracking/domain/time_block_model.dart';
import 'package:app/features/tracking/domain/time_summary_model.dart';
import 'package:app/features/tracking/presentation/log_session_sheet.dart';
import 'package:app/features/tracking/presentation/tracking_controller.dart';
import 'package:app/features/tracking/presentation/widgets/allocation_bar.dart';
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

  group('Shared 100% Allocation Model & Boundary Transfer', () {
    test('buildEqualAllocations distributes 100% equally across activities with integer remainder', () {
      final allocs1 = buildEqualAllocations([1]);
      expect(allocs1.map((a) => a.percentage).toList(), [100]);

      final allocs2 = buildEqualAllocations([1, 2]);
      expect(allocs2.map((a) => a.percentage).toList(), [50, 50]);
      expect(allocs2.fold(0, (s, a) => s + a.percentage), 100);

      final allocs3 = buildEqualAllocations([1, 2, 3]);
      expect(allocs3.map((a) => a.percentage).toList(), [34, 33, 33]);
      expect(allocs3.fold(0, (s, a) => s + a.percentage), 100);

      final allocs4 = buildEqualAllocations([1, 2, 3, 4]);
      expect(allocs4.map((a) => a.percentage).toList(), [25, 25, 25, 25]);
      expect(allocs4.fold(0, (s, a) => s + a.percentage), 100);

      for (int n = 1; n <= 10; n++) {
        final ids = List.generate(n, (i) => i + 1);
        final allocs = buildEqualAllocations(ids);
        expect(allocs.length, n);
        expect(allocs.fold(0, (s, a) => s + a.percentage), 100);
      }
    });

    test('2 activities: boundary movement transfers allocation between adjacent activities and sums to 100%', () {
      final initial = [
        const AllocationItem(activityId: 1, percentage: 70),
        const AllocationItem(activityId: 2, percentage: 30),
      ];

      // Move divider 0 to left by 15%: Study becomes 55%, Development becomes 45%
      final moved = moveDivider(initial, 0, -15);
      expect(moved[0].percentage, 55);
      expect(moved[1].percentage, 45);
      expect(moved.fold(0, (s, a) => s + a.percentage), 100);

      // Move divider 0 to right by 10%: Study becomes 80%, Development becomes 20%
      final movedRight = moveDivider(initial, 0, 10);
      expect(movedRight[0].percentage, 80);
      expect(movedRight[1].percentage, 20);
      expect(movedRight.fold(0, (s, a) => s + a.percentage), 100);
    });

    test('3+ activities: boundary movement only affects the two immediately adjacent activities', () {
      final initial = [
        const AllocationItem(activityId: 1, percentage: 40),
        const AllocationItem(activityId: 2, percentage: 35),
        const AllocationItem(activityId: 3, percentage: 25),
      ];

      // Moving boundary 0 affects only Activity 1 and 2; Activity 3 is untouched
      final movedDivider0 = moveDivider(initial, 0, 10);
      expect(movedDivider0[0].percentage, 50); // 40 + 10
      expect(movedDivider0[1].percentage, 25); // 35 - 10
      expect(movedDivider0[2].percentage, 25); // untouched
      expect(movedDivider0.fold(0, (s, a) => s + a.percentage), 100);

      // Moving boundary 1 affects only Activity 2 and 3; Activity 1 is untouched
      final movedDivider1 = moveDivider(initial, 1, 10);
      expect(movedDivider1[0].percentage, 40); // untouched
      expect(movedDivider1[1].percentage, 45); // 35 + 10
      expect(movedDivider1[2].percentage, 15); // 25 - 10
      expect(movedDivider1.fold(0, (s, a) => s + a.percentage), 100);
    });

    test('enforces minimum 2% segment protection and prevents zero/negative allocations', () {
      final initial = [
        const AllocationItem(activityId: 1, percentage: 70),
        const AllocationItem(activityId: 2, percentage: 30),
      ];

      // Dragging far left (-100%): Left clamps to 2%, Right to 98%
      final clampedLeft = moveDivider(initial, 0, -100);
      expect(clampedLeft[0].percentage, 2);
      expect(clampedLeft[1].percentage, 98);
      expect(clampedLeft.fold(0, (s, a) => s + a.percentage), 100);

      // Dragging far right (+100%): Right clamps to 2%, Left to 98%
      final clampedRight = moveDivider(initial, 0, 100);
      expect(clampedRight[0].percentage, 98);
      expect(clampedRight[1].percentage, 2);
      expect(clampedRight.fold(0, (s, a) => s + a.percentage), 100);
    });

    test('successive boundary operations preserve 100% total allocation invariant', () {
      var current = buildEqualAllocations([1, 2, 3, 4]); // [25, 25, 25, 25]

      current = moveDivider(current, 0, 10); // [35, 15, 25, 25]
      expect(current.fold(0, (s, a) => s + a.percentage), 100);

      current = moveDivider(current, 1, -5); // [35, 10, 30, 25]
      expect(current.fold(0, (s, a) => s + a.percentage), 100);

      current = moveDivider(current, 2, 8); // [35, 10, 38, 17]
      expect(current.fold(0, (s, a) => s + a.percentage), 100);

      current = moveDivider(current, 0, -20); // [15, 30, 38, 17]
      expect(current.fold(0, (s, a) => s + a.percentage), 100);
    });
  });

  group('AllocationBar Widget Drag Interaction', () {
    const activities = [
      ActivityModel(id: 1, name: 'Study', color: '#22d3ee'),
      ActivityModel(id: 2, name: 'Development', color: '#a855f7'),
      ActivityModel(id: 3, name: 'Gym', color: '#10b981'),
    ];

    testWidgets('2 activities: renders single track with 1 draggable boundary and transfers allocation', (
      WidgetTester tester,
    ) async {
      var allocations = [
        const AllocationItem(activityId: 1, percentage: 70),
        const AllocationItem(activityId: 2, percentage: 30),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return AllocationBar(
                      activities: activities,
                      allocations: allocations,
                      onChanged: (updated) {
                        setState(() => allocations = updated);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Only 1 divider between 2 activities
      expect(find.byKey(const Key('allocation_divider_0')), findsOneWidget);
      expect(find.byKey(const Key('allocation_divider_1')), findsNothing);

      // Drag divider 0 by -45px (-15% on 300px bar): Study becomes 55%, Development becomes 45%
      await tester.drag(find.byKey(const Key('allocation_divider_0')), const Offset(-45, 0), touchSlopX: 0);
      await tester.pumpAndSettle();

      expect(allocations[0].percentage, 55);
      expect(allocations[1].percentage, 45);
      expect(allocations.fold(0, (s, a) => s + a.percentage), 100);

      // Drag divider 0 far right (+300px): Development clamps to minimum 2%
      await tester.drag(find.byKey(const Key('allocation_divider_0')), const Offset(300, 0), touchSlopX: 0);
      await tester.pumpAndSettle();

      expect(allocations[0].percentage, 98);
      expect(allocations[1].percentage, 2);
      expect(allocations.fold(0, (s, a) => s + a.percentage), 100);
    });

    testWidgets('3 activities: renders 2 boundaries and moving one boundary does not affect non-adjacent segment', (
      WidgetTester tester,
    ) async {
      var allocations = [
        const AllocationItem(activityId: 1, percentage: 40),
        const AllocationItem(activityId: 2, percentage: 35),
        const AllocationItem(activityId: 3, percentage: 25),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return AllocationBar(
                      activities: activities,
                      allocations: allocations,
                      onChanged: (updated) {
                        setState(() => allocations = updated);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('allocation_divider_0')), findsOneWidget);
      expect(find.byKey(const Key('allocation_divider_1')), findsOneWidget);

      // Drag divider 0 to right (+30px = +10% on 300px bar)
      await tester.drag(find.byKey(const Key('allocation_divider_0')), const Offset(30, 0), touchSlopX: 0);
      await tester.pumpAndSettle();

      expect(allocations[0].percentage, 50);
      expect(allocations[1].percentage, 25);
      expect(allocations[2].percentage, 25); // Activity 3 is completely untouched!
      expect(allocations.fold(0, (s, a) => s + a.percentage), 100);

      // Drag divider 1 to right (+30px = +10% on 300px bar)
      await tester.drag(find.byKey(const Key('allocation_divider_1')), const Offset(30, 0), touchSlopX: 0);
      await tester.pumpAndSettle();

      expect(allocations[0].percentage, 50); // Activity 1 is completely untouched!
      expect(allocations[1].percentage, 35);
      expect(allocations[2].percentage, 15);
      expect(allocations.fold(0, (s, a) => s + a.percentage), 100);
    });
  });

  group('LogSessionSheet Allocation Flow & Session Saving', () {
    late FakeTrackingRepo fakeRepo;

    setUp(() {
      fakeRepo = FakeTrackingRepo();
    });

    testWidgets('allocates 2 activities with single shared slider and saves session totaling 100%', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ChronologTheme.darkTheme,
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                trackingRepositoryProvider.overrideWithValue(fakeRepo),
                activitiesListProvider.overrideWith((ref) => fakeRepo.activities),
                tasksProvider.overrideWith((ref) async => <TaskModel>[]),
              ],
              child: const LogSessionSheet(elapsedDuration: Duration(minutes: 60)),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 0: Select Activities
      expect(find.text('Log Session: Select'), findsOneWidget);
      await tester.tap(find.text('Study'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Development'));
      await tester.pumpAndSettle();

      // Proceed to Step 1: Allocate
      await tester.tap(find.text('Next: Allocate (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Log Session: Allocate'), findsOneWidget);

      // Equal split initialized to 50/50
      expect(find.text('50%'), findsNWidgets(2));
      expect(find.text('Next: Review Tasks (100%)'), findsOneWidget);

      // 1 boundary divider present
      expect(find.byKey(const Key('allocation_divider_0')), findsOneWidget);

      // Drag boundary divider 0
      await tester.drag(find.byKey(const Key('allocation_divider_0')), const Offset(-40, 0), touchSlopX: 0);
      await tester.pumpAndSettle();

      // Total still remains exactly 100% on the action button
      expect(find.text('Next: Review Tasks (100%)'), findsOneWidget);

      // Tap Equal Split in header
      await tester.tap(find.text('Equal Split'));
      await tester.pumpAndSettle();

      // Restored to 50/50
      expect(find.text('50%'), findsNWidgets(2));
      expect(find.text('Next: Review Tasks (100%)'), findsOneWidget);

      // Proceed to Step 2: Tasks
      await tester.tap(find.text('Next: Review Tasks (100%)'));
      await tester.pumpAndSettle();

      expect(find.text('Log Session: Tasks'), findsOneWidget);

      // Save Time Block
      await tester.tap(find.text('Save Time Block'));
      await tester.pumpAndSettle();

      // Verifies backend received allocations summing to exactly 100%
      expect(fakeRepo.lastLoggedAllocations, isNotNull);
      expect(fakeRepo.lastLoggedAllocations!.length, 2);
      final total = fakeRepo.lastLoggedAllocations!.fold(0, (sum, a) => sum + (a['percentage'] as int));
      expect(total, 100);
      expect(fakeRepo.lastLoggedAllocations![0]['percentage'], 50);
      expect(fakeRepo.lastLoggedAllocations![1]['percentage'], 50);
    });

    testWidgets('allocates 3 activities with shared slider and saves session totaling 100%', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ChronologTheme.darkTheme,
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                trackingRepositoryProvider.overrideWithValue(fakeRepo),
                activitiesListProvider.overrideWith((ref) => fakeRepo.activities),
                tasksProvider.overrideWith((ref) async => <TaskModel>[]),
              ],
              child: const LogSessionSheet(elapsedDuration: Duration(minutes: 90)),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 0: Select Study, Development, and Gym
      await tester.tap(find.text('Study'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Development'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gym'));
      await tester.pumpAndSettle();

      // Proceed to Step 1: Allocate (3)
      await tester.tap(find.text('Next: Allocate (3)'));
      await tester.pumpAndSettle();

      // 3 activities equal split: 34% (Study) + 33% (Development) + 33% (Gym) = 100%
      expect(find.text('34%'), findsOneWidget);
      expect(find.text('33%'), findsNWidgets(2));
      expect(find.text('Next: Review Tasks (100%)'), findsOneWidget);

      // 2 boundary dividers present
      expect(find.byKey(const Key('allocation_divider_0')), findsOneWidget);
      expect(find.byKey(const Key('allocation_divider_1')), findsOneWidget);

      // Drag boundary divider 1
      await tester.drag(find.byKey(const Key('allocation_divider_1')), const Offset(20, 0), touchSlopX: 0);
      await tester.pumpAndSettle();

      // Total still remains 100%
      expect(find.text('Next: Review Tasks (100%)'), findsOneWidget);

      // Proceed to tasks and save
      await tester.tap(find.text('Next: Review Tasks (100%)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Time Block'));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastLoggedAllocations, isNotNull);
      expect(fakeRepo.lastLoggedAllocations!.length, 3);
      final total = fakeRepo.lastLoggedAllocations!.fold(0, (sum, a) => sum + (a['percentage'] as int));
      expect(total, 100);
    });
  });
}

class FakeTrackingRepo implements TrackingRepository {
  List<ActivityModel> activities = [
    const ActivityModel(id: 1, name: 'Study', color: '#22d3ee'),
    const ActivityModel(id: 2, name: 'Development', color: '#a855f7'),
    const ActivityModel(id: 3, name: 'Gym', color: '#10b981'),
  ];
  List<Map<String, dynamic>>? lastLoggedAllocations;

  @override
  Future<List<ActivityModel>> getActivities() async => activities;

  @override
  Future<TimeBlockModel> logSession({
    required List<Map<String, dynamic>> allocations,
  }) async {
    lastLoggedAllocations = allocations;
    return TimeBlockModel(
      id: 101,
      startTime: DateTime.now().subtract(const Duration(hours: 1)),
      endTime: DateTime.now(),
      createdAt: DateTime.now(),
      elapsedSeconds: 3600,
      allocations: allocations.map((a) {
        return TimeAllocationModel(
          activityId: a['activityId'] as int,
          percentage: a['percentage'] as int,
          durationSeconds: ((a['percentage'] as int) * 36),
        );
      }).toList(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

