import 'package:flutter/foundation.dart';
import '../../../../shared/utils/time_utils.dart';

/// Represents a persistent Pomodoro Focus Plan in Chronolog.
@immutable
class PomodoroPlanModel {
  const PomodoroPlanModel({
    required this.id,
    required this.userId,
    required this.status,
    required this.currentPhase,
    required this.currentSession,
    required this.totalSessions,
    required this.focusDurationSeconds,
    required this.shortBreakDurationSeconds,
    required this.longBreakDurationSeconds,
    required this.longBreakInterval,
    required this.autoStartBreaks,
    required this.autoStartFocus,
    this.phaseStartedAt,
    this.phaseEndsAt,
    this.pausedAt,
    this.pausedRemainingSeconds,
    this.totalFocusSeconds = 0,
    this.totalBreakSeconds = 0,
    this.totalPausedSeconds = 0,
    this.completedSessions = 0,
    this.taskId,
    this.taskTitle,
    required this.startedAt,
    this.completedAt,
  });

  final int id;
  final int userId;
  final String status; // 'focus' | 'shortBreak' | 'longBreak' | 'paused' | 'completed' | 'cancelled'
  final String currentPhase; // 'focus' | 'shortBreak' | 'longBreak'
  final int currentSession;
  final int totalSessions;
  final int focusDurationSeconds;
  final int shortBreakDurationSeconds;
  final int longBreakDurationSeconds;
  final int longBreakInterval;
  final bool autoStartBreaks;
  final bool autoStartFocus;
  final DateTime? phaseStartedAt;
  final DateTime? phaseEndsAt;
  final DateTime? pausedAt;
  final int? pausedRemainingSeconds;
  final int totalFocusSeconds;
  final int totalBreakSeconds;
  final int totalPausedSeconds;
  final int completedSessions;
  final String? taskId;
  final String? taskTitle;
  final DateTime startedAt;
  final DateTime? completedAt;

  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isActive =>
      status == 'focus' ||
      status == 'shortBreak' ||
      status == 'longBreak' ||
      status == 'paused';

