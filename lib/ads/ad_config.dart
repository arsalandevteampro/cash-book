/// Centralized configuration for Google AdMob Ads.
class AdConfig {
  /// Set [useTestAds] to false and provide your real [androidProductionBannerId]
  /// before building and publishing the production release.
  static const bool useTestAds = true;

  /// Official Google Android Test Banner Ad Unit ID
  static const String androidTestBannerId =
      'ca-app-pub-3940256099942544/6300978111';

  /// Real Android Production Banner Ad Unit ID
  /// Replace this string with your real AdMob Banner Ad Unit ID when ready for production
  static const String androidProductionBannerId =
      'ca-app-pub-7531348818625320/2535465273';

  /// Returns the active Android Banner Ad Unit ID based on [useTestAds] flag
  static String get androidBannerAdUnitId {
    return useTestAds ? androidTestBannerId : androidProductionBannerId;
  }

  /// Official Google Android Test Interstitial Ad Unit ID
  static const String androidTestInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  /// Real Android Production Interstitial Ad Unit ID
  static const String androidProductionInterstitialId =
      'ca-app-pub-7531348818625320/5834326279';

  /// Returns the active Android Interstitial Ad Unit ID based on [useTestAds] flag
  static String get androidInterstitialAdUnitId {
    return useTestAds ? androidTestInterstitialId : androidProductionInterstitialId;
  }
}
