import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../shared/utils/time_utils.dart';
import '../data/pomodoro_repository.dart';
import '../data/timer_storage.dart';
import '../domain/pomodoro_model.dart';

/// Provider for Pomodoro focus plan state and actions.
final pomodoroTimerProvider =
    NotifierProvider<PomodoroNotifier, PomodoroPlanModel?>(() {
  return PomodoroNotifier();
});

/// Riverpod notifier managing Pomodoro focus session lifecycle synchronized with backend.
class PomodoroNotifier extends Notifier<PomodoroPlanModel?> {
  TimerStorage get _storage => ref.read(timerStorageProvider);
  PomodoroRepository get _repo => ref.read(pomodoroRepositoryProvider);

  String? _lastPhaseKey;

  void _updateState(PomodoroPlanModel? next) {
    final previous = state;
    state = next;
    _maybeNotifyTransition(previous, next);
  }

  void _maybeNotifyTransition(PomodoroPlanModel? previous, PomodoroPlanModel? next) {
    if (next == null) {
      _lastPhaseKey = null;
      return;
    }

    final nextKey =
        '${next.id}:${next.status}:${next.currentPhase}:${next.currentSession}:${next.completedSessions}';
    if (_lastPhaseKey == null) {
      _lastPhaseKey = nextKey;
      return;
    }

    if (_lastPhaseKey != nextKey) {
      _lastPhaseKey = nextKey;
      unawaited(_safeNotify(previous, next));
    }
  }

  Future<void> _safeNotify(PomodoroPlanModel? previous, PomodoroPlanModel next) async {
    try {
      final notifications = ref.read(notificationServiceProvider);
      if (next.isCompleted && (previous == null || !previous.isCompleted)) {
        await notifications.showNotification(
          id: 100,
          title: 'Pomodoro Complete!',
          body: 'Great job! You finished all ${next.totalSessions} focus sessions.',
        );
      } else if (next.currentPhase == 'focus' && previous?.currentPhase != 'focus') {
        await notifications.showNotification(
          id: 101,
          title: 'Focus Session ${next.currentSession} Started',
          body: 'Time to focus! Session ${next.currentSession} of ${next.totalSessions} is underway.',
        );
      } else if (next.currentPhase == 'longBreak' && previous?.currentPhase != 'longBreak') {
        await notifications.showNotification(
          id: 102,
          title: 'Long Break Started',
          body: 'Enjoy your long break! Session ${next.currentSession} of ${next.totalSessions} begins after this.',
        );
      } else if (next.currentPhase == 'shortBreak' && previous?.currentPhase != 'shortBreak') {
        await notifications.showNotification(
          id: 103,
          title: 'Short Break Started',
          body: 'Take a break! Session ${next.currentSession} of ${next.totalSessions} begins after this.',
        );
      }
    } catch (e) {
      // Notifications are strictly independent: never throw or block Pomodoro state
      debugPrint('[PomodoroNotifier] Notification error: $e');
    }
  }

  @override
  PomodoroPlanModel? build() {
    // 1. Recover cached plan if available, advancing to current time
    final cached = _storage.loadPlan();
    final effective = cached?.advanceToTime(TimeUtils.now());
    if (effective != null) {
      _lastPhaseKey =
          '${effective.id}:${effective.status}:${effective.currentPhase}:${effective.currentSession}:${effective.completedSessions}';
    }

    // 2. Fetch authoritative state from backend
    Future.microtask(() => refreshFromRemote());

    return effective;
  }

  /// Checks whether current phase has elapsed, advances local state and reconciles with backend.
  void checkAutoAdvance() {
    if (state != null && state!.isActive && !state!.isPaused && state!.phaseEndsAt != null) {
      final now = TimeUtils.now();
      if (!now.isBefore(state!.phaseEndsAt!)) {
        final advanced = state!.advanceToTime(now);
        _updateState(advanced);
        _storage.savePlan(advanced);
        refreshFromRemote();
      }
    }
  }

  /// Refreshes current active plan from the backend REST API.
  Future<void> refreshFromRemote() async {
    try {
      final plan = await _repo.getCurrentPlan();
      final effective = plan?.advanceToTime(TimeUtils.now());
      _updateState(effective);
      await _storage.savePlan(effective);
    } catch (e) {
      debugPrint('[PomodoroNotifier] Failed to refresh current plan: $e');
    }
  }

