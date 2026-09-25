import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/chronolog_theme.dart';
import '../../../shared/utils/color_utils.dart';
import '../../tasks/presentation/tasks_controller.dart';
import 'tracking_controller.dart';

/// Modal bottom sheet implementing the three-step log-session allocation flow:
/// Step 1: Select Activities
/// Step 2: Allocate Percentages (defaults to equal split totaling 100%)
/// Step 3: Complete Finished Tasks (optional)
class LogSessionSheet extends ConsumerStatefulWidget {
  const LogSessionSheet({
    super.key,
    required this.elapsedDuration,
  });

  final Duration elapsedDuration;

  static Future<void> show(BuildContext context, Duration elapsed) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ChronologTheme.zinc900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LogSessionSheet(elapsedDuration: elapsed),
    );
  }

  @override
  ConsumerState<LogSessionSheet> createState() => _LogSessionSheetState();
}

class _LogSessionSheetState extends ConsumerState<LogSessionSheet> {
  // Step: 0 = select, 1 = allocate, 2 = tasks
  int _step = 0;
  final Set<int> _selectedActivityIds = {};
  final Map<int, int> _allocations = {};
  final Set<String> _selectedTaskIds = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  void _toggleActivity(int id) {
    setState(() {
      if (_selectedActivityIds.contains(id)) {
        _selectedActivityIds.remove(id);
      } else {
        _selectedActivityIds.add(id);
      }
      _errorMessage = null;
    });
  }

  /// Builds equal allocations matching web behavior: base + remainder for first activity.
  void _buildEqualAllocations() {
    final list = _selectedActivityIds.toList();
    final n = list.length;
    if (n == 0) return;

    final base = 100 ~/ n;
    final remainder = 100 - (base * n);

    _allocations.clear();
    for (int i = 0; i < n; i++) {
      _allocations[list[i]] = base + (i == 0 ? remainder : 0);
    }
  }

  void _proceedToAllocate() {
    if (_selectedActivityIds.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one activity.');
      return;
    }
    setState(() {
      _buildEqualAllocations();
      _errorMessage = null;
      _step = 1;
    });
  }

  void _adjustAllocation(int activityId, int delta) {
    final current = _allocations[activityId] ?? 0;
    final updated = (current + delta).clamp(1, 100);
    setState(() {
      _allocations[activityId] = updated;
      _errorMessage = null;
    });
  }

  int get _totalPercentage =>
      _allocations.values.fold(0, (sum, val) => sum + val);

  void _proceedToTasks() {
    if (_totalPercentage != 100) {
      setState(() {
        _errorMessage =
            'Percentages must sum to exactly 100% (currently $_totalPercentage%).';
      });
      return;
    }
    setState(() {
      _errorMessage = null;
      _step = 2;
    });
  }

  Future<void> _submitLog({bool includeTasks = true}) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final payload = _allocations.entries.map((e) {
        return {
          'activityId': e.key,
          'percentage': e.value,
        };
      }).toList();

      await ref.read(trackingControllerProvider.notifier).logSession(payload);

