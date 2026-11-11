import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Cấu hình ID quảng cáo.
/// - Chạy debug (flutter run): luôn dùng ID thử nghiệm của Google.
/// - Build release: dùng ID thật, trừ khi build với --dart-define=ADS_TEST=true.
/// Không tự bấm quảng cáo thật của mình: Google có thể đình chỉ tài khoản AdMob.
class AdConfig {
  AdConfig._();

  static const bool _forceTest = bool.fromEnvironment('ADS_TEST');
  static bool get useTestAds => kDebugMode || _forceTest;

  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _prodBanner = 'ca-app-pub-4389618584846299/8438666638';
  static const String _prodInterstitial = 'ca-app-pub-4389618584846299/9915399831';

  static String get bannerUnitId => useTestAds ? _testBanner : _prodBanner;
  static String get interstitialUnitId => useTestAds ? _testInterstitial : _prodInterstitial;
}

class AdMobService {
  AdMobService._();
  static final AdMobService instance = AdMobService._();

  /// Hiển thị quảng cáo xen kẽ sau mỗi bao nhiêu lần lưu.
  static const int interstitialEvery = 2;

  bool _initialized = false;
  bool _loading = false;
  InterstitialAd? _interstitial;
  int _saveCount = 0;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await MobileAds.instance.initialize();
      _loadInterstitial();
    } catch (e) {
      debugPrint('AdMob init lỗi: $e');
    }
  }

  void _loadInterstitial() {
    if (_loading || _interstitial != null) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          _interstitial = null;
        },
      ),
    );
  }

  /// Gọi sau mỗi lần lưu thành công. [onDone] luôn được gọi đúng một lần,
  /// dù có quảng cáo hay không, sau khi quảng cáo đóng (nếu có).
  void onMeasurementSaved({required VoidCallback onDone}) {
    _saveCount++;
    final ad = _interstitial;
    if (ad == null || _saveCount % interstitialEvery != 0) {
      _loadInterstitial();
      onDone();
      return;
    }

    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
        onDone();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        _loadInterstitial();
        onDone();
      },
    );
    ad.show();
  }
}

/// Banner đáy màn hình. Tự ẩn nếu chưa tải được quảng cáo.
class AdMobBanner extends StatefulWidget {
  const AdMobBanner({super.key});

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: AdSize.banner.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
