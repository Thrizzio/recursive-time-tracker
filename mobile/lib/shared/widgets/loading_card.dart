import 'package:flutter/material.dart';
import '../theme/chronolog_theme.dart';

/// Card with loading indicator and optional message.
class LoadingCard extends StatelessWidget {
  const LoadingCard({
    super.key,
    this.message = 'Loading...',
    this.height = 100,
  });

  final String message;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: ChronologTheme.zinc900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ChronologTheme.zinc800),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ChronologTheme.cyan400,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ChronologTheme.zinc400,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

