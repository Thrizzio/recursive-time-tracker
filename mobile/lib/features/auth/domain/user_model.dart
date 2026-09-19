import 'package:flutter/foundation.dart';

/// Represents an authenticated Chronolog user.
@immutable
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.trackingStartedAt,
    this.selectedTaskListId,
  });

  final int id;
  final String email;
  final String name;
  final String? avatarUrl;
  final DateTime? trackingStartedAt;
  final String? selectedTaskListId;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      trackingStartedAt: json['trackingStartedAt'] != null
          ? DateTime.tryParse(json['trackingStartedAt'] as String)
          : null,
      selectedTaskListId: json['selectedTaskListId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'trackingStartedAt': trackingStartedAt?.toIso8601String(),
      'selectedTaskListId': selectedTaskListId,
    };
  }

  UserModel copyWith({
    int? id,
    String? email,
    String? name,
    String? avatarUrl,
    DateTime? trackingStartedAt,
    String? selectedTaskListId,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      trackingStartedAt: trackingStartedAt ?? this.trackingStartedAt,
      selectedTaskListId: selectedTaskListId ?? this.selectedTaskListId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          name == other.name &&
          avatarUrl == other.avatarUrl &&
          trackingStartedAt == other.trackingStartedAt &&
          selectedTaskListId == other.selectedTaskListId;

  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      name.hashCode ^
      avatarUrl.hashCode ^
      trackingStartedAt.hashCode ^
      selectedTaskListId.hashCode;

  @override
  String toString() =>
      'UserModel(id: $id, email: $email, name: $name, avatarUrl: $avatarUrl)';
}

