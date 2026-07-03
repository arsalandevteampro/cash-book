import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tracks app usage and controls when the Play Store rating prompt appears.
class RatingService {
  RatingService._();

  static const String _firstLaunchKey = 'rating_first_launch_ms';
  static const String _launchCountKey = 'rating_launch_count';
  static const String _hasRatedKey = 'rating_has_rated';
  static const String _lastPromptKey = 'rating_last_prompt_ms';
  static const String _minTransactionsKey = 'rating_min_transactions_met';

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.arsalandev.cashbook';

  /// Minimum app opens before the prompt can appear.
  static const int minLaunches = 5;

  /// Minimum days after first launch before showing the prompt.
  static const int minDaysSinceInstall = 3;

  /// Wait this many days before asking again after "Maybe Later".
  static const int remindAfterDays = 10;

  /// Minimum transactions added before showing (shows real engagement).
  static const int minTransactions = 3;

  static Future<void> trackAppLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    final firstLaunch = prefs.getInt(_firstLaunchKey);
    if (firstLaunch == null) {
      await prefs.setInt(_firstLaunchKey, now);
    }

    final launchCount = prefs.getInt(_launchCountKey) ?? 0;
    await prefs.setInt(_launchCountKey, launchCount + 1);
  }

  static Future<void> trackTransactionAdded(int totalTransactions) async {
    if (totalTransactions < minTransactions) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_minTransactionsKey, true);
  }

  static Future<bool> shouldShowRatingPrompt() async {
    if (kIsWeb) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_hasRatedKey) ?? false) {
      return false;
    }

    final firstLaunch = prefs.getInt(_firstLaunchKey);
    if (firstLaunch == null) {
      return false;
    }

    final launchCount = prefs.getInt(_launchCountKey) ?? 0;
    final hasEnoughTransactions = prefs.getBool(_minTransactionsKey) ?? false;
    final daysSinceInstall = _daysBetween(
      DateTime.fromMillisecondsSinceEpoch(firstLaunch),
      DateTime.now(),
    );

    final meetsUsageThreshold = launchCount >= minLaunches ||
        daysSinceInstall >= minDaysSinceInstall;
    if (!meetsUsageThreshold || !hasEnoughTransactions) {
      return false;
    }

    final lastPrompt = prefs.getInt(_lastPromptKey);
    if (lastPrompt == null) {
      return true;
    }

    final daysSinceLastPrompt = _daysBetween(
      DateTime.fromMillisecondsSinceEpoch(lastPrompt),
      DateTime.now(),
    );

    return daysSinceLastPrompt >= remindAfterDays;
  }

  static Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPromptKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> markRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasRatedKey, true);
    await markPromptShown();
  }

  static Future<void> markDismissed() async {
    await markPromptShown();
  }

  static Future<void> openStoreListing() async {
    final review = InAppReview.instance;

    if (await review.isAvailable()) {
      await review.requestReview();
      return;
    }

    final uri = Uri.parse(playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static int _daysBetween(DateTime from, DateTime to) {
    return to.difference(from).inHours ~/ 24;
  }
}
