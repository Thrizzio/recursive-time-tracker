import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/activities_repository.dart';
import '../domain/activity_model.dart';
import '../../tracking/presentation/tracking_controller.dart';

/// Provider for activities list.
final activitiesProvider =
    FutureProvider.autoDispose<List<ActivityModel>>((ref) async {
  final repo = ref.watch(activitiesRepositoryProvider);
  return repo.getActivities();
});

/// Provider for activities action operations (creating activities).
final activitiesActionControllerProvider =
    Provider<ActivitiesActionController>((ref) {
  return ActivitiesActionController(ref);
});

class ActivitiesActionController {
  ActivitiesActionController(this._ref);

  final Ref _ref;
  ActivitiesRepository get _repo => _ref.read(activitiesRepositoryProvider);

  /// Creates a new activity and refreshes the activities caches.
  Future<ActivityModel> createActivity({
    required String name,
    required String color,
  }) async {
    try {
      final created = await _repo.createActivity(
        name: name,
        color: color,
      );

      // Invalidate both activities providers to keep UI in sync
      _ref.invalidate(activitiesProvider);
      _ref.invalidate(activitiesListProvider);

      return created;
    } catch (e) {
      debugPrint('[ActivitiesActionController] Failed to create activity: $e');
      rethrow;
    }
  }
}
