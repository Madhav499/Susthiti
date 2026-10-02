import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/system.dart';
import '../../data/providers.dart';
import '../notifications/notifications.dart';

final doctorDashboardProvider = FutureProvider.autoDispose<DoctorDashboard>((ref) => ref.watch(doctorRepositoryProvider).dashboard());

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      title: 'Dashboard',
      large: true,
      actions: const [NotificationBell()],
      body: PageBody(
        onRefresh: () async => ref.invalidate(doctorDashboardProvider),
        children: [
          AsyncBody(
            value: ref.watch(doctorDashboardProvider),
            onRetry: () => ref.invalidate(doctorDashboardProvider),
            data: (d) => _Body(d: d),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.d});
  final DoctorDashboard d;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    int m(String k) => d.metrics[k] ?? 0;

    final metrics = ResponsiveGrid(minItemWidth: 170, maxColumns: 5, children: [
      MetricTile(icon: Icons.people_outline, label: 'Patients', value: '${m('patients')}', caption: 'with approved access', onTap: () => context.go('/d/patients')),
      MetricTile(icon: Icons.hourglass_empty, label: 'Pending requests', value: '${m('pending_requests')}', caption: 'awaiting patient approval', onTap: () => context.go('/d/requests')),
      MetricTile(icon: Icons.healing_outlined, label: 'Open side effects', value: '${m('open_side_effects')}', caption: 'not yet resolved', onTap: () => context.go('/d/patients?filter=side_effects')),
      MetricTile(icon: Icons.event_outlined, label: 'Follow-ups', value: '${m('follow_ups_7d')}', caption: 'in the next 7 days', onTap: () => context.go('/d/patients?filter=follow_up')),
      MetricTile(icon: Icons.description_outlined, label: 'New reports', value: '${m('recent_reports_7d')}', caption: 'in the last 7 days'),
    ]);

    final attention = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Needs attention', subtitle: 'Based on patient-reported severity, unresolved items and due follow-ups. Not a clinical triage.'),
      if (d.needsAttention.isEmpty)
        const AppCard(child: EmptyState(icon: Icons.check_circle_outline, title: 'Nothing needs attention right now.', compact: true))
      else
        for (final a in d.needsAttention) ...[
          AppCard(
            onTap: () => context.push('/d/patients/${a.patientId}'),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconBadge(Icons.priority_high, tone: StatusTone.attention),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${a.name} · ${a.patientCode}', style: t.titleSmall),
                  const SizedBox(height: 2),
                  for (final r in a.reasons) Text('${r.reason}${r.at != null ? ' · ${Fmt.relative(r.at)}' : ''}', style: t.bodySmall),
                ]),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
    ]);

    final actions = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Quick actions'),
      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
        FilledButton.icon(onPressed: () => context.push('/d/patients/add'), icon: const Icon(Icons.person_add_alt_outlined), label: const Text('Add Patient')),
        OutlinedButton.icon(onPressed: () => context.go('/d/patients'), icon: const Icon(Icons.people_outline), label: const Text('My Patients')),
        OutlinedButton.icon(onPressed: () => context.go('/d/requests'), icon: const Icon(Icons.verified_user_outlined), label: const Text('Access Requests')),
      ]),
    ]);

    final activity = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Recent activity'),
      AppCard(
        child: d.recentActivity.isEmpty
            ? Text('No recent activity.', style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final a in d.recentActivity)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.sentence, style: t.bodyMedium),
                      Text(Fmt.relative(a.createdAt), style: t.bodySmall),
                    ]),
                  ),
              ]),
      ),
    ]);

    const gap = SizedBox(height: AppSpacing.section);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${Fmt.greeting()}, Dr. ${Fmt.firstName(d.doctorName)}', style: t.headlineSmall),
      const SizedBox(height: AppSpacing.lg),
      metrics,
      gap,
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: attention),
          const SizedBox(width: AppSpacing.xxl),
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [actions, gap, activity])),
        ])
      else ...[attention, gap, actions, gap, activity],
      const Disclaimer(),
    ]);
  }
}
