/// Utility helpers for formatting durations, clocks, and timestamps.
class TimeUtils {
  TimeUtils._();

  /// Injectable clock source for deterministic testing.
  static DateTime Function() clock = DateTime.now;

  /// Returns current DateTime from [clock].
  static DateTime now() => clock();

  /// Formats seconds into a digital timer display `HH:mm:ss` or `mm:ss`.
  static String formatDigital(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hStr = hours.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  /// Formats duration for compact summary displays (e.g. `0m`, `5m`, `1h 20m`).
  /// Matches web app's `formatMinutes` logic for dashboard metrics.
  static String formatSummaryDuration(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h == 0 && m == 0) return '0m';
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Formats elapsed seconds into human readable short format:
  /// e.g. `1h 24m`, `45m`, `less than a minute`.
  static String formatHumanShort(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;

    if (h == 0 && m == 0) return 'less than a minute';
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Formats a DateTime into a local 12-hour time string, e.g. `10:45 AM`.
  static String formatTime12h(DateTime dt) {
    final local = dt.toLocal();
    final hour24 = local.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  /// Formats a time range between start and end: `10:30 AM - 11:45 AM`.
  static String formatTimeRange(DateTime start, DateTime end) {
    return '${formatTime12h(start)} – ${formatTime12h(end)}';
  }

  /// Returns the start of the local day (00:00:00.000).
  static DateTime startOfDay(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Returns the end of the local day (start of next day: 00:00:00.000).
  static DateTime endOfDay(DateTime dt) {
    final start = startOfDay(dt);
    return start.add(const Duration(days: 1));
  }
}
