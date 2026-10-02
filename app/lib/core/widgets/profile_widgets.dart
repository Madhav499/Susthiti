import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'avatar.dart';
import 'feedback.dart';

/// Detail-page header: back link (+ breadcrumbs on desktop), avatar, identity lines, status and
/// actions. Shared by the doctor and patient profiles so both read the same way.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.backLabel,
    required this.onBack,
    this.breadcrumbs = const [],
    this.idLabel,
    this.details = const [],
    this.status,
    this.badges = const [],
    this.actions = const [],
  });

  final String name;
  final String backLabel;
  final VoidCallback onBack;

  /// Shown on desktop only, e.g. ['Admin', 'Doctors', 'Dr. James Wilson'].
  final List<String> breadcrumbs;
  final String? idLabel;
  final List<String> details;
  final Widget? status;
  final List<Widget> badges;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final size = context.screenSize;
    final mobile = size == ScreenSize.mobile;

    final identity = Column(
      crossAxisAlignment: mobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          alignment: mobile ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(name, style: t.headlineSmall, textAlign: mobile ? TextAlign.center : TextAlign.start),
            ?status,
            ...badges,
          ],
        ),
        if (idLabel != null) ...[
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            idLabel!,
            style: t.titleSmall?.copyWith(color: AppColors.primaryDeep, letterSpacing: 0.6, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
        if (details.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            details.join('  ·  '),
            style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: mobile ? TextAlign.center : TextAlign.start,
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(backLabel),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
            ),
            if (size == ScreenSize.desktop && breadcrumbs.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Text(
                  breadcrumbs.join('  /  '),
                  style: t.labelMedium?.copyWith(color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (mobile)
          Column(
            children: [
              SusthitiAvatar(name, size: 72),
              const SizedBox(height: AppSpacing.md),
              identity,
              if (actions.isNotEmpty) ...[const SizedBox(height: AppSpacing.lg), Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, alignment: WrapAlignment.center, children: actions)],
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SusthitiAvatar(name, size: 72),
              const SizedBox(width: AppSpacing.lgPlus),
              Expanded(child: identity),
              if (actions.isNotEmpty) ...[const SizedBox(width: AppSpacing.lg), Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: actions)],
            ],
          ),
      ],
    );
  }
}

/// A titled card that loads on its own. When it fails it shows its own retry, so one broken
/// section never takes down the rest of the profile.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.title,
    required this.value,
    required this.onRetry,
    required this.builder,
    this.action,
    this.subtitle,
    this.loadingLines = 3,
    this.padding = const EdgeInsets.all(AppSpacing.lgPlus),
  });

  final String title;
  final String? subtitle;
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;
  final Widget? action;
  final int loadingLines;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      // Transparent Material inside the card so list rows show their ink.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: Text(title, style: t.titleMedium)),
                        if (subtitle != null) Text(subtitle!, style: t.bodySmall),
                      ],
                    ),
                  ),
                  ?action,
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              value.when(
                skipLoadingOnRefresh: true,
                loading: () => Column(
                  children: [
                    for (var i = 0; i < loadingLines; i++) ...[const Skeleton(height: 18), const SizedBox(height: AppSpacing.sm)],
                  ],
                ),
                error: (e, _) => Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: AppColors.warningText),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text('Unable to load $title.', style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                    ),
                    TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
                  ],
                ),
                data: builder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet one-line message used for empty sections ("No active patients").
class EmptyLine extends StatelessWidget {
  const EmptyLine(this.message, {super.key, this.icon});
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon ?? Icons.inbox_outlined, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// Compact stat: big number, label, optional caption. Used in profile overview rows.
class StatBlock extends StatelessWidget {
  const StatBlock({super.key, required this.label, required this.value, this.caption, this.icon, this.onTap});
  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value${caption == null ? '' : ', $caption'}',
      button: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Text(label, style: t.labelMedium, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  value,
                  style: t.headlineSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (caption != null) Text(caption!, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileTab {
  const ProfileTab(this.key, this.label, this.body);

  /// Stable id used in links, e.g. /a/doctors/abc?tab=patients.
  final String key;
  final String label;
  final Widget body;
}

/// Header that scrolls away, a pinned (horizontally scrollable) tab bar, and one body per tab.
/// Children can switch tabs with [TabbedProfile.goTo].
class TabbedProfile extends StatelessWidget {
  const TabbedProfile({super.key, required this.header, required this.tabs, this.initialTab});

  final Widget header;
  final List<ProfileTab> tabs;
  final String? initialTab;

  static void goTo(BuildContext context, String key) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ProfileTabsScope>();
    final index = scope?.keys.indexOf(key) ?? -1;
    if (index >= 0) DefaultTabController.of(context).animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final gutter = context.screenSize == ScreenSize.mobile ? AppSpacing.lg : AppSpacing.xxl;
    final initial = tabs.indexWhere((t) => t.key == initialTab);
    return DefaultTabController(
      length: tabs.length,
      initialIndex: initial < 0 ? 0 : initial,
      child: _ProfileTabsScope(
        keys: [for (final t in tabs) t.key],
        child: Scaffold(
          body: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.lg),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: Breakpoints.maxContentWidth),
                        child: header,
                      ),
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      padding: EdgeInsets.symmetric(horizontal: gutter - AppSpacing.md),
                      tabs: [for (final t in tabs) Tab(text: t.label)],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  for (final t in tabs)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: t.body,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTabsScope extends InheritedWidget {
  const _ProfileTabsScope({required this.keys, required super.child});
  final List<String> keys;

  @override
  bool updateShouldNotify(_ProfileTabsScope old) => old.keys.join() != keys.join();
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: maxExtent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.tabBar != tabBar;
}

/// Lays out children in two columns on desktop and stacks them elsewhere.
class TwoColumn extends StatelessWidget {
  const TwoColumn({super.key, required this.left, required this.right, this.leftFlex = 1, this.rightFlex = 1, this.breakpoint = Breakpoints.desktop});
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < breakpoint - 280) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: AppSpacing.lg),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: AppSpacing.lg),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}
