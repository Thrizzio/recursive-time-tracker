import 'package:flutter/foundation.dart';

/// Represents an activity category (e.g. "Coding", "Reading", "Deep Work").
@immutable
class ActivityModel {
  const ActivityModel({
    required this.id,
    required this.name,
    required this.color,
    this.userId,
    this.createdAt,
  });

  final int id;
  final String name;
  final String color;
  final int? userId;
  final DateTime? createdAt;

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '#06b6d4',
      userId: json['userId'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        if (userId != null) 'userId': userId,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          color == other.color;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ color.hashCode;

  @override
  String toString() => 'ActivityModel(id: $id, name: $name, color: $color)';
}
