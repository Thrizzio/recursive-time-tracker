import 'package:flutter/foundation.dart';
import '../../activities/domain/activity_model.dart';

/// Represents an allocation of time percentage to an activity within a time block.
@immutable
class TimeAllocationModel {
  const TimeAllocationModel({
    required this.activityId,
    required this.percentage,
    this.id,
    this.durationSeconds = 0,
    this.activity,
  });

  final int? id;
  final int activityId;
  final int percentage;
  final int durationSeconds;
  final ActivityModel? activity;

  factory TimeAllocationModel.fromJson(Map<String, dynamic> json) {
    return TimeAllocationModel(
      id: json['id'] as int?,
      activityId: json['activityId'] as int,
      percentage: json['percentage'] as int,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      activity: json['activity'] != null
          ? ActivityModel.fromJson(json['activity'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'activityId': activityId,
        'percentage': percentage,
        'durationSeconds': durationSeconds,
      };

  TimeAllocationModel copyWith({
    int? id,
    int? activityId,
    int? percentage,
    int? durationSeconds,
    ActivityModel? activity,
  }) {
    return TimeAllocationModel(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      percentage: percentage ?? this.percentage,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      activity: activity ?? this.activity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeAllocationModel &&
          runtimeType == other.runtimeType &&
          activityId == other.activityId &&
          percentage == other.percentage;

  @override
  int get hashCode => activityId.hashCode ^ percentage.hashCode;
}
