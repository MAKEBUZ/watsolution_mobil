import '../../utils/asset_utils.dart';

class LandingPageFunctions {
  static Future<({bool hasBgPng, bool hasBgSvg, bool hasLogo})> initAssets() async {
    final bgPng = await assetExists('assets/images/landing_bg.png');
    final bgSvg = await assetExists('assets/images/landing_bg.svg');
    final logo = await assetExists('assets/logo/logo.svg');
    return (hasBgPng: bgPng, hasBgSvg: bgSvg, hasLogo: logo);
  }
}