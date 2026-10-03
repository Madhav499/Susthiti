import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/auth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/brand.dart';

class ShellDestination {
  const ShellDestination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Secondary page shown only in the desktop sidebar (phones reach it from within screens).
class ShellLink {
  const ShellLink(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

/// Bottom navigation on phones, a compact rail on tablets, a full sidebar on desktop.
/// All three share the same destinations and the same blue active state.
class RoleShell extends StatelessWidget {
  const RoleShell({super.key, required this.shell, required this.destinations, this.links = const [], this.header, this.accountRoute});

  final StatefulNavigationShell shell;
  final List<ShellDestination> destinations;
  final List<ShellLink> links;
  final Widget? header;

  /// Where the sidebar's profile block leads (desktop only).
  final String? accountRoute;

  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    switch (context.screenSize) {
      case ScreenSize.mobile:
        return Scaffold(
          body: shell,
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [BoxShadow(color: Color(0x0A1E3A5F), blurRadius: 12, offset: Offset(0, -2))],
            ),
            child: NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [for (final d in destinations) NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label)],
            ),
          ),
        );
      case ScreenSize.tablet:
        return Scaffold(
          body: Row(children: [
            _CompactRail(destinations: destinations, selected: shell.currentIndex, onSelect: _go),
            Expanded(child: shell),
          ]),
        );
      case ScreenSize.desktop:
        return Scaffold(
          body: Row(children: [
            _Sidebar(destinations: destinations, links: links, selected: shell.currentIndex, onSelect: _go, header: header, accountRoute: accountRoute),
            Expanded(child: shell),
          ]),
        );
    }
  }
}

/// Keeps the sidebar (desktop) or rail (tablet) around a page opened above the shell, such as
/// a doctor or patient profile. Selecting a destination goes to that section's root.
class RoleFrame extends StatelessWidget {
  const RoleFrame({
    super.key,
    required this.child,
    required this.destinations,
    required this.routes,
    required this.selected,
    this.links = const [],
    this.header,
    this.accountRoute,
  });

  final Widget child;
  final List<ShellDestination> destinations;

  /// Root route of each destination, same order as [destinations].
  final List<String> routes;
  final int selected;
  final List<ShellLink> links;
  final Widget? header;
  final String? accountRoute;

  @override
  Widget build(BuildContext context) {
    void go(int i) => context.go(routes[i]);
    return switch (context.screenSize) {
      ScreenSize.mobile => child,
      ScreenSize.tablet => Scaffold(body: Row(children: [_CompactRail(destinations: destinations, selected: selected, onSelect: go), Expanded(child: child)])),
      ScreenSize.desktop => Scaffold(
          body: Row(children: [
            _Sidebar(destinations: destinations, links: links, selected: selected, onSelect: go, header: header, accountRoute: accountRoute),
            Expanded(child: child),
          ]),
        ),
    };
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.destinations, required this.links, required this.selected, required this.onSelect, this.header, this.accountRoute});

  final List<ShellDestination> destinations;
  final List<ShellLink> links;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget? header;
  final String? accountRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(right: BorderSide(color: AppColors.border))),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
            child: Align(alignment: Alignment.centerLeft, child: header ?? const SizedBox.shrink()),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _SidebarItem(label: destinations[i].label, icon: i == selected ? destinations[i].selectedIcon : destinations[i].icon, selected: i == selected, onTap: () => onSelect(i)),
                  ),
                if (links.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                    child: Text('MORE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted, letterSpacing: 1)),
                  ),
                  for (final link in links)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: _SidebarItem(label: link.label, icon: link.icon, selected: false, onTap: () => context.push(link.route)),
                    ),
                ],
              ],
            ),
          ),
          const Divider(),
          _SidebarProfile(accountRoute: accountRoute),
        ]),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        borderRadius: AppRadius.buttonBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: AppColors.surfaceSecondary,
          child: SizedBox(
            height: 44,
            child: Row(children: [
              AnimatedContainer(
                duration: AppDurations.fast,
                width: 3,
                height: 20,
                decoration: BoxDecoration(color: selected ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: selected ? AppColors.primaryDeep : AppColors.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SidebarProfile extends ConsumerWidget {
  const _SidebarProfile({this.accountRoute});
  final String? accountRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.buttonBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: accountRoute == null ? null : () => context.go(accountRoute!),
          hoverColor: AppColors.surfaceSecondary,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(children: [
              SusthitiAvatar(user.fullName, size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.fullName, style: t.labelLarge, overflow: TextOverflow.ellipsis),
                  Text(user.role.label, style: t.labelMedium),
                ]),
              ),
              IconButton(
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout, size: 18, color: AppColors.textSecondary),
                onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CompactRail extends StatelessWidget {
  const _CompactRail({required this.destinations, required this.selected, required this.onSelect});

  final List<ShellDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: 88,
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(right: BorderSide(color: AppColors.border))),
      child: SafeArea(
        child: Column(children: [
          const SizedBox(height: AppSpacing.xl),
          const BrandIcon(size: 36),
          const SizedBox(height: AppSpacing.xxl),
          for (var i = 0; i < destinations.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Semantics(
                selected: i == selected,
                button: true,
                label: destinations[i].label,
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onSelect(i),
                  borderRadius: AppRadius.buttonBorder,
                  child: SizedBox(
                    width: 72,
                    child: Column(children: [
                      AnimatedContainer(
                        duration: AppDurations.fast,
                        width: 52,
                        height: 32,
                        decoration: BoxDecoration(color: i == selected ? AppColors.primarySoft : Colors.transparent, borderRadius: AppRadius.buttonBorder),
                        child: Icon(i == selected ? destinations[i].selectedIcon : destinations[i].icon, size: 22, color: i == selected ? AppColors.primary : AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        destinations[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelSmall?.copyWith(color: i == selected ? AppColors.primaryDeep : AppColors.textSecondary, fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
