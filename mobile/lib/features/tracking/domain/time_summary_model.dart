import 'package:flutter/foundation.dart';

/// Single activity slice inside a daily time summary.
@immutable
class ActivitySummaryItem {
  const ActivitySummaryItem({
    required this.id,
    required this.name,
    required this.color,
    required this.totalSeconds,
    required this.percentage,
  });

  final int id;
  final String name;
  final String color;
  final int totalSeconds;
  final int percentage;

  factory ActivitySummaryItem.fromJson(Map<String, dynamic> json) {
    return ActivitySummaryItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '#06b6d4',
      totalSeconds: json['totalSeconds'] as int? ?? 0,
      percentage: json['percentage'] as int? ?? 0,
    );
  }
}

/// Aggregated time summary for a given day window.
@immutable
class TimeSummaryModel {
  const TimeSummaryModel({
    required this.startDate,
    required this.endDate,
    required this.totalTrackedSeconds,
    required this.finalizedSeconds,
    required this.activeTrackingSeconds,
    required this.hasActiveTracking,
    this.activeTrackingStartedAt,
    this.activities = const [],
  });

  final DateTime startDate;
  final DateTime endDate;
  final int totalTrackedSeconds;
  final int finalizedSeconds;
  final int activeTrackingSeconds;
  final bool hasActiveTracking;
  final DateTime? activeTrackingStartedAt;
  final List<ActivitySummaryItem> activities;

  factory TimeSummaryModel.fromJson(Map<String, dynamic> json) {
    return TimeSummaryModel(
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      totalTrackedSeconds: json['totalTrackedSeconds'] as int? ?? 0,
      finalizedSeconds: json['finalizedSeconds'] as int? ?? 0,
      activeTrackingSeconds: json['activeTrackingSeconds'] as int? ?? 0,
      hasActiveTracking: json['hasActiveTracking'] as bool? ?? false,
      activeTrackingStartedAt: json['activeTrackingStartedAt'] != null
          ? DateTime.tryParse(json['activeTrackingStartedAt'] as String)
          : null,
      activities: (json['activities'] as List<dynamic>? ?? [])
          .map((a) => ActivitySummaryItem.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}
