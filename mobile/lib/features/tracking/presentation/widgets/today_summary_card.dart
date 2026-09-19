import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/chronolog_theme.dart';
import '../../../../shared/utils/color_utils.dart';
import '../../../../shared/utils/time_utils.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/loading_card.dart';
import '../tracking_controller.dart';

/// Renders aggregated activity totals, percentages, and progress bars for today.
class TodaySummaryCard extends ConsumerWidget {
  const TodaySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(todaySummaryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Summary",
                  style: TextStyle(
                    color: ChronologTheme.zinc50,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  color: ChronologTheme.zinc400,
                  tooltip: 'Refresh summary',
                  onPressed: () => ref.invalidate(todaySummaryProvider),
                ),
              ],
            ),
            const SizedBox(height: 8),
            summaryAsync.when(
              loading: () => const LoadingCard(
                message: 'Calculating today\'s time totals...',
                height: 100,
              ),
              error: (err, _) => ErrorRetry(
                title: 'Could not load summary',
                message: err.toString(),
                onRetry: () => ref.invalidate(todaySummaryProvider),
              ),
              data: (summary) {
                final hasData = summary.totalTrackedSeconds > 0 ||
                    summary.activities.isNotEmpty;

                if (!hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No time logged today yet. Start tracking above!',
                        style: TextStyle(
                          color: ChronologTheme.zinc500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          TimeUtils.formatHumanShort(summary.totalTrackedSeconds),
                          style: const TextStyle(
                            color: ChronologTheme.cyan400,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'tracked today',
                          style: TextStyle(
                            color: ChronologTheme.zinc400,
                            fontSize: 13,
                          ),
                        ),
                        if (summary.hasActiveTracking &&
                            summary.activeTrackingSeconds > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(+ ${TimeUtils.formatHumanShort(summary.activeTrackingSeconds)} active)',
                            style: const TextStyle(
                              color: ChronologTheme.emerald400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: summary.activities.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = summary.activities[index];
                        final color = ColorUtils.parseHexColor(item.color);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        color: ChronologTheme.zinc200,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      TimeUtils.formatHumanShort(item.totalSeconds),
                                      style: const TextStyle(
                                        color: ChronologTheme.zinc400,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${item.percentage}%',
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: (item.percentage / 100).clamp(0.0, 1.0),
                                backgroundColor: ChronologTheme.zinc800,
                                color: color,
                                minHeight: 6,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
