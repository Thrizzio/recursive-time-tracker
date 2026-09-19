import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/chronolog_theme.dart';
import '../../../../shared/utils/time_utils.dart';
import '../log_session_sheet.dart';
import '../tracking_controller.dart';

/// Live tracking control panel with 1-second elapsed clock, start, reset, and log session.
class LiveTrackingCard extends ConsumerWidget {
  const LiveTrackingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingControllerProvider);
    final elapsedDuration = ref.watch(liveElapsedDurationProvider).value ?? Duration.zero;
    final isTracking = trackingState.isTracking;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isTracking
                            ? ChronologTheme.emerald400
                            : ChronologTheme.zinc600,
                        shape: BoxShape.circle,
                        boxShadow: isTracking
                            ? [
                                BoxShadow(
                                  color: ChronologTheme.emerald400.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isTracking ? 'TRACKING ACTIVE' : 'READY TO TRACK',
                      style: TextStyle(
                        color: isTracking
                            ? ChronologTheme.emerald400
                            : ChronologTheme.zinc400,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                if (isTracking)
                  Text(
                    'Started ${TimeUtils.formatTime12h(trackingState.trackingStartedAt!)}',
                    style: const TextStyle(
                      color: ChronologTheme.zinc500,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Live Clock Display
            Center(
              child: Column(
                children: [
                  Text(
                    isTracking
                        ? TimeUtils.formatDigital(elapsedDuration.inSeconds)
                        : '00:00',
                    style: TextStyle(
                      color: isTracking
                          ? ChronologTheme.zinc50
                          : ChronologTheme.zinc600,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTracking
                        ? TimeUtils.formatHumanShort(elapsedDuration.inSeconds)
                        : 'No active session',
                    style: const TextStyle(
                      color: ChronologTheme.zinc400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            if (trackingState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ChronologTheme.red950.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: ChronologTheme.red400.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  trackingState.errorMessage!,
                  style: const TextStyle(
                    color: ChronologTheme.red400,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Control Buttons
            if (trackingState.isLoading) ...[
              const Center(
                child: SizedBox(
                  height: 42,
                  width: 42,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: ChronologTheme.cyan400,
                    ),
                  ),
                ),
              ),
            ] else if (!isTracking) ...[
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(trackingControllerProvider.notifier).startTracking();
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Start Tracking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ChronologTheme.cyan400,
                  foregroundColor: ChronologTheme.zinc950,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: ChronologTheme.zinc900,
                          title: const Text('Reset Tracking?'),
                          content: const Text(
                            'This will discard your currently active tracking session without logging any time.',
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
                              child: const Text('Reset'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        ref.read(trackingControllerProvider.notifier).resetTracking();
                      }
                    },
                    icon: const Icon(Icons.refresh, size: 18, color: ChronologTheme.zinc400),
                    label: const Text(
                      'Reset',
                      style: TextStyle(color: ChronologTheme.zinc300),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ChronologTheme.zinc700),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        LogSessionSheet.show(context, elapsedDuration);
                      },
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text('Log Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChronologTheme.emerald400,
                        foregroundColor: ChronologTheme.zinc950,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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
}
