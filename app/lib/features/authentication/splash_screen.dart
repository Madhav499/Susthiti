import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Becomes true once the launch splash has played, so the router never cuts it short.
class SplashGate extends Notifier<bool> {
  @override
  bool build() => false;

  void finish() => state = true;
}

final splashGateProvider = NotifierProvider<SplashGate, bool>(SplashGate.new);

/// Launch screen: the official logo fades in and settles (opacity 0 -> 1, scale 0.96 -> 1) while
/// the session is restored. Calm on purpose: no bounce, spin or large zoom.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const animation = Duration(milliseconds: 900);

  /// The logo stays fully visible this long before the app moves on.
  static const hold = Duration(milliseconds: 350);

  /// Logo width for the available space: phones ~68%, tablets ~46%, desktops 280-420 px, and never
  /// taller than about half the screen. The aspect ratio is always the logo's own.
  static double logoWidth(Size size) {
    final double byWidth;
    if (size.width >= Breakpoints.desktop) {
      byWidth = (size.width * 0.28).clamp(280.0, 420.0);
    } else if (size.width >= Breakpoints.tablet) {
      byWidth = size.width * 0.46;
    } else {
      byWidth = size.width * 0.68;
    }
    return byWidth.clamp(120.0, size.height * 0.55);
  }

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: SplashScreen.animation);
  late final _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final _scale = Tween<double>(begin: 0.96, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (ref.read(splashGateProvider)) {
      _controller.value = 1; // already played this session (e.g. a later session restore)
      return;
    }
    _controller.forward().whenComplete(() async {
      await Future<void>.delayed(SplashScreen.hold);
      if (mounted) ref.read(splashGateProvider.notifier).finish();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = SplashScreen.logoWidth(MediaQuery.sizeOf(context));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Semantics(
          label: 'SUSTHITI. ${AppAssets.tagline}',
          image: true,
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Image.asset(AppAssets.logoTransparent, width: width, fit: BoxFit.contain, filterQuality: FilterQuality.medium, excludeFromSemantics: true),
            ),
          ),
        ),
      ),
    );
  }
}
