import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/utils/time_utils.dart';
import '../../activities/domain/activity_model.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../data/tracking_repository.dart';
import '../domain/time_block_model.dart';
import '../domain/time_summary_model.dart';

/// Provider for user activities list.
final activitiesListProvider =
    FutureProvider.autoDispose<List<ActivityModel>>((ref) async {
  final repo = ref.watch(trackingRepositoryProvider);
  return repo.getActivities();
});

/// Provider for today's summary.
final todaySummaryProvider =
    FutureProvider.autoDispose<TimeSummaryModel>((ref) async {
  final repo = ref.watch(trackingRepositoryProvider);
  final now = DateTime.now();
  return repo.getTimeSummary(
    startDate: TimeUtils.startOfDay(now),
    endDate: TimeUtils.endOfDay(now),
  );
});

/// Provider for today's time blocks.
final todayTimeBlocksProvider =
    FutureProvider.autoDispose<List<TimeBlockModel>>((ref) async {
  final repo = ref.watch(trackingRepositoryProvider);
  final now = DateTime.now();
  return repo.getTimeBlocks(
    startDate: TimeUtils.startOfDay(now),
    endDate: TimeUtils.endOfDay(now),
  );
});

/// State of current live tracking.
class TrackingState {
  const TrackingState({
    required this.trackingStartedAt,
    this.isLoading = false,
    this.errorMessage,
  });

  final DateTime? trackingStartedAt;
  final bool isLoading;
  final String? errorMessage;

  bool get isTracking => trackingStartedAt != null;

  TrackingState copyWith({
    DateTime? trackingStartedAt,
    bool? clearTrackingStartedAt,
    bool? isLoading,
    String? errorMessage,
    bool? clearError,
  }) {
    return TrackingState(
      trackingStartedAt: clearTrackingStartedAt == true
          ? null
          : (trackingStartedAt ?? this.trackingStartedAt),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError == true ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Notifier managing start/reset tracking and session logging.
final trackingControllerProvider =
    NotifierProvider<TrackingController, TrackingState>(() {
  return TrackingController();
});

class TrackingController extends Notifier<TrackingState> {
  @override
  TrackingState build() {
    // Synchronize initial tracking state with authenticated user profile
    final auth = ref.watch(authNotifierProvider);
    final startedAt = auth is Authenticated ? auth.user.trackingStartedAt : null;
    return TrackingState(trackingStartedAt: startedAt);
  }

  TrackingRepository get _repo => ref.read(trackingRepositoryProvider);

  /// Updates tracking started timestamp from sync/WebSocket events.
  void setTrackingStartedAt(DateTime? startedAt) {
    if (startedAt == null) {
      state = state.copyWith(clearTrackingStartedAt: true);
    } else {
      state = state.copyWith(trackingStartedAt: startedAt);
    }
  }

  /// Starts or resumes tracking session.
  Future<void> startTracking() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final startedAt = await _repo.startTracking();
      state = state.copyWith(trackingStartedAt: startedAt, isLoading: false);

      // Update user entity in auth notifier
      _syncAuthUser(startedAt);
      _refreshDashboardData();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Resets/discards current tracking session.
  Future<void> resetTracking() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.resetTracking();
      state = state.copyWith(clearTrackingStartedAt: true, isLoading: false);

      // Update user entity in auth notifier
      _syncAuthUser(null);
      _refreshDashboardData();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Logs session with activity allocations.
  Future<TimeBlockModel> logSession(List<Map<String, dynamic>> allocations) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final block = await _repo.logSession(allocations: allocations);

      // The backend sets trackingStartedAt to block.endTime to start the next contiguous block
      state = state.copyWith(
        trackingStartedAt: block.endTime,
        isLoading: false,
      );

      _syncAuthUser(block.endTime);
      _refreshDashboardData();
      return block;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  void _syncAuthUser(DateTime? trackingStartedAt) {
    final auth = ref.read(authNotifierProvider);
    if (auth is Authenticated) {
      // Re-fetch or update auth state user
      ref.read(authNotifierProvider.notifier).checkSession();
    }
  }

  void _refreshDashboardData() {
    ref.invalidate(todaySummaryProvider);
    ref.invalidate(todayTimeBlocksProvider);
  }
}

/// 1-second periodic tick for live elapsed tracking clock.
/// Always computes elapsed seconds from DateTime.now().difference(trackingStartedAt).
final liveElapsedDurationProvider = StreamProvider.autoDispose<Duration>((ref) {
  final trackingState = ref.watch(trackingControllerProvider);
  final startedAt = trackingState.trackingStartedAt;

  if (startedAt == null) {
    return Stream.value(Duration.zero);
  }

  return Stream.periodic(const Duration(seconds: 1), (_) {
    final diff = DateTime.now().difference(startedAt);
    return diff.isNegative ? Duration.zero : diff;
  });
});