  /// Advances expired phase boundaries sequentially up to [now], deriving the current phase,
  /// session number, and completion state from timestamps.
  PomodoroPlanModel advanceToTime(DateTime now) {
    if (isCompleted || isCancelled || isPaused || phaseEndsAt == null) {
      return this;
    }
    if (now.isBefore(phaseEndsAt!)) {
      return this;
    }

    var current = this;

    while (!current.isCompleted &&
        !current.isCancelled &&
        !current.isPaused &&
        current.phaseEndsAt != null &&
        !now.isBefore(current.phaseEndsAt!)) {
      final boundary = current.phaseEndsAt!;
      final phaseStarted = current.phaseStartedAt ?? boundary;
      final elapsed = boundary.difference(phaseStarted).inSeconds.clamp(0, 100000000);

      final addFocus = current.currentPhase == 'focus' ? elapsed : 0;
      final addBreak = current.currentPhase != 'focus' ? elapsed : 0;

      final newTotalFocus = current.totalFocusSeconds + addFocus;
      final newTotalBreak = current.totalBreakSeconds + addBreak;

      if (current.currentPhase == 'focus') {
        final newCompleted = current.completedSessions + 1;
        if (newCompleted >= current.totalSessions) {
          current = PomodoroPlanModel(
            id: current.id,
            userId: current.userId,
            status: 'completed',
            currentPhase: current.currentPhase,
            currentSession: current.totalSessions,
            totalSessions: current.totalSessions,
            focusDurationSeconds: current.focusDurationSeconds,
            shortBreakDurationSeconds: current.shortBreakDurationSeconds,
            longBreakDurationSeconds: current.longBreakDurationSeconds,
            longBreakInterval: current.longBreakInterval,
            autoStartBreaks: current.autoStartBreaks,
            autoStartFocus: current.autoStartFocus,
            phaseStartedAt: null,
            phaseEndsAt: null,
            pausedAt: null,
            pausedRemainingSeconds: null,
            totalFocusSeconds: newTotalFocus,
            totalBreakSeconds: newTotalBreak,
            totalPausedSeconds: current.totalPausedSeconds,
            completedSessions: newCompleted,
            taskId: current.taskId,
            taskTitle: current.taskTitle,
            startedAt: current.startedAt,
            completedAt: boundary,
          );
          break;
        }

        final isLong = (newCompleted % current.longBreakInterval == 0);
        final nextPhase = isLong ? 'longBreak' : 'shortBreak';
        final breakDuration =
            isLong ? current.longBreakDurationSeconds : current.shortBreakDurationSeconds;

        if (current.autoStartBreaks) {
          final nextEndsAt = boundary.add(Duration(seconds: breakDuration));
          current = current.copyWith(
            status: nextPhase,
            currentPhase: nextPhase,
            currentSession: newCompleted + 1,
            completedSessions: newCompleted,
            phaseStartedAt: boundary,
            phaseEndsAt: nextEndsAt,
            totalFocusSeconds: newTotalFocus,
            totalBreakSeconds: newTotalBreak,
          );
        } else {
          current = PomodoroPlanModel(
            id: current.id,
            userId: current.userId,
            status: 'paused',
            currentPhase: nextPhase,
            currentSession: newCompleted + 1,
            totalSessions: current.totalSessions,
            focusDurationSeconds: current.focusDurationSeconds,
            shortBreakDurationSeconds: current.shortBreakDurationSeconds,
            longBreakDurationSeconds: current.longBreakDurationSeconds,
            longBreakInterval: current.longBreakInterval,
            autoStartBreaks: current.autoStartBreaks,
            autoStartFocus: current.autoStartFocus,
            phaseStartedAt: null,
            phaseEndsAt: null,
            pausedAt: boundary,
            pausedRemainingSeconds: breakDuration,
            totalFocusSeconds: newTotalFocus,
            totalBreakSeconds: newTotalBreak,
            totalPausedSeconds: current.totalPausedSeconds,
            completedSessions: newCompleted,
            taskId: current.taskId,
            taskTitle: current.taskTitle,
            startedAt: current.startedAt,
            completedAt: null,
          );
          break;
        }
      } else {
        // Break -> Focus
        final nextSession = current.completedSessions + 1;
        final focusDuration = current.focusDurationSeconds;

        if (current.autoStartFocus) {
          final nextEndsAt = boundary.add(Duration(seconds: focusDuration));
          current = current.copyWith(
            status: 'focus',
            currentPhase: 'focus',
            currentSession: nextSession,
            phaseStartedAt: boundary,
            phaseEndsAt: nextEndsAt,
            totalFocusSeconds: newTotalFocus,
            totalBreakSeconds: newTotalBreak,
          );
        } else {
          current = PomodoroPlanModel(
            id: current.id,
            userId: current.userId,
            status: 'paused',
            currentPhase: 'focus',
            currentSession: nextSession,
            totalSessions: current.totalSessions,
            focusDurationSeconds: current.focusDurationSeconds,
            shortBreakDurationSeconds: current.shortBreakDurationSeconds,
            longBreakDurationSeconds: current.longBreakDurationSeconds,
            longBreakInterval: current.longBreakInterval,
            autoStartBreaks: current.autoStartBreaks,
            autoStartFocus: current.autoStartFocus,
            phaseStartedAt: null,
            phaseEndsAt: null,
            pausedAt: boundary,
            pausedRemainingSeconds: focusDuration,
            totalFocusSeconds: newTotalFocus,
            totalBreakSeconds: newTotalBreak,
            totalPausedSeconds: current.totalPausedSeconds,
            completedSessions: current.completedSessions,
            taskId: current.taskId,
            taskTitle: current.taskTitle,
            startedAt: current.startedAt,
            completedAt: null,
          );
          break;
        }
      }
    }

    return current;
  }

