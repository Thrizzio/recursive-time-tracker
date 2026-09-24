import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/utils/time_utils.dart';
import '../data/timer_storage.dart';
import '../domain/timer_state.dart';

/// Provider for Pomodoro focus timer state and actions.
final pomodoroTimerProvider =
    NotifierProvider<PomodoroNotifier, TimerState>(() {
  return PomodoroNotifier();
});

/// Riverpod notifier managing Pomodoro focus session lifecycle.
class PomodoroNotifier extends Notifier<TimerState> {
  Timer? _ticker;

  TimerStorage get _storage => ref.read(timerStorageProvider);

  @override
  TimerState build() {
    ref.onDispose(() {
      _stopTicker();
    });

    // Attempt to recover persisted session
    final loaded = _storage.loadState();
    if (loaded != null) {
      if (loaded.status == TimerStatus.running && loaded.endsAt != null) {
        final now = TimeUtils.now();
        if (now.isAfter(loaded.endsAt!)) {
          // Timer reached 0 while app was in background or closed
          final finished = loaded.copyWith(
            status: TimerStatus.completed,
            clearEndsAt: true,
          );
          _storage.saveState(finished);
          return finished;
        } else {
          // Timer is still running! Resume background ticker
          Future.microtask(() => _startTicker());
          return loaded;
        }
      }
      return loaded;
    }

    return const TimerState();
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status != TimerStatus.running || state.endsAt == null) {
        _stopTicker();
        return;
      }

      final now = TimeUtils.now();
      if (now.isAfter(state.endsAt!)) {
        _stopTicker();
        state = state.copyWith(
          status: TimerStatus.completed,
          clearEndsAt: true,
        );
        _storage.saveState(state);
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Starts or restarts a focus timer session.
  void start({
    Duration? customDuration,
    String? taskId,
    String? taskTitle,
  }) {
    final sessionDuration = customDuration ?? state.duration;
    final endsAt = TimeUtils.now().add(sessionDuration);

    state = state.copyWith(
      status: TimerStatus.running,
      duration: sessionDuration,
      endsAt: endsAt,
      clearPausedRemaining: true,
      activeTaskId: taskId,
      activeTaskTitle: taskTitle,
    );

    _startTicker();
    _storage.saveState(state);
  }

  /// Pauses the running timer, preserving remaining time.
  void pause() {
    if (state.status != TimerStatus.running || state.endsAt == null) return;

    final remaining = state.endsAt!.difference(TimeUtils.now());
    _stopTicker();

    state = state.copyWith(
      status: TimerStatus.paused,
      pausedRemaining: remaining.isNegative ? Duration.zero : remaining,
      clearEndsAt: true,
    );

    _storage.saveState(state);
  }

  /// Resumes a paused timer with its preserved remaining duration.
  void resume() {
    if (state.status != TimerStatus.paused) return;

    final remaining = state.pausedRemaining ?? state.duration;
    final endsAt = TimeUtils.now().add(remaining);

    state = state.copyWith(
      status: TimerStatus.running,
      endsAt: endsAt,
      clearPausedRemaining: true,
    );

    _startTicker();
    _storage.saveState(state);
  }

  /// Resets the timer back to stopped ready state.
  void reset() {
    _stopTicker();

    state = state.copyWith(
      status: TimerStatus.stopped,
      clearEndsAt: true,
      clearPausedRemaining: true,
      clearActiveTask: true,
    );

    _storage.saveState(state);
  }

  /// Sets the timer duration preset (e.g. 25 min, 50 min).
  void setDuration(Duration newDuration) {
    if (state.status != TimerStatus.stopped &&
        state.status != TimerStatus.completed) {
      return;
    }

    state = state.copyWith(
      duration: newDuration,
      status: TimerStatus.stopped,
      clearEndsAt: true,
      clearPausedRemaining: true,
    );

    _storage.saveState(state);
  }

  /// Convenience method to start a focus timer tied to a specific task.
  void startFocusForTask({
    required String taskId,
    required String taskTitle,
  }) {
    start(taskId: taskId, taskTitle: taskTitle);
  }
}

/// 1-second reactive stream provider for live countdown ticking.
/// Derives remaining time directly from state.endsAt when running or pausedRemaining.
final pomodoroRemainingDurationProvider =
    StreamProvider.autoDispose<Duration>((ref) async* {
  final timer = ref.watch(pomodoroTimerProvider);

  if (timer.status == TimerStatus.running && timer.endsAt != null) {
    final initialDiff = timer.endsAt!.difference(TimeUtils.now());
    yield initialDiff.isNegative ? Duration.zero : initialDiff;

    yield* Stream.periodic(const Duration(seconds: 1), (_) {
      final diff = timer.endsAt!.difference(TimeUtils.now());
      return diff.isNegative ? Duration.zero : diff;
    });
  } else {
    yield timer.remainingDuration;
  }
});
