import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/chronolog_theme.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/loading_card.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_state.dart';
import '../../../timer/presentation/timer_controller.dart';
import '../tasks_controller.dart';

/// Dashboard card displaying incomplete Google Tasks with completion action.
class TasksCard extends ConsumerWidget {
  const TasksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is Authenticated ? authState.user : null;
    final selectedListId = user?.selectedTaskListId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ChronologTheme.cyan950,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: ChronologTheme.cyan400,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tasks',
                      style: TextStyle(
                        color: ChronologTheme.zinc50,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      color: ChronologTheme.zinc400,
                      tooltip: 'Refresh tasks',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => ref.invalidate(tasksProvider),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      color: ChronologTheme.zinc400,
                      tooltip: 'Change task list',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => context.push('/settings'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Content depending on selected task list
            if (selectedListId == null || selectedListId.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ChronologTheme.zinc950,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ChronologTheme.zinc800),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.playlist_add_check,
                      color: ChronologTheme.zinc500,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No task list selected',
                      style: TextStyle(
                        color: ChronologTheme.zinc200,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose which Google Task List to display on your dashboard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ChronologTheme.zinc400,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/settings'),
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Select Task List'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Consumer(
                builder: (context, ref, child) {
                  final tasksAsync = ref.watch(tasksProvider);
                  final completingIds = ref.watch(completingTaskIdsProvider);

                  return tasksAsync.when(
                    loading: () => const LoadingCard(
                      message: 'Loading tasks from Google...',
                      height: 80,
                    ),
                    error: (err, _) => ErrorRetry(
                      title: 'Could not load tasks',
                      message: err.toString(),
                      onRetry: () => ref.invalidate(tasksProvider),
                    ),
                    data: (tasks) {
                      if (tasks.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: ChronologTheme.zinc950,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ChronologTheme.zinc800),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.task_alt,
                                color: ChronologTheme.emerald400,
                                size: 30,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'All caught up!',
                                style: TextStyle(
                                  color: ChronologTheme.zinc200,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'No incomplete tasks in this list.',
                                style: TextStyle(
                                  color: ChronologTheme.zinc500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tasks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final isCompleting = completingIds.contains(task.id);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ChronologTheme.zinc950,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ChronologTheme.zinc800),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Checkbox / Completing spinner
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: isCompleting
                                      ? const Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: ChronologTheme.cyan400,
                                            ),
                                          ),
                                        )
                                      : IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(
                                            Icons.radio_button_unchecked,
                                            color: ChronologTheme.zinc500,
                                            size: 20,
                                          ),
                                          tooltip: 'Mark complete',
                                          onPressed: () async {
                                            try {
                                              await ref
                                                  .read(
                                                    tasksActionControllerProvider,
                                                  )
                                                  .completeTask(task.id);
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Failed to complete task: $e',
                                                    ),
                                                    backgroundColor:
                                                        ChronologTheme.red950,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () {
                                      ref
                                          .read(pomodoroTimerProvider.notifier)
                                          .startFocusForTask(
                                            taskId: task.id,
                                            taskTitle: task.title,
                                          );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Started focus timer for "${task.title}"',
                                          ),
                                          backgroundColor:
                                              ChronologTheme.cyan950,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.title,
                                          style: const TextStyle(
                                            color: ChronologTheme.zinc200,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (task.notes != null &&
                                            task.notes!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            task.notes!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: ChronologTheme.zinc500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                        if (task.due != null) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.event,
                                                size: 12,
                                                color: ChronologTheme.cyan400,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatDueDate(task.due!),
                                                style: const TextStyle(
                                                  color: ChronologTheme.cyan400,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.timer_outlined,
                                    color: ChronologTheme.zinc500,
                                    size: 18,
                                  ),
                                  tooltip: 'Start focus timer',
                                  onPressed: () {
                                    ref
                                        .read(pomodoroTimerProvider.notifier)
                                        .startFocusForTask(
                                          taskId: task.id,
                                          taskTitle: task.title,
                                        );
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Started focus timer for "${task.title}"',
                                        ),
                                        backgroundColor:
                                            ChronologTheme.cyan950,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDueDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return 'Due: ${months[local.month - 1]} ${local.day}';
  }
}
