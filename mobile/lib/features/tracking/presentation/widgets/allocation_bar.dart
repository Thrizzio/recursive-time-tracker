import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../shared/theme/chronolog_theme.dart';
import '../../../../shared/utils/color_utils.dart';
import '../../../activities/domain/activity_model.dart';

/// Minimum percentage allowed for any segment on the allocation bar (matches web MIN_SEGMENT_PCT = 2).
const int kMinSegmentPct = 2;

/// Model representing a single activity percentage partition inside the 100% allocation bar.
@immutable
class AllocationItem {
  final int activityId;
  final int percentage;

  const AllocationItem({
    required this.activityId,
    required this.percentage,
  });

  AllocationItem copyWith({int? activityId, int? percentage}) {
    return AllocationItem(
      activityId: activityId ?? this.activityId,
      percentage: percentage ?? this.percentage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllocationItem &&
          runtimeType == other.runtimeType &&
          activityId == other.activityId &&
          percentage == other.percentage;

  @override
  int get hashCode => Object.hash(activityId, percentage);

  @override
  String toString() => 'AllocationItem(activityId: $activityId, percentage: $percentage)';
}

/// Builds equal allocations matching web behavior: base + remainder for first activity.
List<AllocationItem> buildEqualAllocations(List<int> activityIds) {
  final n = activityIds.length;
  if (n == 0) return [];
  final base = 100 ~/ n;
  final remainder = 100 - (base * n);
  return List.generate(n, (i) {
    return AllocationItem(
      activityId: activityIds[i],
      percentage: base + (i == 0 ? remainder : 0),
    );
  });
}

/// Moves a divider boundary between adjacent activities.
/// Increases left by actualDelta and decreases right by actualDelta.
/// Guarantees neither segment drops below [minSegmentPct] and total is always 100%.
List<AllocationItem> moveDivider(
  List<AllocationItem> allocations,
  int dividerIndex,
  int deltaPct, {
  int minSegmentPct = kMinSegmentPct,
}) {
  if (dividerIndex < 0 || dividerIndex >= allocations.length - 1) {
    return allocations;
  }

  final left = allocations[dividerIndex];
  final right = allocations[dividerIndex + 1];

  final maxIncrease = math.max(0, right.percentage - minSegmentPct);
  final maxDecrease = math.max(0, left.percentage - minSegmentPct);
  final actualDelta = deltaPct.clamp(-maxDecrease, maxIncrease);

  if (actualDelta == 0) return allocations;

  return [
    for (int i = 0; i < allocations.length; i++)
      if (i == dividerIndex)
        allocations[i].copyWith(percentage: allocations[i].percentage + actualDelta)
      else if (i == dividerIndex + 1)
        allocations[i].copyWith(percentage: allocations[i].percentage - actualDelta)
      else
        allocations[i],
  ];
}

/// A continuous 0–100% multi-point slider track with colored adjacent segments
/// and draggable boundary points between activities.
class AllocationBar extends StatefulWidget {
  final List<ActivityModel> activities;
  final List<AllocationItem> allocations;
  final ValueChanged<List<AllocationItem>> onChanged;

  const AllocationBar({
    super.key,
    required this.activities,
    required this.allocations,
    required this.onChanged,
  });

  @override
  State<AllocationBar> createState() => _AllocationBarState();
}

class _AllocationBarState extends State<AllocationBar> {
  int? _activeDividerIndex;
  double _dragAccumulatedPct = 0.0;

  @override
  Widget build(BuildContext context) {
    final allocations = widget.allocations;
    if (allocations.isEmpty) {
      return const SizedBox(height: 42);
    }

    final activityMap = {for (final a in widget.activities) a.id: a};

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const barHeight = 42.0;
        const touchWidth = 36.0;

        return SizedBox(
          height: barHeight,
          width: totalWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Colored segments track
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      for (final alloc in allocations) ...[
                        Expanded(
                          flex: alloc.percentage,
                          child: Container(
                            height: double.infinity,
                            color: ColorUtils.parseHexColor(
                              activityMap[alloc.activityId]?.color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Draggable boundary dividers
              for (int i = 0; i < allocations.length - 1; i++) ...[
                _buildDivider(
                  dividerIndex: i,
                  totalWidth: totalWidth,
                  touchWidth: touchWidth,
                  barHeight: barHeight,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDivider({
    required int dividerIndex,
    required double totalWidth,
    required double touchWidth,
    required double barHeight,
  }) {
    int cumulativePct = 0;
    for (int j = 0; j <= dividerIndex; j++) {
      cumulativePct += widget.allocations[j].percentage;
    }

    final boundaryX = totalWidth > 0 ? (cumulativePct / 100.0) * totalWidth : 0.0;
    final isDragging = _activeDividerIndex == dividerIndex;

    return Positioned(
      left: boundaryX - (touchWidth / 2),
      top: 0,
      bottom: 0,
      width: touchWidth,
      child: GestureDetector(
        key: Key('allocation_divider_$dividerIndex'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) {
          setState(() {
            _activeDividerIndex = dividerIndex;
            _dragAccumulatedPct = 0.0;
          });
        },
        onHorizontalDragUpdate: (details) {
          if (totalWidth <= 0) return;
          final dx = details.primaryDelta ?? 0.0;
          _dragAccumulatedPct += (dx / totalWidth) * 100.0;
          final deltaInt = _dragAccumulatedPct.truncate();
          if (deltaInt != 0) {
            final updated = moveDivider(widget.allocations, dividerIndex, deltaInt);
            final actualChange =
                updated[dividerIndex].percentage - widget.allocations[dividerIndex].percentage;
            if (actualChange != 0) {
              _dragAccumulatedPct -= actualChange;
              widget.onChanged(updated);
            } else {
              _dragAccumulatedPct = 0.0;
            }
          }
        },
        onHorizontalDragEnd: (details) {
          setState(() {
            _activeDividerIndex = null;
            _dragAccumulatedPct = 0.0;
          });
        },
        child: Center(
          child: Container(
            width: 6,
            height: 24,
            decoration: BoxDecoration(
              color: isDragging
                  ? ChronologTheme.zinc900
                  : ChronologTheme.zinc900.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: isDragging
                    ? ChronologTheme.cyan400
                    : ChronologTheme.zinc300.withValues(alpha: 0.8),
                width: isDragging ? 1.2 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
