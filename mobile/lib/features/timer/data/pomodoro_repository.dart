import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../domain/pomodoro_model.dart';

final pomodoroRepositoryProvider = Provider<PomodoroRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PomodoroRepository(apiClient: apiClient);
});

class PomodoroRepository {
  PomodoroRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<PomodoroPlanModel?> getCurrentPlan() async {
    final response = await apiClient.get('/pomodoro/current');
    final data = response.data as Map<String, dynamic>;
    final planJson = data['plan'] as Map<String, dynamic>?;
    if (planJson == null) return null;
    return PomodoroPlanModel.fromJson(planJson);
  }

  Future<PomodoroPlanModel> startPlan({
    int totalSessions = 4,
    int focusDurationSeconds = 1500,
    int shortBreakDurationSeconds = 300,
    int longBreakDurationSeconds = 900,
    int longBreakInterval = 4,
    bool autoStartBreaks = false,
    bool autoStartFocus = false,
    String? taskId,
    String? taskTitle,
  }) async {
    final response = await apiClient.post(
      '/pomodoro/start',
      data: {
        'totalSessions': totalSessions,
        'focusDurationSeconds': focusDurationSeconds,
        'shortBreakDurationSeconds': shortBreakDurationSeconds,
        'longBreakDurationSeconds': longBreakDurationSeconds,
        'longBreakInterval': longBreakInterval,
        'autoStartBreaks': autoStartBreaks,
        'autoStartFocus': autoStartFocus,
        'taskId': ?taskId,
        'taskTitle': ?taskTitle,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return PomodoroPlanModel.fromJson(data['plan'] as Map<String, dynamic>);
  }

  Future<PomodoroPlanModel> pausePlan([int? planId]) async {
    final response = await apiClient.post(
      '/pomodoro/pause',
      data: {
        'planId': ?planId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return PomodoroPlanModel.fromJson(data['plan'] as Map<String, dynamic>);
  }

  Future<PomodoroPlanModel> resumePlan([int? planId]) async {
    final response = await apiClient.post(
      '/pomodoro/resume',
      data: {
        'planId': ?planId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return PomodoroPlanModel.fromJson(data['plan'] as Map<String, dynamic>);
  }

  Future<PomodoroPlanModel> nextPhase([int? planId]) async {
    final response = await apiClient.post(
      '/pomodoro/next',
      data: {
        'planId': ?planId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return PomodoroPlanModel.fromJson(data['plan'] as Map<String, dynamic>);
  }

  Future<PomodoroPlanModel> skipPhase([int? planId]) async {
    final response = await apiClient.post(
      '/pomodoro/skip',
      data: {
        'planId': ?planId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return PomodoroPlanModel.fromJson(data['plan'] as Map<String, dynamic>);
  }

  Future<PomodoroPlanModel> cancelPlan([int? planId]) async {
    final response = await apiClient.post(
      '/pomodoro/cancel',
      data: {
        'planId': ?planId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return PomodoroPlanModel.fromJson(data['plan'] as Map<String, dynamic>);
  }
}
