import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/timer/data/timer_storage.dart';

const String kPomodoroNotificationsKey = 'chronolog_pomodoro_notifications_enabled';

/// Local notification service for Chronolog Pomodoro events.
///
/// Architectural guarantee:
/// Notifications are strictly an asynchronous, non-blocking side-effect.
/// State transitions in Pomodoro MUST NEVER wait for, depend on, or infer state
/// from this service.
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final SharedPreferences? prefs;

  NotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    this.prefs,
  }) : _notificationsPlugin = notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  bool get pomodoroNotificationsEnabled {
    return prefs?.getBool(kPomodoroNotificationsKey) ?? true;
  }

  Future<void> setPomodoroNotificationsEnabled(bool enabled) async {
    await prefs?.setBool(kPomodoroNotificationsKey, enabled);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(settings: initSettings);
      _isInitialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Initialization error (non-fatal): $e');
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final androidPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final granted = await androidPlatform.requestNotificationsPermission();
        return granted ?? false;
      }

      final iOSPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iOSPlatform != null) {
        final granted = await iOSPlatform.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Permission request error (non-fatal): $e');
      return false;
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!pomodoroNotificationsEnabled) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'pomodoro_channel',
        'Pomodoro Timer',
        channelDescription: 'Notifications for Pomodoro focus sessions and breaks',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('[NotificationService] showNotification error (non-fatal): $e');
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = NotificationService(prefs: prefs);
  // Asynchronously initialize without blocking provider creation
  service.initialize();
  return service;
});
