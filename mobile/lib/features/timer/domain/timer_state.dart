import 'package:flutter/foundation.dart';

/// Status of the local Pomodoro timer.
enum TimerStatus {
  stopped,
  running,
  paused,
  completed,
}

/// Immutable state for the local Pomodoro focus timer.
///
/// Designed with [endsAt] timestamp as the single source of truth when running,
/// ensuring zero clock drift, background resilience, and survival across app restarts.
@immutable
class TimerState {
  const TimerState({
    this.status = TimerStatus.stopped,
    this.duration = const Duration(minutes: 25),
    this.endsAt,
    this.pausedRemaining,
    this.activeTaskId,
    this.activeTaskTitle,
  });

  final TimerStatus status;
  final Duration duration;
  final DateTime? endsAt;
  final Duration? pausedRemaining;
  final String? activeTaskId;
  final String? activeTaskTitle;

  /// Calculates remaining duration dynamically from [endsAt] or paused duration.
  Duration get remainingDuration {
    switch (status) {
      case TimerStatus.stopped:
        return duration;
      case TimerStatus.paused:
        return pausedRemaining ?? duration;
      case TimerStatus.completed:
        return Duration.zero;
      case TimerStatus.running:
        if (endsAt == null) return duration;
        final diff = endsAt!.difference(DateTime.now());
        return diff.isNegative ? Duration.zero : diff;
    }
  }

  /// Completion progress from 0.0 (just started) to 1.0 (finished).
  double get progress {
    final totalMs = duration.inMilliseconds;
    if (totalMs <= 0) return 1.0;
    final remainingMs = remainingDuration.inMilliseconds;
    final completedMs = totalMs - remainingMs;
    return (completedMs / totalMs).clamp(0.0, 1.0);
  }

  TimerState copyWith({
    TimerStatus? status,
    Duration? duration,
    DateTime? endsAt,
    bool clearEndsAt = false,
    Duration? pausedRemaining,
    bool clearPausedRemaining = false,
    String? activeTaskId,
    bool clearActiveTask = false,
    String? activeTaskTitle,
  }) {
    return TimerState(
      status: status ?? this.status,
      duration: duration ?? this.duration,
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      pausedRemaining: clearPausedRemaining
          ? null
          : (pausedRemaining ?? this.pausedRemaining),
      activeTaskId: clearActiveTask ? null : (activeTaskId ?? this.activeTaskId),
      activeTaskTitle:
          clearActiveTask ? null : (activeTaskTitle ?? this.activeTaskTitle),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'durationMs': duration.inMilliseconds,
        'endsAt': endsAt?.toIso8601String(),
        'pausedRemainingMs': pausedRemaining?.inMilliseconds,
        'activeTaskId': activeTaskId,
        'activeTaskTitle': activeTaskTitle,
      };

  factory TimerState.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? 'stopped';
    final status = TimerStatus.values.firstWhere(
      (e) => e.name == statusName,
      orElse: () => TimerStatus.stopped,
    );

    final durationMs = json['durationMs'] as int? ?? (25 * 60 * 1000);
    final endsAtStr = json['endsAt'] as String?;
    final pausedRemainingMs = json['pausedRemainingMs'] as int?;

    return TimerState(
      status: status,
      duration: Duration(milliseconds: durationMs),
      endsAt: endsAtStr != null ? DateTime.tryParse(endsAtStr) : null,
      pausedRemaining: pausedRemainingMs != null
          ? Duration(milliseconds: pausedRemainingMs)
          : null,
      activeTaskId: json['activeTaskId'] as String?,
      activeTaskTitle: json['activeTaskTitle'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimerState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          duration == other.duration &&
          endsAt == other.endsAt &&
          pausedRemaining == other.pausedRemaining &&
          activeTaskId == other.activeTaskId &&
          activeTaskTitle == other.activeTaskTitle;

  @override
  int get hashCode =>
      status.hashCode ^
      duration.hashCode ^
      endsAt.hashCode ^
      pausedRemaining.hashCode ^
      activeTaskId.hashCode ^
      activeTaskTitle.hashCode;

  @override
  String toString() =>
      'TimerState(status: $status, duration: ${duration.inMinutes}m, remaining: ${remainingDuration.inSeconds}s, task: $activeTaskTitle)';
}
