import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'brand.dart';

/// Standard page: calm app bar + content. Root tabs pass [large] for a bigger title.
///
/// [brand] shows the compact SUSTHITI mark as the app bar's leading widget — reserved for the
/// three root dashboards (patient/doctor/admin) so the product identity survives past the splash
/// screen on phones, where [RoleShell] has no header of its own. Not used on other screens: a
/// mark on every detail/form screen would be the "overcrowded" branding this is meant to avoid.
class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.title, required this.body, this.actions, this.floatingActionButton, this.large = false, this.bottom, this.subtitle, this.brand = false});

  final String title;

  /// Secondary line under a [large] title (e.g. today's date on the dashboard).
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool large;
  final PreferredSizeWidget? bottom;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: brand ? 48 : null,
        leading: brand ? const Center(child: BrandIcon(size: 26)) : null,
        automaticallyImplyLeading: !brand,
        title: subtitle == null
            ? Text(title, style: large ? t.headlineSmall : t.titleMedium)
            : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: large ? t.headlineSmall : t.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle!, style: t.bodySmall),
              ]),
        toolbarHeight: large ? (subtitle == null ? 68 : 80) : kToolbarHeight,
        actions: [...?actions, const SizedBox(width: AppSpacing.sm)],
        bottom: bottom,
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

/// Panel used for the few most important blocks (e.g. the assessment summary).
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.panelBorder,
        border: Border.all(color: AppColors.primaryBorder),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primarySoft, AppColors.primaryFaint]),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: AppRadius.panelBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: child)),
      ),
    );
  }
}

class Disclaimer extends StatelessWidget {
  const Disclaimer({super.key, this.text = 'SUSTHITI provides AI-assisted informational insights and does not replace professional medical diagnosis, treatment, or emergency care.'});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }
}
