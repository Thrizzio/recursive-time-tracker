import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/auth_config.dart';
import '../../../shared/theme/chronolog_theme.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/loading_card.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../../tasks/presentation/tasks_controller.dart';

/// Screen for app settings, user profile, Google account status, and task list configuration.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _savingListId;

  Future<void> _handleSelectList(String listId) async {
    setState(() {
      _savingListId = listId;
    });

    try {
      await ref
          .read(tasksActionControllerProvider)
          .selectTaskList(listId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default task list updated!'),
            backgroundColor: ChronologTheme.emerald950,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task list: $e'),
            backgroundColor: ChronologTheme.red950,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingListId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is Authenticated ? authState.user : null;
    final taskListsAsync = ref.watch(taskListsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User Profile Card
            if (user != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: ChronologTheme.cyan950,
                        backgroundImage: user.avatarUrl != null
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl == null
                            ? Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: ChronologTheme.cyan400,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                color: ChronologTheme.zinc50,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: const TextStyle(
                                color: ChronologTheme.zinc400,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'User ID: #${user.id}',
                              style: const TextStyle(
                                color: ChronologTheme.zinc500,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Default Task List Selection Card (Phase 4b)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Default Task List',
                          style: TextStyle(
                            color: ChronologTheme.zinc50,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          color: ChronologTheme.zinc400,
                          tooltip: 'Refresh task lists',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => ref.invalidate(taskListsProvider),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select which Google Task List to display on your dashboard.',
                      style: TextStyle(
                        color: ChronologTheme.zinc400,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),

                    taskListsAsync.when(
                      loading: () => const LoadingCard(
                        message: 'Loading Google Task lists...',
                        height: 70,
                      ),
                      error: (err, _) => ErrorRetry(
                        title: 'Could not load task lists',
                        message: err.toString(),
                        onRetry: () => ref.invalidate(taskListsProvider),
                      ),
                      data: (lists) {
                        if (lists.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: ChronologTheme.zinc950,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ChronologTheme.zinc800),
                            ),
                            child: const Text(
                              'No task lists found in your Google account.',
                              style: TextStyle(
                                color: ChronologTheme.zinc400,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: lists.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final list = lists[index];
                            final isSelected =
                                user?.selectedTaskListId == list.id;
                            final isSavingThis = _savingListId == list.id;

                            return InkWell(
                              onTap: isSavingThis
                                  ? null
                                  : () => _handleSelectList(list.id),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? ChronologTheme.cyan950.withValues(
                                          alpha: 0.6,
                                        )
                                      : ChronologTheme.zinc950,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? ChronologTheme.cyan400
                                        : ChronologTheme.zinc800,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        list.title,
                                        style: TextStyle(
                                          color: isSelected
                                              ? ChronologTheme.zinc50
                                              : ChronologTheme.zinc300,
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    if (isSavingThis)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: ChronologTheme.cyan400,
                                        ),
                                      )
                                    else if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: ChronologTheme.cyan400,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Environment & Configuration Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'API Environment',
                      style: TextStyle(
                        color: ChronologTheme.zinc50,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Target URL: ${ApiConfig.baseUrl}',
                      style: const TextStyle(
                        color: ChronologTheme.zinc400,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Server Client ID: ${AuthConfig.serverClientId.isNotEmpty ? '${AuthConfig.serverClientId.substring(0, 12)}...' : '(not configured)'}',
                      style: const TextStyle(
                        color: ChronologTheme.zinc500,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notifications Status (Phase 7)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications (Phase 7)',
                      style: TextStyle(
                        color: ChronologTheme.zinc50,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Local 2-hour reminders and Pomodoro timer completion notifications will be configurable here.',
                      style: TextStyle(
                        color: ChronologTheme.zinc400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Logout Action Button
            if (user != null) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: ChronologTheme.zinc900,
                      title: const Text('Log out of Chronolog?'),
                      content: const Text(
                        'This will invalidate your current session and clear local credentials.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor: ChronologTheme.red400,
                          ),
                          child: const Text('Log out'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await ref.read(authNotifierProvider.notifier).logout();
                  }
                },
                icon: const Icon(
                  Icons.logout,
                  color: ChronologTheme.red400,
                  size: 20,
                ),
                label: const Text(
                  'Log out',
                  style: TextStyle(color: ChronologTheme.red400),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ChronologTheme.red950),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
