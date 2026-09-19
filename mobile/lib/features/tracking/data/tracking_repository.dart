import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../../activities/domain/activity_model.dart';
import '../domain/time_block_model.dart';
import '../domain/time_summary_model.dart';

/// Provider for [TrackingRepository].
final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TrackingRepository(apiClient: apiClient);
});

/// Repository for time tracking, log-session, time blocks, and daily summary.
class TrackingRepository {
  TrackingRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Fetches user activities (`GET /activities`).
  Future<List<ActivityModel>> getActivities() async {
    final res = await apiClient.get<List<dynamic>>('/activities');
    final list = res.data ?? [];
    return list
        .map((item) => ActivityModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Starts or resumes tracking session (`POST /tracking/start`).
  Future<DateTime> startTracking() async {
    final res = await apiClient.post<Map<String, dynamic>>('/tracking/start');
    final startedAtStr = res.data?['trackingStartedAt'] as String?;
    if (startedAtStr == null) {
      throw StateError('Server did not return trackingStartedAt.');
    }
    return DateTime.parse(startedAtStr);
  }

  /// Resets/discards the current tracking session (`POST /tracking/reset`).
  Future<void> resetTracking() async {
    await apiClient.post('/tracking/reset');
  }

  /// Logs the current session with activity allocations (`POST /log-session`).
  Future<TimeBlockModel> logSession({
    required List<Map<String, dynamic>> allocations,
  }) async {
    final res = await apiClient.post<Map<String, dynamic>>(
      '/log-session',
      data: {'allocations': allocations},
    );

    final blockData = res.data?['block'] as Map<String, dynamic>?;
    if (blockData == null) {
      throw StateError('Server did not return created time block.');
    }

    return TimeBlockModel.fromJson(blockData);
  }

  /// Fetches daily time summary (`GET /time-summary`).
  Future<TimeSummaryModel> getTimeSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, dynamic>{};
    if (startDate != null) query['startDate'] = startDate.toIso8601String();
    if (endDate != null) query['endDate'] = endDate.toIso8601String();

    final res = await apiClient.get<Map<String, dynamic>>(
      '/time-summary',
      queryParameters: query.isNotEmpty ? query : null,
    );

    final data = res.data;
    if (data == null) {
      throw StateError('Failed to fetch time summary data.');
    }

    return TimeSummaryModel.fromJson(data);
  }

  /// Fetches time blocks (`GET /time-blocks`).
  Future<List<TimeBlockModel>> getTimeBlocks({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, dynamic>{};
    if (startDate != null) query['startDate'] = startDate.toIso8601String();
    if (endDate != null) query['endDate'] = endDate.toIso8601String();

    final res = await apiClient.get<List<dynamic>>(
      '/time-blocks',
      queryParameters: query.isNotEmpty ? query : null,
    );

    final list = res.data ?? [];
    return list
        .map((item) => TimeBlockModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
