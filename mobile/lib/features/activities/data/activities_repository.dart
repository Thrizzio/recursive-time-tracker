import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../domain/activity_model.dart';

/// Provider for [ActivitiesRepository].
final activitiesRepositoryProvider = Provider<ActivitiesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ActivitiesRepository(apiClient: apiClient);
});

/// Repository handling Activity management (CRUD).
class ActivitiesRepository {
  ActivitiesRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Fetches all user activities (`GET /activities`).
  Future<List<ActivityModel>> getActivities() async {
    final res = await apiClient.get<List<dynamic>>('/activities');
    final list = res.data ?? [];
    return list
        .map((item) => ActivityModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new user activity (`POST /activities`).
  Future<ActivityModel> createActivity({
    required String name,
    required String color,
  }) async {
    final res = await apiClient.post<Map<String, dynamic>>(
      '/activities',
      data: {
        'name': name.trim(),
        'color': color.trim(),
      },
    );

    final data = res.data;
    if (data == null) {
      throw StateError('Server did not return created activity data.');
    }

    return ActivityModel.fromJson(data);
  }
}

