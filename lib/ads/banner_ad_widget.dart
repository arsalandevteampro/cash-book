import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';

/// A reusable anchored adaptive Banner Ad widget.
/// Automatically handles screen sizing, ad loading, error fallback, retry on failure, and proper lifecycle disposal.
class BannerAdWidget extends StatefulWidget {
  final double horizontalPadding;
  final int? adWidth;
  const BannerAdWidget({
    super.key,
    this.horizontalPadding = 0,
    this.adWidth,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  int? _loadedWidth;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  static const int _maxRetries = 3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAdaptiveAd();
  }

  @override
  void didUpdateWidget(BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adWidth != widget.adWidth ||
        oldWidget.horizontalPadding != widget.horizontalPadding) {
      _loadAdaptiveAd();
    }
  }

  Future<void> _loadAdaptiveAd() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final mediaWidth = (widget.adWidth?.toDouble() ??
            (screenWidth - widget.horizontalPadding))
        .truncate();
    if (mediaWidth <= 0) return;

    // Avoid redundant reloading if width hasn't changed and ad is already loaded or currently loading
    if ((_bannerAd != null && _loadedWidth == mediaWidth) || _isLoading) {
      return;
    }

    _isLoading = true;
    _loadedWidth = mediaWidth;

    // Safely dispose old ad by resetting state first so AdWidget is removed before disposal
    if (_bannerAd != null) {
      final oldAd = _bannerAd;
      setState(() {
        _bannerAd = null;
        _isLoaded = false;
      });
      try {
        await oldAd?.dispose();
      } catch (e) {
        debugPrint('Error disposing old banner ad: $e');
      }
    }

    AdSize? adaptiveSize;
    try {
      // ignore: deprecated_member_use
      adaptiveSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(mediaWidth);
    } catch (e) {
      debugPrint('Error getting adaptive banner size: $e');
    }

    if (!mounted) {
      _isLoading = false;
      return;
    }

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
          debugPrint('=== [AdMob Mediation Log] Banner Ad Loaded Successfully! ===');
          debugPrint('Filled Adapter Class: $adapterClassName');
          debugPrint('Ad Unit ID: ${AdConfig.androidBannerAdUnitId}');

          _retryAttempt = 0;
          _retryTimer?.cancel();
          _retryTimer = null;

          setState(() {
            _bannerAd = loadedAd;
            _isLoaded = true;
            _isLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('=== [AdMob] BannerAd failed to load: ${error.message} (Code: ${error.code}) ===');
          debugPrint('Ad Unit ID used: ${AdConfig.androidBannerAdUnitId}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
              _isLoading = false;
            });
            _scheduleRetry();
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
          _isLoading = false;
        });
        _scheduleRetry();
      }
    }
  }

  void _scheduleRetry() {
    if (_retryAttempt >= _maxRetries || !mounted) return;
    _retryAttempt++;
    final delaySeconds = _retryAttempt * 5; // 5s, 10s, 15s
    debugPrint('Scheduling BannerAd retry #$_retryAttempt in ${delaySeconds}s...');
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      if (mounted) {
        _loadAdaptiveAd();
      }
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final adWidth = _bannerAd!.size.width.toDouble();
    final adHeight = _bannerAd!.size.height.toDouble();

    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: adHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: adWidth,
          height: adHeight,
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}
