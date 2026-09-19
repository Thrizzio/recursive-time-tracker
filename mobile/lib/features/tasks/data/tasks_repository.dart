import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../domain/task_list_model.dart';
import '../domain/task_model.dart';

/// Provider for [TasksRepository].
final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TasksRepository(apiClient: apiClient);
});

/// Repository handling Google Tasks data access and mutations.
class TasksRepository {
  TasksRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Fetches available Google Task Lists (`GET /tasks/lists`).
  Future<List<TaskListModel>> getTaskLists() async {
    final res = await apiClient.get<List<dynamic>>('/tasks/lists');
    final list = res.data ?? [];
    return list
        .map((item) => TaskListModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetches incomplete tasks from user's selected list (`GET /tasks`).
  /// Returns empty list if no task list has been selected yet.
  Future<List<TaskModel>> getTasks() async {
    final res = await apiClient.get<List<dynamic>>('/tasks');
    final list = res.data ?? [];
    return list
        .map((item) => TaskModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Marks specified task IDs as completed in Google Tasks (`POST /tasks/complete`).
  Future<void> completeTasks(List<String> taskIds) async {
    if (taskIds.isEmpty) return;
    await apiClient.post(
      '/tasks/complete',
      data: {'taskIds': taskIds},
    );
  }

  /// Updates the user's default Google Task List preference (`POST /settings/task-list`).
  Future<void> selectTaskList(String taskListId) async {
    await apiClient.post(
      '/settings/task-list',
      data: {'taskListId': taskListId.trim()},
    );
  }
}

