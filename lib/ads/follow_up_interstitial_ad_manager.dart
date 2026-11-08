import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';
import '../services/connectivity_helper.dart';

/// Dedicated manager for Follow-up Interstitial Ads (Create & Edit).
/// Preloads interstitial ads in background and handles full-screen callbacks smoothly.
class FollowUpInterstitialAdManager {
  FollowUpInterstitialAdManager._();

  static final FollowUpInterstitialAdManager instance =
      FollowUpInterstitialAdManager._();

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;
  final List<Completer<bool>> _loadingCompleters = [];

  /// Whether the follow-up interstitial ad is loaded and ready to show.
  bool get isAdReady => _interstitialAd != null;

  /// Preload an interstitial ad in background if one is not already available or loading.
  /// Checks active internet connection first to prevent sending failed ad requests.
  Future<void> preloadAd() async {
    if (_interstitialAd != null || _isLoading) {
      return;
    }

    // Mark as loading before the connectivity check to avoid concurrent requests.
    _isLoading = true;

    // Verify active internet connection BEFORE sending ad request to Google AdMob.
    final hasInternet = await ConnectivityHelper.hasInternetConnection();
    if (!hasInternet) {
      _isLoading = false;
      _notifyCompleters(false);
      debugPrint('=== [AdMob] No internet. Skipping Follow-up Interstitial Ad request. ===');
      return;
    }

    if (_interstitialAd != null) {
      _isLoading = false;
      return;
    }

    InterstitialAd.load(
      adUnitId: AdConfig.androidFollowUpInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('=== [AdMob] Follow-up Interstitial Ad Loaded Successfully ===');
          _interstitialAd = ad;
          _isLoading = false;
          _notifyCompleters(true);
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('=== [AdMob] Follow-up Interstitial Ad Failed To Load: ${error.message} ===');
          _interstitialAd = null;
          _isLoading = false;
          _notifyCompleters(false);
        },
      ),
    );
  }

  void _notifyCompleters(bool success) {
    for (final completer in _loadingCompleters) {
      if (!completer.isCompleted) {
        completer.complete(success);
      }
    }
    _loadingCompleters.clear();
  }

  /// Show the interstitial ad if available, or wait briefly (up to [timeout]) if it is loading.
  /// Then execute [onComplete]. If the ad is already cached in memory, it renders immediately (0ms).
  Future<void> showAdThen({
    required VoidCallback onComplete,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    // 1. If ad is ALREADY ready (preloaded during form entry), show immediately!
    // No duplicate HTTP ping is needed because the creative is already cached locally.
    if (_interstitialAd != null) {
      debugPrint('=== [AdMob] Preloaded Follow-up Ad is ready. Showing instantly! ===');
      _showLoadedAd(onComplete);
      return;
    }

    // 2. If not ready, start loading if not already loading (preloadAd verifies internet)
    unawaited(preloadAd());

    // 3. Wait up to timeout for the ad to finish loading
    final completer = Completer<bool>();
    _loadingCompleters.add(completer);

    bool loaded = false;
    try {
      loaded = await completer.future.timeout(timeout, onTimeout: () => false);
    } catch (_) {
      loaded = false;
    }

    if (loaded && _interstitialAd != null) {
      debugPrint('=== [AdMob] Follow-up Ad finished loading just in time. Showing! ===');
      _showLoadedAd(onComplete);
    } else {
      debugPrint(
          '=== [AdMob] Follow-up Ad not ready in time, proceeding directly ===');
      onComplete();
    }
  }

  void _showLoadedAd(VoidCallback onComplete) {
    final ad = _interstitialAd;
    if (ad == null) {
      onComplete();
      return;
    }

    bool completed = false;
    void finish() {
      if (!completed) {
        completed = true;
        onComplete();
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint(
            '=== [AdMob] Follow-up Interstitial Ad Showed Full Screen ===');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('=== [AdMob] Follow-up Interstitial Ad Dismissed ===');
        ad.dispose();
        _interstitialAd = null;
        unawaited(preloadAd());
        finish();
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint(
            '=== [AdMob] Follow-up Interstitial Ad Failed To Show: ${error.message} ===');
        ad.dispose();
        _interstitialAd = null;
        unawaited(preloadAd());
        finish();
      },
    );

    _interstitialAd = null;
    ad.show();
  }

  /// Clean up resources when needed.
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isLoading = false;
  }
}
