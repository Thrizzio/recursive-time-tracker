import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/chronolog_theme.dart';
import '../../../../shared/utils/time_utils.dart';
import '../../domain/timer_state.dart';
import '../timer_controller.dart';

/// Dashboard card providing Pomodoro focus session tracking, countdown, and controls.
class PomodoroTimerCard extends ConsumerWidget {
  const PomodoroTimerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(pomodoroTimerProvider);
    final notifier = ref.read(pomodoroTimerProvider.notifier);

    final isStopped = timerState.status == TimerStatus.stopped;
    final isRunning = timerState.status == TimerStatus.running;
    final isPaused = timerState.status == TimerStatus.paused;
    final isCompleted = timerState.status == TimerStatus.completed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status chip
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
                        Icons.timer_outlined,
                        color: ChronologTheme.cyan400,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Focus Timer',
                      style: TextStyle(
                        color: ChronologTheme.zinc50,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(timerState.status),
              ],
            ),
            const SizedBox(height: 12),

            // Active Task Banner (if started from a Google Task)
            if (timerState.activeTaskTitle != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ChronologTheme.cyan950.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: ChronologTheme.cyan400.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.task_alt,
                      color: ChronologTheme.cyan400,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Focusing on: ${timerState.activeTaskTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ChronologTheme.cyan300,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Main Digital Countdown
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  TimeUtils.formatDigital(
                    timerState.remainingDuration.inSeconds,
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.0,
                    color: ChronologTheme.zinc50,
                  ),
                ),
              ),
            ),

            // Linear Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: timerState.progress,
                minHeight: 6,
                backgroundColor: ChronologTheme.zinc800,
                color: isCompleted
                    ? ChronologTheme.emerald400
                    : isPaused
                        ? const Color(0xFFFBBF24)
                        : ChronologTheme.cyan400,
              ),
            ),
            const SizedBox(height: 16),

            // Duration Presets (Enabled when stopped or completed)
            if (isStopped || isCompleted) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDurationPresetChip(
                    label: '25 min',
                    duration: const Duration(minutes: 25),
                    selected: timerState.duration.inMinutes == 25,
                    onTap: () => notifier.setDuration(
                      const Duration(minutes: 25),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildDurationPresetChip(
                    label: '50 min',
                    duration: const Duration(minutes: 50),
                    selected: timerState.duration.inMinutes == 50,
                    onTap: () => notifier.setDuration(
                      const Duration(minutes: 50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Completion Banner
            if (isCompleted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: ChronologTheme.emerald950.withValues(alpha: 0.5),
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
                        'Focus session finished! Time to take a short break.',
                        style: TextStyle(
                          color: ChronologTheme.emerald400,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Controls
            if (isStopped) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => notifier.start(),
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('Start Focus'),
                ),
              ),
            ] else if (isRunning) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => notifier.pause(),
                      icon: const Icon(Icons.pause, size: 20),
                      label: const Text('Pause'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: ChronologTheme.zinc950,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => notifier.reset(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset'),
                    ),
                  ),
                ],
              ),
            ] else if (isPaused) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => notifier.resume(),
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text('Resume'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => notifier.reset(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset'),
                    ),
                  ),
                ],
              ),
            ] else if (isCompleted) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => notifier.start(),
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text('Start Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => notifier.reset(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(TimerStatus status) {
    String label;
    Color bg;
    Color fg;

    switch (status) {
      case TimerStatus.stopped:
        label = 'Ready';
        bg = ChronologTheme.zinc800;
        fg = ChronologTheme.zinc400;
        break;
      case TimerStatus.running:
        label = 'Running';
        bg = ChronologTheme.cyan950;
        fg = ChronologTheme.cyan400;
        break;
      case TimerStatus.paused:
        label = 'Paused';
        bg = const Color(0xFF451A03);
        fg = const Color(0xFFFBBF24);
        break;
      case TimerStatus.completed:
        label = 'Done';
        bg = ChronologTheme.emerald950;
        fg = ChronologTheme.emerald400;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDurationPresetChip({
    required String label,
    required Duration duration,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? ChronologTheme.cyan950.withValues(alpha: 0.6)
              : ChronologTheme.zinc950,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? ChronologTheme.cyan400
                : ChronologTheme.zinc800,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? ChronologTheme.cyan300 : ChronologTheme.zinc400,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
