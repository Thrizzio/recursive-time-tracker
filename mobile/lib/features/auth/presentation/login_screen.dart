import 'package:flutter/material.dart';
import '../../../shared/theme/chronolog_theme.dart';

/// Screen displayed when user is not authenticated.
/// Full Google Sign-In integration is implemented in Phase 3.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ChronologTheme.zinc900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ChronologTheme.zinc800),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'CHRONOLOG',
                    style: TextStyle(
                      color: ChronologTheme.cyan400,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Log in to Chronolog',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your time with seamless multi-device sync.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ChronologTheme.zinc400,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Google Sign-In will be active in Phase 3.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.account_circle, size: 20),
                    label: const Text('Continue with Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ChronologTheme.zinc50,
                      foregroundColor: ChronologTheme.zinc950,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

