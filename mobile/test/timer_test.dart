import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/networking/api_client.dart';
import 'package:app/features/timer/data/pomodoro_repository.dart';
import 'package:app/features/timer/data/timer_storage.dart';
import 'package:app/features/timer/domain/pomodoro_model.dart';
import 'package:app/features/timer/domain/timer_state.dart';
import 'package:app/features/timer/presentation/timer_controller.dart';
import 'package:app/features/timer/presentation/widgets/pomodoro_timer_card.dart';
import 'package:app/shared/theme/chronolog_theme.dart';
import 'package:app/shared/utils/time_utils.dart';

class FakePomodoroRepository implements PomodoroRepository {
  PomodoroPlanModel? currentPlan;

  @override
  ApiClient get apiClient => throw UnimplementedError();

  @override
  Future<PomodoroPlanModel?> getCurrentPlan() async => currentPlan;

  @override
  Future<PomodoroPlanModel> startPlan({
    int totalSessions = 4,
    int focusDurationSeconds = 1500,
    int shortBreakDurationSeconds = 300,
    int longBreakDurationSeconds = 900,
    int longBreakInterval = 4,
    bool autoStartBreaks = false,
    bool autoStartFocus = false,
    String? taskId,
    String? taskTitle,
  }) async {
    final now = TimeUtils.now();
    final plan = PomodoroPlanModel(
      id: 1,
      userId: 1,
      status: 'focus',
      currentPhase: 'focus',
      currentSession: 1,
      totalSessions: totalSessions,
      focusDurationSeconds: focusDurationSeconds,
      shortBreakDurationSeconds: shortBreakDurationSeconds,
      longBreakDurationSeconds: longBreakDurationSeconds,
      longBreakInterval: longBreakInterval,
      autoStartBreaks: autoStartBreaks,
      autoStartFocus: autoStartFocus,
      phaseStartedAt: now,
      phaseEndsAt: now.add(Duration(seconds: focusDurationSeconds)),
      taskId: taskId,
      taskTitle: taskTitle,
      startedAt: now,
    );
    currentPlan = plan;
    return plan;
  }

  @override
  Future<PomodoroPlanModel> pausePlan([int? planId]) async {
    final now = TimeUtils.now();
    final p = currentPlan!;
    final remaining = p.remainingDuration.inSeconds;
    final updated = p.copyWith(
      status: 'paused',
      pausedAt: now,
      pausedRemainingSeconds: remaining,
      phaseStartedAt: null,
      phaseEndsAt: null,
    );
    currentPlan = updated;
    return updated;
  }

  @override
  Future<PomodoroPlanModel> resumePlan([int? planId]) async {
    final now = TimeUtils.now();
    final p = currentPlan!;
    final remaining = p.pausedRemainingSeconds ?? p.focusDurationSeconds;
    final updated = p.copyWith(
      status: p.currentPhase,
      phaseStartedAt: now,
      phaseEndsAt: now.add(Duration(seconds: remaining)),
      pausedAt: null,
      pausedRemainingSeconds: null,
    );
    currentPlan = updated;
    return updated;
  }

  @override
  Future<PomodoroPlanModel> nextPhase([int? planId]) async {
    final p = currentPlan!;
    final updated = p.copyWith(currentPhase: 'shortBreak', status: 'shortBreak');
    currentPlan = updated;
    return updated;
  }

  @override
  Future<PomodoroPlanModel> skipPhase([int? planId]) async {
    final p = currentPlan!;
    final updated = p.copyWith(currentPhase: 'shortBreak', status: 'shortBreak');
    currentPlan = updated;
    return updated;
  }

