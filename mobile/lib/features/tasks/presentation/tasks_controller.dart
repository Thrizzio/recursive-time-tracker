import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../data/tasks_repository.dart';
import '../domain/task_list_model.dart';
import '../domain/task_model.dart';

/// Provider for incomplete tasks in the user's selected list.
final tasksProvider = FutureProvider.autoDispose<List<TaskModel>>((ref) async {
  final repo = ref.watch(tasksRepositoryProvider);
  return repo.getTasks();
});

/// Provider for all available Google Task Lists.
final taskListsProvider =
    FutureProvider.autoDispose<List<TaskListModel>>((ref) async {
  final repo = ref.watch(tasksRepositoryProvider);
  return repo.getTaskLists();
});

/// Set of task IDs currently being marked as completed.
final completingTaskIdsProvider =
    NotifierProvider<CompletingTaskIdsNotifier, Set<String>>(() {
  return CompletingTaskIdsNotifier();
});

class CompletingTaskIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void markStarted(String taskId) {
    state = {...state, taskId};
  }

  void markFinished(String taskId) {
    final next = Set<String>.from(state);
    next.remove(taskId);
    state = next;
  }
}

/// Provider for task action operations (completing tasks, selecting default list).
final tasksActionControllerProvider = Provider<TasksActionController>((ref) {
  return TasksActionController(ref);
});

class TasksActionController {
  TasksActionController(this._ref);

  final Ref _ref;
  TasksRepository get _repo => _ref.read(tasksRepositoryProvider);

  /// Completes a task in Google Tasks and refreshes the task list.
  Future<void> completeTask(String taskId) async {
    final completingNotifier =
        _ref.read(completingTaskIdsProvider.notifier);
    completingNotifier.markStarted(taskId);

    try {
      await _repo.completeTasks([taskId]);
      // Invalidate to fetch fresh list without the completed task
      _ref.invalidate(tasksProvider);
    } catch (e) {
      debugPrint('[TasksActionController] Failed to complete task $taskId: $e');
      rethrow;
    } finally {
      completingNotifier.markFinished(taskId);
    }
  }

  /// Sets user's default Google Task List preference and updates user state.
  Future<void> selectTaskList(String taskListId) async {
    try {
      await _repo.selectTaskList(taskListId);

      // Update local user state immediately
      final authState = _ref.read(authNotifierProvider);
      if (authState is Authenticated) {
        _ref
            .read(authNotifierProvider.notifier)
            .updateUser(authState.user.copyWith(selectedTaskListId: taskListId));
      }

      // Invalidate tasks so they are re-fetched from the newly chosen list
      _ref.invalidate(tasksProvider);
    } catch (e) {
      debugPrint('[TasksActionController] Failed to set task list: $e');
      rethrow;
    }
  }
}