  /// Calculates remaining countdown duration derived from phaseEndsAt or paused remaining.
  Duration get remainingDuration {
    if (isCompleted || isCancelled) return Duration.zero;
    if (isPaused) {
      return Duration(seconds: pausedRemainingSeconds ?? 0);
    }
    final now = TimeUtils.now();
    final effective = advanceToTime(now);
    if (effective.isCompleted || effective.isCancelled) return Duration.zero;
    if (effective.isPaused) {
      return Duration(seconds: effective.pausedRemainingSeconds ?? 0);
    }
    if (effective.phaseEndsAt == null) return Duration.zero;
    final diff = effective.phaseEndsAt!.difference(now);
    if (diff.isNegative) return Duration.zero;
    return diff;
  }

  /// Calculates live accumulated focus time (never includes paused time).
  int get liveFocusSeconds {
    final effective = advanceToTime(TimeUtils.now());
    var total = effective.totalFocusSeconds;
    if (effective.status == 'focus' && effective.phaseStartedAt != null) {
      final now = TimeUtils.now();
      total += now.difference(effective.phaseStartedAt!).inSeconds.clamp(0, 100000000);
    }
    return total;
  }

  /// Calculates live accumulated break time (never includes paused time).
  int get liveBreakSeconds {
    final effective = advanceToTime(TimeUtils.now());
    var total = effective.totalBreakSeconds;
    if ((effective.status == 'shortBreak' || effective.status == 'longBreak') && effective.phaseStartedAt != null) {
      final now = TimeUtils.now();
      total += now.difference(effective.phaseStartedAt!).inSeconds.clamp(0, 100000000);
    }
    return total;
  }

  /// Calculates live accumulated paused time.
  int get livePausedSeconds {
    var total = totalPausedSeconds;
    if (status == 'paused' && pausedAt != null) {
      final now = TimeUtils.now();
      total += now.difference(pausedAt!).inSeconds.clamp(0, 100000000);
    }
    return total;
  }