  @override
  Future<PomodoroPlanModel> cancelPlan([int? planId]) async {
    final p = currentPlan!;
    final updated = p.copyWith(status: 'cancelled');
    currentPlan = updated;
    return updated;
  }
}

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

  group('PomodoroPlanModel', () {
    test('serialization roundtrip preserves all fields', () {
      final startedAt = DateTime(2026, 9, 25, 8, 0, 0);
      final endsAt = startedAt.add(const Duration(minutes: 25));

      final plan = PomodoroPlanModel(
        id: 42,
        userId: 1,
        status: 'focus',
        currentPhase: 'focus',
        currentSession: 1,
        totalSessions: 4,
        focusDurationSeconds: 1500,
        shortBreakDurationSeconds: 300,
        longBreakDurationSeconds: 900,
        longBreakInterval: 4,
        autoStartBreaks: true,
        autoStartFocus: false,
        phaseStartedAt: startedAt,
        phaseEndsAt: endsAt,
        totalFocusSeconds: 120,
        totalBreakSeconds: 60,
        totalPausedSeconds: 30,
        completedSessions: 1,
        taskId: 'task_1',
        taskTitle: 'Important task',
        startedAt: startedAt,
      );

      final json = plan.toJson();
      final restored = PomodoroPlanModel.fromJson(json);

      expect(restored.id, 42);
      expect(restored.status, 'focus');
      expect(restored.currentPhase, 'focus');
      expect(restored.totalSessions, 4);
      expect(restored.totalFocusSeconds, 120);
      expect(restored.totalBreakSeconds, 60);
      expect(restored.totalPausedSeconds, 30);
      expect(restored.autoStartBreaks, isTrue);
      expect(restored.autoStartFocus, isFalse);
      expect(restored.taskTitle, 'Important task');
    });

    test('strictly segregates live focus, break, and paused times', () {
      final fixedNow = DateTime(2026, 9, 25, 10, 0, 0);
      TimeUtils.clock = () => fixedNow;
      addTearDown(() => TimeUtils.clock = DateTime.now);

      // Active focus session started 60s ago
      final focusPlan = PomodoroPlanModel(
        id: 1,
        userId: 1,
        status: 'focus',
        currentPhase: 'focus',
        currentSession: 1,
        totalSessions: 4,
        focusDurationSeconds: 1500,
        shortBreakDurationSeconds: 300,
        longBreakDurationSeconds: 900,
        longBreakInterval: 4,
        autoStartBreaks: false,
        autoStartFocus: false,
        phaseStartedAt: fixedNow.subtract(const Duration(seconds: 60)),
        phaseEndsAt: fixedNow.add(const Duration(seconds: 1440)),
        totalFocusSeconds: 200,
        totalBreakSeconds: 100,
        totalPausedSeconds: 50,
        startedAt: fixedNow.subtract(const Duration(minutes: 10)),
      );

      // Live focus time includes 200s accumulated + 60s active = 260s
      expect(focusPlan.liveFocusSeconds, 260);
      // Break and Paused times remain unchanged
      expect(focusPlan.liveBreakSeconds, 100);
      expect(focusPlan.livePausedSeconds, 50);

      // Paused session paused 40s ago: paused time accumulates, focus & break DO NOT
      final pausedPlan = focusPlan.copyWith(
        status: 'paused',
        pausedAt: fixedNow.subtract(const Duration(seconds: 40)),
        pausedRemainingSeconds: 1440,
        phaseStartedAt: null,
        phaseEndsAt: null,
      );

      expect(pausedPlan.liveFocusSeconds, 200);
      expect(pausedPlan.liveBreakSeconds, 100);
      expect(pausedPlan.livePausedSeconds, 90); // 50s + 40s
    });
  });

  group('TimerStorage', () {
    test('saves, loads, and clears PomodoroPlanModel', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = TimerStorage(prefs: prefs);

      expect(storage.loadPlan(), isNull);

      final plan = PomodoroPlanModel(
        id: 10,
        userId: 2,
        status: 'focus',
        currentPhase: 'focus',
        currentSession: 1,
        totalSessions: 4,
        focusDurationSeconds: 1500,
        shortBreakDurationSeconds: 300,
        longBreakDurationSeconds: 900,
        longBreakInterval: 4,
        autoStartBreaks: false,
        autoStartFocus: false,
        startedAt: DateTime.now(),
      );

      await storage.savePlan(plan);
      final loaded = storage.loadPlan();
      expect(loaded, isNotNull);
      expect(loaded!.id, 10);
      expect(loaded.status, 'focus');

      await storage.clearPlan();
      expect(storage.loadPlan(), isNull);
    });
  });

  group('PomodoroNotifier Actions', () {
    late SharedPreferences prefs;
    late FakePomodoroRepository fakeRepo;

    setUp(() async {
      prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      fakeRepo = FakePomodoroRepository();
    });

    test('startPlan creates plan and sets state', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          pomodoroRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final notifier = container.read(pomodoroTimerProvider.notifier);
      await notifier.startPlan(
        totalSessions: 4,
        focusDurationSeconds: 1500,
        taskTitle: 'Writing Tests',
      );

      final state = container.read(pomodoroTimerProvider);
      expect(state, isNotNull);
      expect(state!.status, 'focus');
      expect(state.currentSession, 1);
      expect(state.taskTitle, 'Writing Tests');
      expect(state.remainingDuration.inMinutes, inInclusiveRange(24, 25));
    });

    test('pause and resume toggles paused state and remaining duration', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          pomodoroRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final notifier = container.read(pomodoroTimerProvider.notifier);
      await notifier.startPlan(focusDurationSeconds: 1500);

      await notifier.pause();
      final paused = container.read(pomodoroTimerProvider);
      expect(paused!.status, 'paused');
      expect(paused.isPaused, isTrue);

      await notifier.resume();
      final resumed = container.read(pomodoroTimerProvider);
      expect(resumed!.status, 'focus');
      expect(resumed.isPaused, isFalse);
    });

    test('syncFromRemote updates state from WebSocket payload', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          pomodoroRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final notifier = container.read(pomodoroTimerProvider.notifier);
      notifier.syncFromRemote({
        'id': 99,
        'userId': 1,
        'status': 'shortBreak',
        'currentPhase': 'shortBreak',
        'currentSession': 2,
        'totalSessions': 4,
        'focusDurationSeconds': 1500,
        'shortBreakDurationSeconds': 300,
        'longBreakDurationSeconds': 900,
        'longBreakInterval': 4,
        'autoStartBreaks': true,
        'autoStartFocus': false,
        'totalFocusSeconds': 1500,
        'totalBreakSeconds': 0,
        'totalPausedSeconds': 0,
        'completedSessions': 1,
        'startedAt': DateTime.now().toIso8601String(),
      });

      final state = container.read(pomodoroTimerProvider);
      expect(state, isNotNull);
      expect(state!.id, 99);
      expect(state.status, 'shortBreak');
      expect(state.currentSession, 2);
    });
  });

  group('PomodoroTimerCard Widget', () {
    late SharedPreferences prefs;
    late FakePomodoroRepository fakeRepo;

    setUp(() async {
      prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      fakeRepo = FakePomodoroRepository();
    });

    testWidgets('renders configuration mode with "I WILL WORK" button and starts session', (
      WidgetTester tester,
    ) async {
      var fakeClock = DateTime(2026, 9, 25, 12, 0, 0);
      TimeUtils.clock = () => fakeClock;
      addTearDown(() => TimeUtils.clock = DateTime.now);

      await tester.pumpWidget(
        MaterialApp(
          theme: ChronologTheme.darkTheme,
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                pomodoroRepositoryProvider.overrideWithValue(fakeRepo),
              ],
              child: const SingleChildScrollView(child: PomodoroTimerCard()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Focus Session Setup'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('I WILL WORK'), findsOneWidget);
      expect(find.text('25m'), findsWidgets);
      expect(find.text('50m'), findsOneWidget);

      // Select 50m preset
      await tester.tap(find.text('50m'));
      await tester.pumpAndSettle();
      expect(find.text('50 min'), findsOneWidget);

      // Tap "I WILL WORK"
      await tester.tap(find.text('I WILL WORK'));
      await tester.pumpAndSettle();

      // Now active session view is rendered
      expect(find.text('FOCUS PHASE'), findsOneWidget);
      expect(find.text('Session 1 of 4'), findsOneWidget);
      expect(find.text('50:00'), findsOneWidget);
      expect(find.text('FOCUS'), findsOneWidget);
      expect(find.text('BREAK'), findsOneWidget);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Advance clock by 3 seconds and verify countdown ticks
      fakeClock = fakeClock.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('49:57'), findsOneWidget);
      expect(find.text('3s'), findsOneWidget); // Live focus metric
    });

    testWidgets('supports Custom focus duration option with numeric input and validation', (
      WidgetTester tester,
    ) async {
      var fakeClock = DateTime(2026, 9, 25, 12, 0, 0);
      TimeUtils.clock = () => fakeClock;
      addTearDown(() => TimeUtils.clock = DateTime.now);

      await tester.pumpWidget(
        MaterialApp(
          theme: ChronologTheme.darkTheme,
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                pomodoroRepositoryProvider.overrideWithValue(fakeRepo),
              ],
              child: const SingleChildScrollView(child: PomodoroTimerCard()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify presets and Custom button are visible
      expect(find.text('15m'), findsWidgets);
      expect(find.text('25m'), findsWidgets);
      expect(find.text('45m'), findsOneWidget);
      expect(find.text('50m'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      // Custom input field should not be visible initially
      expect(find.byType(TextField), findsNothing);

      // Select Custom
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      // Custom input field should now be visible with default 25 min
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('25'), findsOneWidget);

      // Enter invalid input: 0
      await tester.enterText(find.byType(TextField), '0');
      await tester.pumpAndSettle();
      expect(find.text('Enter 1 to 180 minutes'), findsOneWidget);
      expect(find.text('Custom'), findsWidgets);

      // Enter empty input
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('Please enter a duration'), findsOneWidget);

      // Enter valid custom input: 35 minutes
      await tester.enterText(find.byType(TextField), '35');
      await tester.pumpAndSettle();
      expect(find.text('35 min'), findsOneWidget);
      expect(find.text('Enter 1 to 180 minutes'), findsNothing);
      expect(find.text('Please enter a duration'), findsNothing);

      // Switch back to a preset (45m) - custom input should disappear
      await tester.tap(find.text('45m'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('45 min'), findsOneWidget);

      // Switch back to Custom and enter 30
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '30');
      await tester.pumpAndSettle();
      expect(find.text('30 min'), findsOneWidget);

      // Tap "I WILL WORK" to start session with 30m custom duration
      await tester.tap(find.text('I WILL WORK'));
      await tester.pumpAndSettle();

      // Session should start with 30:00 countdown
      expect(find.text('FOCUS PHASE'), findsOneWidget);
      expect(find.text('30:00'), findsOneWidget);
    });
  });

  group('Pomodoro Transitions and Timestamp Derivation', () {
    test('focus -> short break: natural time expiration advances phase, session and countdown', () {
      final t0 = DateTime(2026, 9, 25, 10, 0, 0);
      final endsAt = t0.add(const Duration(minutes: 25));

      final plan = PomodoroPlanModel(
        id: 1,
        userId: 1,
        status: 'focus',
        currentPhase: 'focus',
        currentSession: 1,
        totalSessions: 4,
        focusDurationSeconds: 1500,
        shortBreakDurationSeconds: 300,
        longBreakDurationSeconds: 900,
        longBreakInterval: 4,
        autoStartBreaks: true,
        autoStartFocus: true,
        phaseStartedAt: t0,
        phaseEndsAt: endsAt,
        startedAt: t0,
      );

      final now = endsAt; // Reached 00:00
      final advanced = plan.advanceToTime(now);

      expect(advanced.status, 'shortBreak');
      expect(advanced.currentPhase, 'shortBreak');
      expect(advanced.currentSession, 2);
      expect(advanced.completedSessions, 1);
      expect(advanced.phaseStartedAt, endsAt);
      expect(advanced.phaseEndsAt, endsAt.add(const Duration(seconds: 300)));
      expect(advanced.totalFocusSeconds, 1500);

      TimeUtils.clock = () => now;
      addTearDown(() => TimeUtils.clock = DateTime.now);
      expect(advanced.remainingDuration, const Duration(seconds: 300));
    });

    test('focus -> long break: triggers on configured longBreakInterval', () {
      final t0 = DateTime(2026, 9, 25, 12, 0, 0);
      final endsAt = t0.add(const Duration(minutes: 25));

      final plan = PomodoroPlanModel(
        id: 1,
        userId: 1,
        status: 'focus',
        currentPhase: 'focus',
        currentSession: 4,
        completedSessions: 3,
        totalSessions: 6,
        focusDurationSeconds: 1500,
        shortBreakDurationSeconds: 300,
        longBreakDurationSeconds: 900,
        longBreakInterval: 4,
        autoStartBreaks: true,
        autoStartFocus: true,
        phaseStartedAt: t0,
        phaseEndsAt: endsAt,
        startedAt: t0,
      );

      final now = endsAt;
      final advanced = plan.advanceToTime(now);

      expect(advanced.status, 'longBreak');
      expect(advanced.currentPhase, 'longBreak');
      expect(advanced.currentSession, 5);
      expect(advanced.completedSessions, 4);
      expect(advanced.phaseEndsAt, endsAt.add(const Duration(seconds: 900)));
    });

    test('break -> next focus: transitions automatically and resets countdown to focus duration', () {
      final t0 = DateTime(2026, 9, 25, 10, 25, 0);
      final endsAt = t0.add(const Duration(minutes: 5));

      final plan = PomodoroPlanModel(
        id: 1,
        userId: 1,
        status: 'shortBreak',
        currentPhase: 'shortBreak',
        currentSession: 2,
        completedSessions: 1,
        totalSessions: 4,
        focusDurationSeconds: 1500,
        shortBreakDurationSeconds: 300,
        longBreakDurationSeconds: 900,
        longBreakInterval: 4,
        autoStartBreaks: true,
        autoStartFocus: true,
        phaseStartedAt: t0,
        phaseEndsAt: endsAt,
        startedAt: t0,
      );

      final now = endsAt;
      final advanced = plan.advanceToTime(now);

      expect(advanced.status, 'focus');
      expect(advanced.currentPhase, 'focus');
      expect(advanced.currentSession, 2);
      expect(advanced.phaseStartedAt, endsAt);
      expect(advanced.phaseEndsAt, endsAt.add(const Duration(seconds: 1500)));
    });

    test('final focus -> completed: completes plan without remaining stuck at 00:00', () {
      final t0 = DateTime(2026, 9, 25, 12, 0, 0);
      final endsAt = t0.add(const Duration(minutes: 25));

      final plan = PomodoroPlanModel(
        id: 1,
        userId: 1,
        status: 'focus',
        currentPhase: 'focus',
        currentSession: 4,
        completedSessions: 3,
        totalSessions: 4,
        focusDurationSeconds: 1500,
        shortBreakDurationSeconds: 300,
        longBreakDurationSeconds: 900,
        longBreakInterval: 4,
        autoStartBreaks: true,
        autoStartFocus: true,
        phaseStartedAt: t0,
        phaseEndsAt: endsAt,
        startedAt: t0,
      );

      final now = endsAt.add(const Duration(seconds: 1));
      final advanced = plan.advanceToTime(now);

      expect(advanced.isCompleted, isTrue);
      expect(advanced.status, 'completed');
      expect(advanced.completedSessions, 4);
      expect(advanced.completedAt, endsAt);
      expect(advanced.phaseEndsAt, isNull);
      expect(advanced.remainingDuration, Duration.zero);
    });

    test('pause/resume around phase boundary: preserves paused duration and transitions after resume', () {
      final pauseTime = DateTime(2026, 9, 25, 10, 24, 50);

      // Plan paused with 10s remaining
      final plan = PomodoroPlanModel(
        id: 1,
        userId: 1,
        status: 'paused',
        currentPhase: 'focus',
        currentSession: 1,
        completedSessions: 0,
        totalSessions: 4,
        focusDurationSeconds: 1500,
        shortBreakDurationSeconds: 300,
        longBreakDurationSeconds: 900,
        longBreakInterval: 4,
        autoStartBreaks: true,
        autoStartFocus: true,
        pausedAt: pauseTime,
        pausedRemainingSeconds: 10,
        startedAt: pauseTime,
      );

      // Advancing while paused does NOT advance phase
      final later = pauseTime.add(const Duration(minutes: 15));
      final advancedWhilePaused = plan.advanceToTime(later);
      expect(advancedWhilePaused.status, 'paused');
      expect(advancedWhilePaused.pausedRemainingSeconds, 10);

      // Resumed at later
      final resumed = plan.copyWith(
        status: 'focus',
        pausedAt: null,
        pausedRemainingSeconds: null,
        phaseStartedAt: later,
        phaseEndsAt: later.add(const Duration(seconds: 10)),
      );

      // 10s later, expires and transitions into break
      final expired = resumed.advanceToTime(later.add(const Duration(seconds: 10)));
      expect(expired.status, 'shortBreak');
      expect(expired.currentSession, 2);
      expect(expired.phaseEndsAt, later.add(const Duration(seconds: 310)));
    });

    test('reconnect/backgrounding when phase(s) expire: accurately derives active phase and session', () {
      final t0 = DateTime(2026, 9, 25, 10, 0, 0);
      final endsAt = t0.add(const Duration(minutes: 25));

      final plan = PomodoroPlanModel(
        id: 1,
        userId: 1,
        status: 'focus',
        currentPhase: 'focus',
        currentSession: 1,
        totalSessions: 4,
        focusDurationSeconds: 1500,
        shortBreakDurationSeconds: 300,
        longBreakDurationSeconds: 900,
        longBreakInterval: 4,
        autoStartBreaks: true,
        autoStartFocus: true,
        phaseStartedAt: t0,
        phaseEndsAt: endsAt,
        startedAt: t0,
      );

      // Backgrounded for 35 minutes -> 5 minutes into Session 2 focus
      final reopenTime = t0.add(const Duration(minutes: 35));
      final derived = plan.advanceToTime(reopenTime);

      expect(derived.status, 'focus');
      expect(derived.currentPhase, 'focus');
      expect(derived.currentSession, 2);
      expect(derived.completedSessions, 1);
      expect(derived.totalFocusSeconds, 1500);
      expect(derived.totalBreakSeconds, 300);
      expect(derived.phaseStartedAt, t0.add(const Duration(minutes: 30)));
      expect(derived.phaseEndsAt, t0.add(const Duration(minutes: 55)));

      TimeUtils.clock = () => reopenTime;
      addTearDown(() => TimeUtils.clock = DateTime.now);
      expect(derived.remainingDuration, const Duration(minutes: 20));

      // Backgrounded for 4 hours -> complete
      final muchLater = t0.add(const Duration(hours: 4));
      final fullyComplete = plan.advanceToTime(muchLater);
      expect(fullyComplete.isCompleted, isTrue);
      expect(fullyComplete.completedSessions, 4);
    });

    testWidgets('PomodoroTimerCard displays Next: Session during breaks and Session during focus', (
      WidgetTester tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      final fakeRepo = FakePomodoroRepository();

      final t0 = DateTime(2026, 9, 25, 10, 25, 0);
      TimeUtils.clock = () => t0;
      addTearDown(() => TimeUtils.clock = DateTime.now);

      final breakPlan = PomodoroPlanModel(
        id: 1,
        userId: 1,
        status: 'shortBreak',
        currentPhase: 'shortBreak',
        currentSession: 2,
        totalSessions: 4,
        focusDurationSeconds: 1500,
        shortBreakDurationSeconds: 300,
        longBreakDurationSeconds: 900,
        longBreakInterval: 4,
        autoStartBreaks: true,
        autoStartFocus: true,
        phaseStartedAt: t0,
        phaseEndsAt: t0.add(const Duration(seconds: 300)),
        startedAt: t0,
      );

      fakeRepo.currentPlan = breakPlan;
      await TimerStorage(prefs: prefs).savePlan(breakPlan);

      await tester.pumpWidget(
        MaterialApp(
          theme: ChronologTheme.darkTheme,
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                pomodoroRepositoryProvider.overrideWithValue(fakeRepo),
              ],
              child: const SingleChildScrollView(child: PomodoroTimerCard()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // In break: shows Next: Session 2 of 4 and SHORT BREAK
      expect(find.text('SHORT BREAK'), findsOneWidget);
      expect(find.text('Next: Session 2 of 4'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
    });
  });
}
