import 'package:flutter/foundation.dart';
import 'time_allocation_model.dart';

/// Represents a finalized tracking block with start/end time and allocations.
@immutable
class TimeBlockModel {
  const TimeBlockModel({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    required this.elapsedSeconds,
    this.allocations = const [],
  });

  final int id;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdAt;
  final int elapsedSeconds;
  final List<TimeAllocationModel> allocations;

  factory TimeBlockModel.fromJson(Map<String, dynamic> json) {
    return TimeBlockModel(
      id: json['id'] as int,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
      allocations: (json['allocations'] as List<dynamic>? ?? [])
          .map((a) => TimeAllocationModel.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeBlockModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
