import 'package:flutter/material.dart';
import '../../../core/config/api_config.dart';
import '../../../shared/theme/chronolog_theme.dart';

/// Screen for app configuration, Google Task list selection, and notifications.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tasks & Notifications (Phase 4b & Phase 7)',
                      style: TextStyle(
                        color: ChronologTheme.zinc50,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Google Task List selection and local notification preferences will be integrated in later phases.',
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