      String taskWarning = '';
      if (includeTasks && _selectedTaskIds.isNotEmpty) {
        try {
          await ref
              .read(tasksActionControllerProvider)
              .completeTasks(_selectedTaskIds.toList());
        } catch (taskError) {
          taskWarning =
              ' (Note: tasks could not be marked complete in Google Tasks)';
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Time block saved successfully!$taskWarning'),
            backgroundColor: ChronologTheme.emerald950,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(activitiesListProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: ChronologTheme.zinc700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _step == 0
                          ? 'Log Session: Select'
                          : (_step == 1
                              ? 'Log Session: Allocate'
                              : 'Log Session: Tasks'),
                      style: const TextStyle(
                        color: ChronologTheme.zinc50,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Elapsed: ${widget.elapsedDuration.inMinutes}m (${widget.elapsedDuration.inSeconds % 60}s)',
                      style: const TextStyle(
                        color: ChronologTheme.zinc400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (_step == 1)
                  TextButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() => _buildEqualAllocations()),
                    icon: const Icon(Icons.balance, size: 16),
                    label: const Text('Equal Split'),
                    style: TextButton.styleFrom(
                      foregroundColor: ChronologTheme.cyan400,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Error banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ChronologTheme.red950.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ChronologTheme.red400.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: ChronologTheme.red400,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Content per step
            if (_step == 2)
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Did you complete any tasks during this time?',
                      style: TextStyle(
                        color: ChronologTheme.zinc50,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select any Google Tasks you finished.',
                      style: TextStyle(
                        color: ChronologTheme.zinc400,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final tasksAsync = ref.watch(tasksProvider);
                          return tasksAsync.when(
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(
                                  color: ChronologTheme.cyan400,
                                ),
                              ),
                            ),
                            error: (err, _) => Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Could not load tasks: $err',
                                style: const TextStyle(
                                  color: ChronologTheme.red400,
                                ),
                              ),
                            ),
                            data: (tasks) {
                              if (tasks.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'No incomplete tasks found.',
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
                                itemCount: tasks.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final task = tasks[index];
                                  final checked =
                                      _selectedTaskIds.contains(task.id);
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (checked) {
                                          _selectedTaskIds.remove(task.id);
                                        } else {
                                          _selectedTaskIds.add(task.id);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: checked
                                            ? ChronologTheme.zinc800
                                            : ChronologTheme.zinc950,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: checked
                                              ? ChronologTheme.cyan400
                                              : ChronologTheme.zinc800,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            checked
                                                ? Icons.check_box
                                                : Icons.check_box_outline_blank,
                                            color: checked
                                                ? ChronologTheme.cyan400
                                                : ChronologTheme.zinc600,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              task.title,
                                              style: const TextStyle(
                                                color: ChronologTheme.zinc200,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: activitiesAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: ChronologTheme.cyan400),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Failed to load activities: $err',
                            style: const TextStyle(color: ChronologTheme.red400),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(activitiesListProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (activities) {
                    if (activities.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No activities found. Please create an activity in Activities screen first.',
                          style: TextStyle(color: ChronologTheme.zinc400),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (_step == 0) {
                      // Step 1: Select Activities
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: activities.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final act = activities[index];
                          final isSelected = _selectedActivityIds.contains(act.id);
                          final color = ColorUtils.parseHexColor(act.color);

                          return InkWell(
                            onTap: () => _toggleActivity(act.id),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? ChronologTheme.zinc800
                                    : ChronologTheme.zinc950,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : ChronologTheme.zinc800,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      act.name,
                                      style: const TextStyle(
                                        color: ChronologTheme.zinc200,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isSelected ? color : ChronologTheme.zinc600,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    } else {
                      // Step 2: Allocate Percentages
                      final selectedList = activities
                          .where((a) => _selectedActivityIds.contains(a.id))
                          .toList();

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: selectedList.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final act = selectedList[index];
                          final pct = _allocations[act.id] ?? 0;
                          final color = ColorUtils.parseHexColor(act.color);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ChronologTheme.zinc950,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ChronologTheme.zinc800),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        act.name,
                                        style: const TextStyle(
                                          color: ChronologTheme.zinc200,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$pct%',
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () => _adjustAllocation(act.id, -5),
                                      icon: const Icon(Icons.remove, size: 18),
                                      color: ChronologTheme.zinc400,
                                      tooltip: '-5%',
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: color,
                                          inactiveTrackColor: ChronologTheme.zinc800,
                                          thumbColor: color,
                                          overlayColor: color.withValues(alpha: 0.2),
                                        ),
                                        child: Slider(
                                          value: pct.toDouble(),
                                          min: 1,
                                          max: 100,
                                          divisions: 99,
                                          onChanged: _isSubmitting
                                              ? null
                                              : (val) {
                                                  setState(() {
                                                    _allocations[act.id] = val.round();
                                                    _errorMessage = null;
                                                  });
                                                },
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () => _adjustAllocation(act.id, 5),
                                      icon: const Icon(Icons.add, size: 18),
                                      color: ChronologTheme.zinc400,
                                      tooltip: '+5%',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Bottom action buttons
            if (_step == 0) ...[
              ElevatedButton(
                onPressed: _selectedActivityIds.isEmpty ? null : _proceedToAllocate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ChronologTheme.cyan400,
                  foregroundColor: ChronologTheme.zinc950,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Next: Allocate (${_selectedActivityIds.length})'),
              ),
            ] else if (_step == 1) ...[
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() {
                              _step = 0;
                              _errorMessage = null;
                            }),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ChronologTheme.zinc700),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_totalPercentage != 100 || _isSubmitting)
                          ? null
                          : _proceedToTasks,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChronologTheme.cyan400,
                        foregroundColor: ChronologTheme.zinc950,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Next: Review Tasks ($_totalPercentage%)'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() {
                              _step = 1;
                              _errorMessage = null;
                            }),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ChronologTheme.zinc700),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _submitLog(includeTasks: false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ChronologTheme.zinc700),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _submitLog(includeTasks: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChronologTheme.cyan400,
                        foregroundColor: ChronologTheme.zinc950,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ChronologTheme.zinc950,
                              ),
                            )
                          : Text(
                              _selectedTaskIds.isEmpty
                                  ? 'Save Time Block'
                                  : 'Save (${_selectedTaskIds.length} tasks)',
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