  /// Synchronizes state directly from a WebSocket event payload.
  void syncFromRemote(Map<String, dynamic>? planJson) {
    if (planJson != null) {
      final parsed = PomodoroPlanModel.fromJson(planJson);
      _updateState(parsed.advanceToTime(TimeUtils.now()));
    } else {
      _updateState(null);
    }
    _storage.savePlan(state);
  }

  /// Directly set plan (useful in tests or local overrides).
  void setLocalPlan(PomodoroPlanModel? plan) {
    _updateState(plan?.advanceToTime(TimeUtils.now()));
    _storage.savePlan(state);
  }

  /// Starts a new Pomodoro focus plan on the backend.
  Future<PomodoroPlanModel> startPlan({
    int totalSessions = 4,
    int focusDurationSeconds = 1500,
    int shortBreakDurationSeconds = 300,
    int longBreakDurationSeconds = 900,
    int longBreakInterval = 4,
    bool autoStartBreaks = true,
    bool autoStartFocus = true,
    String? taskId,
    String? taskTitle,
  }) async {
    final newPlan = await _repo.startPlan(
      totalSessions: totalSessions,
      focusDurationSeconds: focusDurationSeconds,
      shortBreakDurationSeconds: shortBreakDurationSeconds,
      longBreakDurationSeconds: longBreakDurationSeconds,
      longBreakInterval: longBreakInterval,
      autoStartBreaks: autoStartBreaks,
      autoStartFocus: autoStartFocus,
      taskId: taskId,
      taskTitle: taskTitle,
    );
    _updateState(newPlan);
    await _storage.savePlan(newPlan);
    return newPlan;
  }

  /// Pauses the running timer, strictly segregating paused time on the backend.
  Future<void> pause() async {
    if (state == null) return;
    final updated = await _repo.pausePlan(state!.id);
    _updateState(updated);
    await _storage.savePlan(updated);
  }

  /// Resumes a paused timer with preserved remaining duration.
  Future<void> resume() async {
    if (state == null) return;
    final updated = await _repo.resumePlan(state!.id);
    _updateState(updated);
    await _storage.savePlan(updated);
  }

  /// Advances to the next phase (focus -> break or break -> focus).
  Future<void> nextPhase() async {
    if (state == null) return;
    final updated = await _repo.nextPhase(state!.id);
    _updateState(updated);
    await _storage.savePlan(updated);
  }

  /// Skips the current phase.
  Future<void> skipPhase() async {
    if (state == null) return;
    final updated = await _repo.skipPhase(state!.id);
    _updateState(updated);
    await _storage.savePlan(updated);
  }

  /// Cancels the current Pomodoro plan.
  Future<void> cancelPlan() async {
    if (state == null) return;
    final updated = await _repo.cancelPlan(state!.id);
    _updateState(updated);
    await _storage.savePlan(updated);
  }

  /// Reset action: cancels active plan or clears local state if completed.
  Future<void> reset() async {
    if (state != null && state!.isActive) {
      await cancelPlan();
    } else {
      _updateState(null);
      await _storage.clearPlan();
    }
  }

  /// Starts a focus session tied to a specific Google task.
  Future<void> startFocusForTask({
    required String taskId,
    required String taskTitle,
    int focusDurationSeconds = 1500,
  }) async {
    await startPlan(
      taskId: taskId,
      taskTitle: taskTitle,
      focusDurationSeconds: focusDurationSeconds,
    );
  }
}

/// 1-second reactive ticker provider emitting DateTime.now().
final pomodoroTickerStreamProvider =
    StreamProvider.autoDispose<DateTime>((ref) async* {
  yield TimeUtils.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) {
    ref.read(pomodoroTimerProvider.notifier).checkAutoAdvance();
    return TimeUtils.now();
  });
});

/// 1-second reactive stream provider for live countdown ticking.
final pomodoroRemainingDurationProvider =
    StreamProvider.autoDispose<Duration>((ref) async* {
  final plan = ref.watch(pomodoroTimerProvider);
  if (plan == null) {
    yield Duration.zero;
    return;
  }

  yield plan.remainingDuration;

  if (plan.isActive && !plan.isPaused) {
    yield* Stream.periodic(const Duration(seconds: 1), (_) => plan.remainingDuration);
  }
});
