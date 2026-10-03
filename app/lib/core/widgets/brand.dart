import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../theme/app_colors.dart';

/// The SUSTHITI wordmark + emblem, used wherever the full lockup fits (auth screens, sidebar
/// headers). For a compact app-bar mark with no wordmark, use [BrandIcon].
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'SUSTHITI',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset(AppAssets.mark, width: size * 1.15, height: size * 1.15, filterQuality: FilterQuality.medium),
        const SizedBox(width: 10),
        Text('SUSTHITI', style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 2, color: AppColors.primaryDeep, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// The emblem alone, no wordmark — for tight spaces (an app bar's leading slot, a compact rail)
/// where the full [BrandMark] would overflow or crowd the title next to it.
class BrandIcon extends StatelessWidget {
  const BrandIcon({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'SUSTHITI',
      excludeSemantics: true,
      child: Image.asset(AppAssets.mark, width: size, height: size, filterQuality: FilterQuality.medium),
    );
  }
}
