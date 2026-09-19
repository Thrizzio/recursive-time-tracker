import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/theme/chronolog_theme.dart';
import 'router.dart';

/// Root application widget for Chronolog mobile.
class ChronologApp extends ConsumerWidget {
  const ChronologApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Chronolog',
      debugShowCheckedModeBanner: false,
      theme: ChronologTheme.darkTheme,
      darkTheme: ChronologTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}

