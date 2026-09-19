import 'package:flutter/foundation.dart';

/// Represents an incomplete or completed task from Google Tasks.
@immutable
class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    this.notes,
    this.due,
    this.status = 'needsAction',
  });

  final String id;
  final String title;
  final String? notes;
  final String? due;
  final String status;

  bool get isCompleted => status == 'completed';

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String?,
      due: json['due'] as String?,
      status: json['status'] as String? ?? 'needsAction',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (notes != null) 'notes': notes,
        if (due != null) 'due': due,
        'status': status,
      };

  TaskModel copyWith({
    String? id,
    String? title,
    String? notes,
    String? due,
    String? status,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      due: due ?? this.due,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          notes == other.notes &&
          due == other.due &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      notes.hashCode ^
      due.hashCode ^
      status.hashCode;

  @override
  String toString() =>
      'TaskModel(id: $id, title: $title, status: $status, due: $due)';
}
