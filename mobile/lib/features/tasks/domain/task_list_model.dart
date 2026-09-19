import 'package:flutter/foundation.dart';

/// Represents a Google Task List metadata container.
@immutable
class TaskListModel {
  const TaskListModel({
    required this.id,
    required this.title,
  });

  final String id;
  final String title;

  factory TaskListModel.fromJson(Map<String, dynamic> json) {
    return TaskListModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled List',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskListModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title;

  @override
  int get hashCode => id.hashCode ^ title.hashCode;

  @override
  String toString() => 'TaskListModel(id: $id, title: $title)';
}

