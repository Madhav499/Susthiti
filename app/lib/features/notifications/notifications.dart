import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/system.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../authentication/auth_controller.dart';

/// Unread count, refreshed every minute while visible.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final timer = Timer(const Duration(seconds: 60), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(notificationRepositoryProvider).unreadCount();
});

final notificationsProvider = FutureProvider.autoDispose.family<List<AppNotification>, String>((ref, status) async {
  return (await ref.watch(notificationRepositoryProvider).list(status: status)).items;
});

final notificationPreferencesProvider = FutureProvider.autoDispose<NotificationPreferences>((ref) => ref.watch(notificationRepositoryProvider).preferences());

String _notificationsRoute(UserRole? role) => role == UserRole.doctor ? '/d/notifications' : '/p/notifications';

/// Marks a notification read (if needed) and opens the record it refers to.
Future<void> openNotification(BuildContext context, WidgetRef ref, AppNotification n) async {
  final user = ref.read(currentUserProvider);
  if (!n.isRead) {
    try {
      await ref.read(notificationRepositoryProvider).markRead(n.id);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }
  if (user == null || !context.mounted) return;
  final route = notificationRoute(n, user);
  if (route != null) context.push(route);
}

Future<void> markAllNotificationsRead(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(notificationRepositoryProvider).markAllRead();
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  } catch (e) {
    if (context.mounted) showFailure(context, e);
  }
}

/// Phones: opens the notifications screen. Tablet and desktop: opens a panel under the bell with
/// the most recent notifications and a link to the full list.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(unreadCountProvider).value ?? 0;
    final role = ref.watch(currentUserProvider)?.role;
    final panel = context.screenSize != ScreenSize.mobile;
    final bell = IconButton(
      tooltip: count > 0 ? 'Notifications, $count unread' : 'Notifications',
      onPressed: () {
        if (!panel) {
          context.push(_notificationsRoute(role));
        } else if (_menu.isOpen) {
          _menu.close();
        } else {
          ref.invalidate(notificationsProvider('all'));
          _menu.open();
        }
      },
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: AppColors.primary,
        label: Text(count > 9 ? '9+' : '$count'),
        child: const Icon(Icons.notifications_none_outlined),
      ),
    );
    if (!panel) return bell;
    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(-340, 4),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card), side: const BorderSide(color: AppColors.border))),
      ),
      menuChildren: [
        NotificationPanel(
          onOpen: (n) {
            _menu.close();
            openNotification(context, ref, n);
          },
          onViewAll: () {
            _menu.close();
            context.push(_notificationsRoute(role));
          },
        ),
      ],
      child: bell,
    );
  }
}

/// Recent notifications shown in the bell's panel on tablet and desktop.
class NotificationPanel extends ConsumerWidget {
  const NotificationPanel({super.key, required this.onOpen, required this.onViewAll});
  final ValueChanged<AppNotification> onOpen;
  final VoidCallback onViewAll;

  static const _shown = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final value = ref.watch(notificationsProvider('all'));
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return SizedBox(
      width: 380,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
          child: Row(children: [
            Expanded(child: Text('Notifications', style: t.titleMedium)),
            if (unread > 0) TextButton(onPressed: () => markAllNotificationsRead(context, ref), child: const Text('Mark all read')),
          ]),
        ),
        const Divider(height: 1),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: value.when(
            skipLoadingOnRefresh: true,
            loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Notifications could not be loaded.', style: t.bodyMedium),
                TextButton(onPressed: () => ref.invalidate(notificationsProvider('all')), child: const Text('Retry')),
              ]),
            ),
            data: (items) => items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text("You're all caught up.", textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  )
                : SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < items.length && i < _shown; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                        _NotificationTile(items[i], onTap: () => onOpen(items[i])),
                      ],
                    ]),
                  ),
          ),
        ),
        const Divider(height: 1),
        TextButton(onPressed: onViewAll, child: const Text('View all notifications')),
        const SizedBox(height: AppSpacing.xs),
      ]),
    );
  }
}