  factory PomodoroPlanModel.fromJson(Map<String, dynamic> json) {
    return PomodoroPlanModel(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? json['user_id'] as int,
      status: json['status'] as String? ?? 'focus',
      currentPhase: json['currentPhase'] as String? ?? json['current_phase'] as String? ?? 'focus',
      currentSession: json['currentSession'] as int? ?? json['current_session'] as int? ?? 1,
      totalSessions: json['totalSessions'] as int? ?? json['total_sessions'] as int? ?? 4,
      focusDurationSeconds: json['focusDurationSeconds'] as int? ?? json['focus_duration_seconds'] as int? ?? 1500,
      shortBreakDurationSeconds: json['shortBreakDurationSeconds'] as int? ?? json['short_break_duration_seconds'] as int? ?? 300,
      longBreakDurationSeconds: json['longBreakDurationSeconds'] as int? ?? json['long_break_duration_seconds'] as int? ?? 900,
      longBreakInterval: json['longBreakInterval'] as int? ?? json['long_break_interval'] as int? ?? 4,
      autoStartBreaks: json['autoStartBreaks'] as bool? ?? json['auto_start_breaks'] as bool? ?? false,
      autoStartFocus: json['autoStartFocus'] as bool? ?? json['auto_start_focus'] as bool? ?? false,
      phaseStartedAt: json['phaseStartedAt'] != null
          ? DateTime.tryParse(json['phaseStartedAt'] as String)
          : (json['phase_started_at'] != null ? DateTime.tryParse(json['phase_started_at'] as String) : null),
      phaseEndsAt: json['phaseEndsAt'] != null
          ? DateTime.tryParse(json['phaseEndsAt'] as String)
          : (json['phase_ends_at'] != null ? DateTime.tryParse(json['phase_ends_at'] as String) : null),
      pausedAt: json['pausedAt'] != null
          ? DateTime.tryParse(json['pausedAt'] as String)
          : (json['paused_at'] != null ? DateTime.tryParse(json['paused_at'] as String) : null),
      pausedRemainingSeconds: json['pausedRemainingSeconds'] as int? ?? json['paused_remaining_seconds'] as int?,
      totalFocusSeconds: json['totalFocusSeconds'] as int? ?? json['total_focus_seconds'] as int? ?? 0,
      totalBreakSeconds: json['totalBreakSeconds'] as int? ?? json['total_break_seconds'] as int? ?? 0,
      totalPausedSeconds: json['totalPausedSeconds'] as int? ?? json['total_paused_seconds'] as int? ?? 0,
      completedSessions: json['completedSessions'] as int? ?? json['completed_sessions'] as int? ?? 0,
      taskId: json['taskId'] as String? ?? json['task_id'] as String?,
      taskTitle: json['taskTitle'] as String? ?? json['task_title'] as String?,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : (json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : DateTime.now()),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : (json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'status': status,
    'currentPhase': currentPhase,
    'currentSession': currentSession,
    'totalSessions': totalSessions,
    'focusDurationSeconds': focusDurationSeconds,
    'shortBreakDurationSeconds': shortBreakDurationSeconds,
    'longBreakDurationSeconds': longBreakDurationSeconds,
    'longBreakInterval': longBreakInterval,
    'autoStartBreaks': autoStartBreaks,
    'autoStartFocus': autoStartFocus,
    'phaseStartedAt': phaseStartedAt?.toIso8601String(),
    'phaseEndsAt': phaseEndsAt?.toIso8601String(),
    'pausedAt': pausedAt?.toIso8601String(),
    'pausedRemainingSeconds': pausedRemainingSeconds,
    'totalFocusSeconds': totalFocusSeconds,
    'totalBreakSeconds': totalBreakSeconds,
    'totalPausedSeconds': totalPausedSeconds,
    'completedSessions': completedSessions,
    'taskId': taskId,
    'taskTitle': taskTitle,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  PomodoroPlanModel copyWith({
    int? id,
    int? userId,
    String? status,
    String? currentPhase,
    int? currentSession,
    int? totalSessions,
    int? focusDurationSeconds,
    int? shortBreakDurationSeconds,
    int? longBreakDurationSeconds,
    int? longBreakInterval,
    bool? autoStartBreaks,
    bool? autoStartFocus,
    DateTime? phaseStartedAt,
    DateTime? phaseEndsAt,
    DateTime? pausedAt,
    int? pausedRemainingSeconds,
    int? totalFocusSeconds,
    int? totalBreakSeconds,
    int? totalPausedSeconds,
    int? completedSessions,
    String? taskId,
    String? taskTitle,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return PomodoroPlanModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      currentPhase: currentPhase ?? this.currentPhase,
      currentSession: currentSession ?? this.currentSession,
      totalSessions: totalSessions ?? this.totalSessions,
      focusDurationSeconds: focusDurationSeconds ?? this.focusDurationSeconds,
      shortBreakDurationSeconds: shortBreakDurationSeconds ?? this.shortBreakDurationSeconds,
      longBreakDurationSeconds: longBreakDurationSeconds ?? this.longBreakDurationSeconds,
      longBreakInterval: longBreakInterval ?? this.longBreakInterval,
      autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      autoStartFocus: autoStartFocus ?? this.autoStartFocus,
      phaseStartedAt: phaseStartedAt ?? this.phaseStartedAt,
      phaseEndsAt: phaseEndsAt ?? this.phaseEndsAt,
      pausedAt: pausedAt ?? this.pausedAt,
      pausedRemainingSeconds: pausedRemainingSeconds ?? this.pausedRemainingSeconds,
      totalFocusSeconds: totalFocusSeconds ?? this.totalFocusSeconds,
      totalBreakSeconds: totalBreakSeconds ?? this.totalBreakSeconds,
      totalPausedSeconds: totalPausedSeconds ?? this.totalPausedSeconds,
      completedSessions: completedSessions ?? this.completedSessions,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
