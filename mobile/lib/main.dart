import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'core/networking/api_client.dart';
import 'features/timer/data/timer_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent CookieJar using application storage directory
  final cookieJar = await ApiClient.createDefaultCookieJar();

  // Initialize local key-value store for timer state persistence
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        cookieJarProvider.overrideWithValue(cookieJar),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ChronologApp(),
    ),
  );
}
