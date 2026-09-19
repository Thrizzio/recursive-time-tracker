import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/timer/data/timer_storage.dart';
import 'package:app/features/timer/domain/timer_state.dart';
import 'package:app/features/timer/presentation/timer_controller.dart';
import 'package:app/features/timer/presentation/widgets/pomodoro_timer_card.dart';
import 'package:app/shared/theme/chronolog_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TimerState Model', () {
    test('default state initialized properly', () {
      const state = TimerState();
      expect(state.status, TimerStatus.stopped);
      expect(state.duration, const Duration(minutes: 25));
      expect(state.remainingDuration, const Duration(minutes: 25));
      expect(state.progress, 0.0);
      expect(state.endsAt, isNull);
      expect(state.pausedRemaining, isNull);
    });

    test('remainingDuration calculates accurate difference from endsAt', () {
      final now = DateTime.now();
      final endsAt = now.add(const Duration(minutes: 10));

      final state = TimerState(
        status: TimerStatus.running,
        duration: const Duration(minutes: 25),
        endsAt: endsAt,
      );

      final rem = state.remainingDuration;
      // Allow slight difference for execution time
      expect(rem.inMinutes, inInclusiveRange(9, 10));
      expect(state.progress, greaterThan(0.5));
    });

    test('remainingDuration returns zero when endsAt is in the past', () {
      final now = DateTime.now();
      final endsAt = now.subtract(const Duration(minutes: 5));

      final state = TimerState(
        status: TimerStatus.running,
        duration: const Duration(minutes: 25),
        endsAt: endsAt,
      );

      expect(state.remainingDuration, Duration.zero);
      expect(state.progress, 1.0);
    });

    test('remainingDuration returns pausedRemaining when paused', () {
      const state = TimerState(
        status: TimerStatus.paused,
        duration: Duration(minutes: 25),
        pausedRemaining: Duration(minutes: 14, seconds: 30),
      );

      expect(state.remainingDuration, const Duration(minutes: 14, seconds: 30));
    });

    test('serialization roundtrip preserves state', () {
      final endsAt = DateTime(2026, 9, 19, 18, 0, 0);
      final state = TimerState(
        status: TimerStatus.running,
        duration: const Duration(minutes: 50),
        endsAt: endsAt,
        activeTaskId: 'task_abc',
        activeTaskTitle: 'Deep Code Review',
      );

      final json = state.toJson();
      final restored = TimerState.fromJson(json);

      expect(restored.status, TimerStatus.running);
      expect(restored.duration, const Duration(minutes: 50));
      expect(restored.endsAt, endsAt);
      expect(restored.activeTaskId, 'task_abc');
      expect(restored.activeTaskTitle, 'Deep Code Review');
    });
  });

  group('TimerStorage', () {
    test('saves, loads, and clears TimerState to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = TimerStorage(prefs: prefs);

      expect(storage.loadState(), isNull);

      final endsAt = DateTime(2026, 9, 19, 18, 30);
      final state = TimerState(
        status: TimerStatus.running,
        duration: const Duration(minutes: 25),
        endsAt: endsAt,
        activeTaskTitle: 'Fix Bug',
      );

      await storage.saveState(state);

      final loaded = storage.loadState();
      expect(loaded, isNotNull);
      expect(loaded!.status, TimerStatus.running);
      expect(loaded.duration.inMinutes, 25);
      expect(loaded.activeTaskTitle, 'Fix Bug');

      await storage.clearState();
      expect(storage.loadState(), isNull);
    });
  });

  group('PomodoroNotifier Actions', () {
    late SharedPreferences prefs;

    setUp(() async {
      prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    test('starts focus session with endsAt in future', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final notifier = container.read(pomodoroTimerProvider.notifier);
      notifier.start();

      final state = container.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.running);
      expect(state.endsAt, isNotNull);
      expect(state.endsAt!.isAfter(DateTime.now()), isTrue);
    });

    test('pause and resume preserves remaining duration and recalculates endsAt', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final notifier = container.read(pomodoroTimerProvider.notifier);
      notifier.start();

      notifier.pause();
      final pausedState = container.read(pomodoroTimerProvider);
      expect(pausedState.status, TimerStatus.paused);
      expect(pausedState.pausedRemaining, isNotNull);
      expect(pausedState.endsAt, isNull);

      notifier.resume();
      final resumedState = container.read(pomodoroTimerProvider);
      expect(resumedState.status, TimerStatus.running);
      expect(resumedState.endsAt, isNotNull);
      expect(resumedState.pausedRemaining, isNull);
    });

    test('reset clears running timer back to stopped', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final notifier = container.read(pomodoroTimerProvider.notifier);
      notifier.start(taskTitle: 'Important task', taskId: 't1');

      notifier.reset();
      final state = container.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.stopped);
      expect(state.endsAt, isNull);
      expect(state.activeTaskTitle, isNull);
    });

    test('setDuration updates preset when stopped', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final notifier = container.read(pomodoroTimerProvider.notifier);
      notifier.setDuration(const Duration(minutes: 50));

      final state = container.read(pomodoroTimerProvider);
      expect(state.duration, const Duration(minutes: 50));
      expect(state.remainingDuration, const Duration(minutes: 50));
    });

    test('recovers completed status when loaded endsAt is in the past', () async {
      final storage = TimerStorage(prefs: prefs);
      // Pre-save a timer that expired 10 minutes ago
      final expiredEndsAt = DateTime.now().subtract(const Duration(minutes: 10));
      await storage.saveState(
        TimerState(
          status: TimerStatus.running,
          duration: const Duration(minutes: 25),
          endsAt: expiredEndsAt,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final state = container.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.completed);
      expect(state.endsAt, isNull);
    });
  });

  group('PomodoroTimerCard Widget', () {
    late SharedPreferences prefs;

    setUp(() async {
      prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    testWidgets('renders ready state, countdown, presets, and starts timer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ChronologTheme.darkTheme,
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
              ],
              child: const PomodoroTimerCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Focus Timer'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('25 min'), findsOneWidget);
      expect(find.text('50 min'), findsOneWidget);
      expect(find.text('Start Focus'), findsOneWidget);

      // Switch duration preset to 50 min
      await tester.tap(find.text('50 min'));
      await tester.pumpAndSettle();
      expect(find.text('50:00'), findsOneWidget);

      // Tap Start Focus
      await tester.tap(find.text('Start Focus'));
      await tester.pump();

      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });
  });
}
