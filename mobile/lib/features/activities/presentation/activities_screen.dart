import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/chronolog_theme.dart';
import '../../../shared/utils/color_utils.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/loading_card.dart';
import 'activities_controller.dart';

/// Pre-defined curated palette of vibrant, high-contrast colors matching Chronolog's aesthetic.
const List<String> kPresetColors = [
  '#38BDF8', // Cyan / Sky
  '#34D399', // Emerald
  '#A78BFA', // Violet
  '#F472B6', // Pink
  '#FBBF24', // Amber
  '#F87171', // Red / Rose
  '#FB923C', // Orange
  '#2DD4BF', // Teal
  '#60A5FA', // Blue
  '#C084FC', // Purple
];

/// Screen for managing user activities with full CRUD capability.
class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  void _showAddActivitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ChronologTheme.zinc900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _AddActivitySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(activitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddActivitySheet(context),
        backgroundColor: ChronologTheme.cyan300,
        foregroundColor: ChronologTheme.zinc950,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Add Activity',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: ChronologTheme.cyan400,
          backgroundColor: ChronologTheme.zinc900,
          onRefresh: () async {
            ref.invalidate(activitiesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'What are you spending your time on? Create activities to track, then log time against them from the Dashboard.',
                style: TextStyle(
                  color: ChronologTheme.zinc400,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Activity List Section
              activitiesAsync.when(
                loading: () => const Column(
                  children: [
                    LoadingCard(message: 'Loading activities...', height: 80),
                    SizedBox(height: 12),
                    LoadingCard(message: '', height: 80),
                  ],
                ),
                error: (err, _) => ErrorRetry(
                  title: 'Could not load activities',
                  message: err.toString(),
                  onRetry: () => ref.invalidate(activitiesProvider),
                ),
                data: (activities) {
                  if (activities.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 48,
                      ),
                      decoration: BoxDecoration(
                        color: ChronologTheme.zinc900,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ChronologTheme.zinc800,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            color: ChronologTheme.zinc600,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No activities yet',
                            style: TextStyle(
                              color: ChronologTheme.zinc200,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap "Add Activity" below to create your first activity category.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ChronologTheme.zinc500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddActivitySheet(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Activity'),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'YOUR ACTIVITIES (${activities.length})',
                          style: const TextStyle(
                            color: ChronologTheme.zinc500,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: activities.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final activity = activities[index];
                          final parsedColor = ColorUtils.parseHexColor(
                            activity.color,
                            fallback: ChronologTheme.cyan400,
                          );

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: parsedColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: parsedColor.withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      activity.name,
                                      style: const TextStyle(
                                        color: ChronologTheme.zinc50,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ChronologTheme.zinc800,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      activity.color.toUpperCase(),
                                      style: const TextStyle(
                                        color: ChronologTheme.zinc400,
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Extra bottom padding so FAB does not obscure last item
                      const SizedBox(height: 80),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet form for creating a new activity.
class _AddActivitySheet extends ConsumerStatefulWidget {
  const _AddActivitySheet();

  @override
  ConsumerState<_AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends ConsumerState<_AddActivitySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedColor = kPresetColors.first;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final controller = ref.read(activitiesActionControllerProvider);
      await controller.createActivity(
        name: name,
        color: _selectedColor,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Activity "$name" created'),
            backgroundColor: ChronologTheme.emerald950,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add New Activity',
                  style: TextStyle(
                    color: ChronologTheme.zinc50,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: ChronologTheme.zinc400,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Name field
            const Text(
              'Activity Name',
              style: TextStyle(
                color: ChronologTheme.zinc300,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              maxLength: 100,
              style: const TextStyle(color: ChronologTheme.zinc50),
              decoration: InputDecoration(
                hintText: 'e.g. Coding, Deep Work, Reading',
                hintStyle: const TextStyle(color: ChronologTheme.zinc600),
                counterText: '',
                filled: true,
                fillColor: ChronologTheme.zinc950,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: ChronologTheme.zinc800),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: ChronologTheme.zinc800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: ChronologTheme.cyan400),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter an activity name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Color picker
            const Text(
              'Select Color',
              style: TextStyle(
                color: ChronologTheme.zinc300,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kPresetColors.map((hex) {
                final isSelected = _selectedColor == hex;
                final color = ColorUtils.parseHexColor(hex);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = hex;
                    });
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : Border.all(color: ChronologTheme.zinc800, width: 1),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.black87,
                            size: 20,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: ChronologTheme.red400,
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ChronologTheme.zinc950,
                        ),
                      )
                    : const Text('+ Add Activity'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
