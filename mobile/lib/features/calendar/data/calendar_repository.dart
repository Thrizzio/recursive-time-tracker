import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../domain/calendar_event_model.dart';

/// Provider for [CalendarRepository].
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CalendarRepository(apiClient: apiClient);
});

/// Repository for Google Calendar agenda events.
class CalendarRepository {
  CalendarRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Fetches Google Calendar events for the current day (`GET /google/calendar`).
  Future<List<CalendarEventModel>> getTodayEvents([DateTime? targetDate]) async {
    final now = targetDate ?? DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc();
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc();

    final res = await apiClient.get<List<dynamic>>(
      '/google/calendar',
      queryParameters: {
        'start': startOfDay.toIso8601String(),
        'end': endOfDay.toIso8601String(),
      },
    );

    final list = res.data ?? [];
    return list
        .map((item) => CalendarEventModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

