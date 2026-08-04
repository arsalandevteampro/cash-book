import 'package:shared_preferences/shared_preferences.dart';

class AccessRequestRateLimiter {
  static const String _keyTimestamps = 'access_request_timestamps_v1';
  static const int maxRequestsPer24Hours = 3;
  static const Duration windowDuration = Duration(hours: 24);

  /// Checks if the device is within the allowed request limit for the past 24 hours.
  /// Returns null if allowed, or an error message String if rate limited.
  static Future<String?> checkRateLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawTimestamps = prefs.getStringList(_keyTimestamps) ?? [];
      final now = DateTime.now().millisecondsSinceEpoch;
      final windowStart = now - windowDuration.inMilliseconds;

      // Filter valid timestamps in the last 24 hours
      final validTimestamps = rawTimestamps
          .map((t) => int.tryParse(t) ?? 0)
          .where((t) => t > windowStart)
          .toList();

      if (validTimestamps.length >= maxRequestsPer24Hours) {
        return 'Rate limit reached: You can only submit up to $maxRequestsPer24Hours access requests per 24 hours from this device.';
      }
    } catch (_) {
      // If SharedPreferences fails, allow request to proceed
    }
    return null;
  }

  /// Records a successful request submission timestamp locally.
  static Future<void> recordSubmission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawTimestamps = prefs.getStringList(_keyTimestamps) ?? [];
      final now = DateTime.now().millisecondsSinceEpoch;
      final windowStart = now - windowDuration.inMilliseconds;

      final updated = rawTimestamps
          .map((t) => int.tryParse(t) ?? 0)
          .where((t) => t > windowStart)
          .map((t) => t.toString())
          .toList();

      updated.add(now.toString());
      await prefs.setStringList(_keyTimestamps, updated);
    } catch (_) {}
  }
}
