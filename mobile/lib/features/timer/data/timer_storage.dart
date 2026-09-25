import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/pomodoro_model.dart';
import '../domain/timer_state.dart';

/// Provider for SharedPreferences instance.
/// Overridden in main() with the preloaded persistent instance.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

/// Provider for [TimerStorage].
final timerStorageProvider = Provider<TimerStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TimerStorage(prefs: prefs);
});

/// Local persistence manager for Pomodoro timer state using SharedPreferences.
/// Includes an in-memory fallback when running in lightweight widget test scopes.
class TimerStorage {
  TimerStorage({this.prefs});

  final SharedPreferences? prefs;
  static const String _storageKey = 'chronolog_pomodoro_state';
  static const String _planStorageKey = 'chronolog_pomodoro_plan';
  TimerState? _memoryFallback;
  PomodoroPlanModel? _planMemoryFallback;

  /// Saves current timer state to local disk (or in-memory if prefs is absent).
  Future<void> saveState(TimerState state) async {
    _memoryFallback = state;
    if (prefs != null) {
      final encoded = jsonEncode(state.toJson());
      await prefs!.setString(_storageKey, encoded);
    }
  }

  /// Loads persisted timer state from local disk, or null if none found.
  TimerState? loadState() {
    if (prefs == null) return _memoryFallback;
    final raw = prefs!.getString(_storageKey);
    if (raw == null || raw.isEmpty) return _memoryFallback;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return TimerState.fromJson(json);
    } catch (_) {
      return _memoryFallback;
    }
  }

  /// Clears stored timer state.
  Future<void> clearState() async {
    _memoryFallback = null;
    if (prefs != null) {
      await prefs!.remove(_storageKey);
    }
  }

  /// Saves current pomodoro plan to local disk (or in-memory if prefs is absent).
  Future<void> savePlan(PomodoroPlanModel? plan) async {
    _planMemoryFallback = plan;
    if (prefs != null) {
      if (plan == null) {
        await prefs!.remove(_planStorageKey);
      } else {
        final encoded = jsonEncode(plan.toJson());
        await prefs!.setString(_planStorageKey, encoded);
      }
    }
  }

  /// Loads persisted pomodoro plan from local disk, or null if none found.
  PomodoroPlanModel? loadPlan() {
    if (prefs == null) return _planMemoryFallback;
    final raw = prefs!.getString(_planStorageKey);
    if (raw == null || raw.isEmpty) return _planMemoryFallback;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return PomodoroPlanModel.fromJson(json);
    } catch (_) {
      return _planMemoryFallback;
    }
  }

  /// Clears stored pomodoro plan.
  Future<void> clearPlan() async {
    _planMemoryFallback = null;
    if (prefs != null) {
      await prefs!.remove(_planStorageKey);
    }
  }
}

