import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const chip = 10.0;
  static const control = 10.0;
  static const button = 12.0;
  static const card = 16.0;
  static const panel = 20.0;

  static final chipBorder = BorderRadius.circular(chip);
  static final controlBorder = BorderRadius.circular(control);
  static final buttonBorder = BorderRadius.circular(button);
  static final cardBorder = BorderRadius.circular(card);
  static final panelBorder = BorderRadius.circular(panel);
}

/// 4-point scale: 4, 8, 12, 16, 20, 24, 32, 40, 48.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const lgPlus = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
  static const huge = 48.0;
  static const section = 32.0;
}

abstract final class AppShadows {
  /// Lifted, not floating: a low-opacity blue-gray shadow.
  static const card = [
    BoxShadow(color: Color(0x0D1E3A5F), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x081E3A5F), blurRadius: 2, offset: Offset(0, 1)),
  ];
}

/// Mobile < 600 <= tablet < 1024 <= desktop.
abstract final class Breakpoints {
  static const tablet = 600.0;
  static const desktop = 1024.0;
  static const maxContentWidth = 1240.0;
}

enum ScreenSize { mobile, tablet, desktop }

extension ScreenSizeOf on BuildContext {
  ScreenSize get screenSize {
    final width = MediaQuery.sizeOf(this).width;
    if (width >= Breakpoints.desktop) return ScreenSize.desktop;
    if (width >= Breakpoints.tablet) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const chart = Duration(milliseconds: 600);
}
