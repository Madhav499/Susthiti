import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Surface with a subtle border; lifted, not floating.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.tinted = false,
    this.radius,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool tinted;
  final BorderRadius? radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppRadius.cardBorder;
    final content = Padding(padding: padding, child: child);
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tinted ? AppColors.primarySoft : AppColors.surface,
          borderRadius: r,
          border: Border.all(color: tinted ? AppColors.primaryBorder : AppColors.border),
          boxShadow: tinted ? null : AppShadows.card,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: r,
          clipBehavior: Clip.antiAlias,
          child: onTap == null ? content : InkWell(onTap: onTap, child: content),
        ),
      ),
    );
  }
}

/// Square-ish action tile: soft icon badge above a short label.
class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      child: ExcludeSemantics(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Fixed to a 2-line slot so every tile in a row is the same height, whether its
          // own label wraps or not.
          SizedBox(
            height: 36,
            child: Center(
              child: Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500)),
            ),
          ),
        ]),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: t.titleLarge)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: t.bodySmall),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.trailing, this.valueWidget});

  final String label;
  final String value;
  final Widget? trailing;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: t.bodySmall)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: valueWidget ?? Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Centers content and limits its width on large screens (no stretched cards).
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = Breakpoints.maxContentWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}

/// Standard scrollable page body with consistent gutters.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = Breakpoints.maxContentWidth, this.onRefresh, this.padding});

  final List<Widget> children;
  final double maxWidth;
  final Future<void> Function()? onRefresh;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width >= Breakpoints.tablet ? AppSpacing.xxl : AppSpacing.lg;
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding ?? EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.xxl * 2),
      children: [
        ContentWidth(
          maxWidth: maxWidth,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, color: AppColors.primary, child: list);
  }
}

/// Grid that adapts columns to width: 1 on mobile, 2 on tablet, up to [maxColumns] on desktop.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minItemWidth = 260, this.maxColumns = 4, this.spacing = AppSpacing.md});

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = (constraints.maxWidth / minItemWidth).floor().clamp(1, maxColumns);
      final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final c in children) SizedBox(width: itemWidth, child: c)],
      );
    });
  }
}
