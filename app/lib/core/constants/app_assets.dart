/// Official SUSTHITI brand assets, generated from the supplied logo by
/// scripts/brand/make_brand_assets.py. Reference these constants; never the paths directly.
abstract final class AppAssets {
  /// The official logo exactly as supplied (emblem, wordmark and tagline on white).
  static const logo = 'assets/branding/susthiti_logo.png';

  /// The same logo with its white background made transparent, for non-white surfaces.
  static const logoTransparent = 'assets/branding/susthiti_logo_transparent.png';

  /// The emblem alone (shield, figure and leaves), square and transparent.
  static const mark = 'assets/branding/susthiti_mark.png';

  static const appName = 'SUSTHITI';
  static const tagline = 'Your Health. Our Support. A Better Tomorrow.';
  static const webTitle = '$appName — $tagline';
}
