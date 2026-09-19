import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_event_model.dart';

/// Provider for today's Google Calendar agenda events.
final calendarEventsProvider =
    FutureProvider.autoDispose<List<CalendarEventModel>>((ref) async {
  final repo = ref.watch(calendarRepositoryProvider);
  return repo.getTodayEvents();
});
