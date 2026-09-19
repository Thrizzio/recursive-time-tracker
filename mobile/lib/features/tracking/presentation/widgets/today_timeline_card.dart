import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/chronolog_theme.dart';
import '../../../../shared/utils/color_utils.dart';
import '../../../../shared/utils/time_utils.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/loading_card.dart';
import '../../domain/time_block_model.dart';
import '../tracking_controller.dart';

/// Renders today's logged time blocks ordered newest first with allocation badges.
class TodayTimelineCard extends ConsumerWidget {
  const TodayTimelineCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(todayTimeBlocksProvider);

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
                  "Today's Timeline",
                  style: TextStyle(
                    color: ChronologTheme.zinc50,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  color: ChronologTheme.zinc400,
                  tooltip: 'Refresh timeline',
                  onPressed: () => ref.invalidate(todayTimeBlocksProvider),
                ),
              ],
            ),
            const SizedBox(height: 8),
            blocksAsync.when(
              loading: () => const LoadingCard(
                message: 'Loading timeline entries...',
                height: 120,
              ),
              error: (err, _) => ErrorRetry(
                title: 'Could not load timeline',
                message: err.toString(),
                onRetry: () => ref.invalidate(todayTimeBlocksProvider),
              ),
              data: (blocks) {
                if (blocks.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No time blocks logged today yet.',
                        style: TextStyle(
                          color: ChronologTheme.zinc500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: blocks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final block = blocks[index];
                    return _TimelineBlockTile(block: block);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineBlockTile extends StatelessWidget {
  const _TimelineBlockTile({required this.block});

  final TimeBlockModel block;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ChronologTheme.zinc950,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ChronologTheme.zinc800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Time range + Duration pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TimeUtils.formatTimeRange(block.startTime, block.endTime),
                style: const TextStyle(
                  color: ChronologTheme.zinc200,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ChronologTheme.zinc800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  TimeUtils.formatHumanShort(block.elapsedSeconds),
                  style: const TextStyle(
                    color: ChronologTheme.zinc300,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Multi-segment allocation bar
          if (block.allocations.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: Row(
                  children: block.allocations.map((alloc) {
                    final color = ColorUtils.parseHexColor(alloc.activity?.color);
                    return Expanded(
                      flex: alloc.percentage > 0 ? alloc.percentage : 1,
                      child: Container(color: color),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Allocations chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: block.allocations.map((alloc) {
                final color = ColorUtils.parseHexColor(alloc.activity?.color);
                final name = alloc.activity?.name ?? 'Activity #${alloc.activityId}';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ChronologTheme.zinc900,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ChronologTheme.zinc800),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: const TextStyle(
                          color: ChronologTheme.zinc300,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${alloc.percentage}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
