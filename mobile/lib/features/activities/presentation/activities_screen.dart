import 'package:flutter/material.dart';
import '../../../shared/theme/chronolog_theme.dart';

/// Screen for managing user activities.
/// Full GET/POST activities integration is implemented in Phase 4b.
class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activities'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'What are you spending your time on? Create activities to track, then log time against them from the Dashboard.',
              style: TextStyle(
                color: ChronologTheme.zinc400,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.palette_outlined,
                      color: ChronologTheme.cyan400,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Activities Management (Phase 4b)',
                      style: TextStyle(
                        color: ChronologTheme.zinc50,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Activity creation form with color picker and activity list will be implemented in Phase 4b.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ChronologTheme.zinc400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