/// Where a notification leads. Patients and doctors see the same record screens; the backend
/// re-checks authorization on every request.
String? notificationRoute(AppNotification n, AppUser user) {
  final pid = n.patientId ?? user.patientId;
  final isDoctor = user.role == UserRole.doctor;
  switch (n.entityType) {
    case 'report':
      return pid == null ? null : '/r/$pid/reports/${n.entityId}';
    case 'side_effect':
      return pid == null ? null : '/r/$pid/side-effects/${n.entityId}';
    case 'prescription':
      return pid == null ? null : '/r/$pid/prescriptions/${n.entityId}';
    case 'visit':
      return pid == null ? null : '/r/$pid/visits/${n.entityId}';
    case 'ai_summary':
      return pid == null ? null : '/r/$pid/reports-summary';
    case 'appointment':
      return '/p/appointments';
    case 'follow_up':
      return isDoctor ? (pid == null ? null : '/d/patients/$pid?tab=7') : '/p/follow-ups';
    case 'surgery':
      return isDoctor ? (pid == null ? null : '/d/patients/$pid?tab=8') : '/p/surgeries';
    case 'access_request':
      return isDoctor ? '/d/requests' : '/p/access';
    case 'patient':
      return isDoctor && pid != null ? '/d/patients/$pid' : null;
  }
  return null;
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _status = 'all';

  Future<void> _open(AppNotification n) => openNotification(context, ref, n);

  Future<void> _markAll() => markAllNotificationsRead(context, ref);

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(notificationsProvider(_status));
    return AppPage(
      title: 'Notifications',
      large: widget.embedded,
      actions: [TextButton(onPressed: _markAll, child: const Text('Mark all read'))],
      body: PageBody(
        maxWidth: 760,
        onRefresh: () async => ref.invalidate(notificationsProvider(_status)),
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 'all', label: Text('All')), ButtonSegment(value: 'unread', label: Text('Unread')), ButtonSegment(value: 'read', label: Text('Read'))],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          AsyncBody(
            value: value,
            onRetry: () => ref.invalidate(notificationsProvider(_status)),
            data: (items) => items.isEmpty
                ? const EmptyState(icon: Icons.notifications_none_outlined, title: 'No notifications', message: "You're all caught up.")
                : AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                        _NotificationTile(items[i], onTap: () => _open(items[i])),
                      ],
                    ]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(this.n, {required this.onTap});
  final AppNotification n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: '${n.isRead ? '' : 'Unread. '}${n.title}. ${n.body}. ${Fmt.relative(n.createdAt)}',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: n.isRead ? Colors.transparent : AppColors.primary)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.title, style: t.titleSmall?.copyWith(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w600)),
                const SizedBox(height: 2),
                Text(n.body, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text(Fmt.relative(n.createdAt), style: t.labelSmall),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Notification preference switches (respected by the backend reminder job).
class NotificationPreferencesCard extends ConsumerWidget {
  const NotificationPreferencesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final role = ref.watch(currentUserProvider)?.role;
    Future<void> set(String key, bool value) async {
      try {
        await ref.read(notificationRepositoryProvider).updatePreferences({key: value});
        ref.invalidate(notificationPreferencesProvider);
      } catch (e) {
        if (context.mounted) showFailure(context, e);
      }
    }

    return AsyncBody(
      value: prefs,
      loading: const SkeletonList(count: 2, itemHeight: 56),
      onRetry: () => ref.invalidate(notificationPreferencesProvider),
      data: (p) => AppCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(children: [
          if (role == UserRole.patient) ...[
            SwitchListTile(title: const Text('Food logging reminders'), subtitle: const Text('An evening nudge if no meals are logged'), value: p.foodReminders, onChanged: (v) => set('food_reminders', v)),
            SwitchListTile(title: const Text('Lifestyle reminders'), subtitle: const Text('When no activity or sleep data was recorded this week'), value: p.lifestyleReminders, onChanged: (v) => set('lifestyle_reminders', v)),
          ],
          SwitchListTile(title: const Text('Follow-up reminders'), value: p.followUpReminders, onChanged: (v) => set('follow_up_reminders', v)),
          if (role == UserRole.doctor)
            SwitchListTile(title: const Text('Patient updates'), subtitle: const Text('New reports and patient updates'), value: p.doctorNotifications, onChanged: (v) => set('doctor_notifications', v)),
        ]),
      ),
    );
  }
}
