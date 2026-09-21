import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';

/// A reusable anchored adaptive Banner Ad widget.
/// Automatically handles screen sizing, ad loading, error fallback, and proper lifecycle disposal.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  int? _loadedWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAdaptiveAd();
  }

  Future<void> _loadAdaptiveAd() async {
    final width = MediaQuery.of(context).size.width.truncate();

    // Avoid redundant reloading if width hasn't changed
    if (_bannerAd != null && _loadedWidth == width) {
      return;
    }

    // Dispose previous ad if reloading for screen width/orientation change
    if (_bannerAd != null) {
      await _bannerAd!.dispose();
      _bannerAd = null;
      _isLoaded = false;
    }

    _loadedWidth = width;

    final AdSize? adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

    if (!mounted) return;

    final bannerAd = BannerAd(
      adUnitId: AdConfig.androidBannerAdUnitId,
      size: adaptiveSize ?? AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          final loadedAd = ad as BannerAd;
          final responseInfo = loadedAd.responseInfo;
          final adapterClassName = responseInfo?.loadedAdapterResponseInfo?.adapterClassName;
          debugPrint('=== [AdMob Mediation Log] Ad Loaded Successfully! ===');
          debugPrint('Filled Adapter Class: $adapterClassName');
          if (adapterClassName != null && adapterClassName.contains('facebook')) {
            debugPrint('🎯 WINNER: Meta Audience Network (Facebook) served this ad via Bidding!');
          } else {
            debugPrint('ℹ️ Filled by: $adapterClassName (Google AdMob / standard network)');
          }
          debugPrint('Full Response Info: ${responseInfo?.toString()}');

          setState(() {
            _bannerAd = loadedAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: ${error.message} (Code: ${error.code})');
          debugPrint('ResponseInfo on Failure: ${error.responseInfo?.toString()}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
          }
        },
      ),
    );

    try {
      await bannerAd.load();
    } catch (e) {
      debugPrint('Exception while loading BannerAd: $e');
      if (mounted) {
        setState(() {
          _bannerAd = null;
          _isLoaded = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
