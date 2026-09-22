import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';

/// Production-ready Interstitial Ad Manager.
/// Preloads interstitial ads in background and handles full-screen callbacks smoothly.
class InterstitialAdManager {
  InterstitialAdManager._();

  static final InterstitialAdManager instance = InterstitialAdManager._();

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;
  final List<Completer<bool>> _loadingCompleters = [];

  /// Whether an interstitial ad is loaded and ready to show.
  bool get isAdReady => _interstitialAd != null;

  /// Preload an interstitial ad in background if one is not already available or loading.
  void preloadAd() {
    if (_interstitialAd != null || _isLoading) {
      return;
    }

    _isLoading = true;
    debugPrint('=== [AdMob] Preloading Interstitial Ad... ===');
    InterstitialAd.load(
      adUnitId: AdConfig.androidInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('=== [AdMob] Interstitial Ad Loaded Successfully ===');
          _interstitialAd = ad;
          _isLoading = false;
          _notifyCompleters(true);
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('=== [AdMob] Interstitial Ad Failed to Load: ${error.message} ===');
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
  /// Then execute [onComplete]. If the ad is not ready or times out, [onComplete] is executed
  /// immediately so the user experience is never blocked.
  Future<void> showAdThen({
    required VoidCallback onComplete,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    // 1. If ad is already ready, show immediately!
    if (_interstitialAd != null) {
      _showLoadedAd(onComplete);
      return;
    }

    // 2. If not ready, start loading if not already loading
    preloadAd();

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
      _showLoadedAd(onComplete);
    } else {
      debugPrint('=== [AdMob] Ad not ready in time, proceeding directly with action ===');
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
        debugPrint('=== [AdMob] Interstitial Ad Showed Full Screen ===');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('=== [AdMob] Interstitial Ad Dismissed ===');
        ad.dispose();
        _interstitialAd = null;
        preloadAd();
        finish();
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint('=== [AdMob] Interstitial Ad Failed To Show: ${error.message} ===');
        ad.dispose();
        _interstitialAd = null;
        preloadAd();
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
