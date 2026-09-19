import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/api_config.dart';
import '../../../core/networking/api_client.dart';
import '../../../shared/theme/chronolog_theme.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/loading_card.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../../calendar/presentation/calendar_controller.dart';
import '../../calendar/presentation/widgets/calendar_agenda_card.dart';
import '../../tasks/presentation/tasks_controller.dart';
import '../../tasks/presentation/widgets/tasks_card.dart';
import '../../tracking/presentation/tracking_controller.dart';
import '../../tracking/presentation/widgets/live_tracking_card.dart';
import '../../tracking/presentation/widgets/today_summary_card.dart';
import '../../tracking/presentation/widgets/today_timeline_card.dart';

/// State of the backend health check.
final healthCheckProvider = FutureProvider.autoDispose<bool>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.checkHealth();
});

/// Dashboard screen representing Chronolog's core time tracking workspace.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(healthCheckProvider);
    final authState = ref.watch(authNotifierProvider);
    final user = authState is Authenticated ? authState.user : null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ChronologTheme.cyan950,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: ChronologTheme.cyan400.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'CHRONOLOG',
                style: TextStyle(
                  color: ChronologTheme.cyan400,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Time Tracker'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: ChronologTheme.cyan400,
          backgroundColor: ChronologTheme.zinc900,
          onRefresh: () async {
            ref.invalidate(healthCheckProvider);
            ref.invalidate(todaySummaryProvider);
            ref.invalidate(todayTimeBlocksProvider);
            ref.invalidate(activitiesListProvider);
            ref.invalidate(tasksProvider);
            ref.invalidate(calendarEventsProvider);
            await ref.read(authNotifierProvider.notifier).checkSession();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Active User Card (Phase 3)
              if (user != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
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
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  color: ChronologTheme.zinc50,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  color: ChronologTheme.zinc400,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: ChronologTheme.emerald950.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: ChronologTheme.emerald400.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'Session Active',
                            style: TextStyle(
                              color: ChronologTheme.emerald400,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Foundation & Connection Status Card
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
                            'API Connection (Phase 2)',
                            style: TextStyle(
                              color: ChronologTheme.zinc50,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            color: ChronologTheme.zinc400,
                            tooltip: 'Ping /health',
                            onPressed: () => ref.invalidate(healthCheckProvider),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Base URL: ${ApiConfig.baseUrl}',
                        style: const TextStyle(
                          color: ChronologTheme.zinc400,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 12),
                      healthState.when(
                        loading: () => const LoadingCard(
                          message: 'Pinging backend /health...',
                          height: 60,
                        ),
                        error: (err, _) => ErrorRetry(
                          title: 'Connection check failed',
                          message: err.toString(),
                          onRetry: () => ref.invalidate(healthCheckProvider),
                        ),
                        data: (isHealthy) {
                          if (isHealthy) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: ChronologTheme.emerald950.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: ChronologTheme.emerald400.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: ChronologTheme.emerald400,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Backend reachable: /health returned 200 OK',
                                      style: TextStyle(
                                        color: ChronologTheme.emerald400,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: ChronologTheme.red950.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: ChronologTheme.red400.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.cancel_outlined,
                                    color: ChronologTheme.red400,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Backend offline or unreachable at this URL',
                                      style: TextStyle(
                                        color: ChronologTheme.red400,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Live Tracking Control Panel (Phase 4a)
              const LiveTrackingCard(),

              const SizedBox(height: 16),

              // Google Tasks Card (Phase 4b)
              const TasksCard(),

              const SizedBox(height: 16),

              // Today's Google Calendar Agenda (Phase 4b)
              const CalendarAgendaCard(),

              const SizedBox(height: 16),

              // Today's Summary (Phase 4a)
              const TodaySummaryCard(),

              const SizedBox(height: 16),

              // Today's Timeline (Phase 4a)
              const TodayTimelineCard(),
            ],
          ),
        ),
      ),
    );
  }
}
