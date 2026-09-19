import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/networking/websocket_client.dart';
import '../shared/theme/chronolog_theme.dart';
import 'router.dart';

/// Root application widget for Chronolog mobile.
/// Listens to app lifecycle changes (background -> foreground resume)
/// and maintains the WebSocket realtime sync lifecycle.
class ChronologApp extends ConsumerStatefulWidget {
  const ChronologApp({super.key});

  @override
  ConsumerState<ChronologApp> createState() => _ChronologAppState();
}

class _ChronologAppState extends ConsumerState<ChronologApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(webSocketClientProvider).handleAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep WebSocket sync active across auth changes
    ref.watch(webSocketSyncProvider);
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
