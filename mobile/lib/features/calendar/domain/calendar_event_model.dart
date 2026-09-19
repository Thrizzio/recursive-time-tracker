import 'package:flutter/foundation.dart';

/// Represents a Google Calendar event for today's agenda.
@immutable
class CalendarEventModel {
  const CalendarEventModel({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.location,
    this.allDay = false,
  });

  final String id;
  final String title;
  final String start;
  final String end;
  final String? location;
  final bool allDay;

  DateTime? get startDateTime => DateTime.tryParse(start);
  DateTime? get endDateTime => DateTime.tryParse(end);

  /// Returns a clean time display string (e.g. "09:30 - 10:30" or "All day").
  String get formattedTimeSpan {
    if (allDay) return 'All day';

    final s = startDateTime?.toLocal();
    final e = endDateTime?.toLocal();

    if (s == null) return '';

    final startStr = _formatTime(s);
    if (e == null) return startStr;

    final endStr = _formatTime(e);
    return '$startStr – $endStr';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    return CalendarEventModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Event',
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
      location: json['location'] as String?,
      allDay: json['allDay'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start,
        'end': end,
        if (location != null) 'location': location,
        'allDay': allDay,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEventModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          start == other.start &&
          end == other.end &&
          location == other.location &&
          allDay == other.allDay;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      start.hashCode ^
      end.hashCode ^
      location.hashCode ^
      allDay.hashCode;

  @override
  String toString() =>
      'CalendarEventModel(id: $id, title: $title, start: $start, end: $end, allDay: $allDay)';
}
