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
import '../../l10n/app_localizations.dart';
import '../notifications/notifications.dart';

final doctorDashboardProvider = FutureProvider.autoDispose<DoctorDashboard>((ref) => ref.watch(doctorRepositoryProvider).dashboard());

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: l10n.navDashboard,
      large: true,
      brand: true,
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
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    int m(String k) => d.metrics[k] ?? 0;

    final metrics = ResponsiveGrid(minItemWidth: 170, maxColumns: 6, children: [
      MetricTile(icon: Icons.people_outline, label: l10n.docPatientsLabel, value: '${m('patients')}', caption: l10n.docPatientsCaption, onTap: () => context.go('/d/patients')),
      MetricTile(icon: Icons.hourglass_empty, label: l10n.docPendingRequests, value: '${m('pending_requests')}', caption: l10n.docPendingRequestsCaption, onTap: () => context.go('/d/requests')),
      MetricTile(icon: Icons.healing_outlined, label: l10n.docOpenSideEffects, value: '${m('open_side_effects')}', caption: l10n.docOpenSideEffectsCaption, onTap: () => context.go('/d/patients?filter=side_effects')),
      MetricTile(icon: Icons.event_outlined, label: l10n.navFollowUps, value: '${m('follow_ups_7d')}', caption: l10n.docFollowUpsCaption, onTap: () => context.go('/d/patients?filter=follow_up')),
      MetricTile(icon: Icons.event_available_outlined, label: l10n.navAppointments, value: '${m('upcoming_appointments_7d')}', caption: l10n.docAppointmentsCaption),
      MetricTile(icon: Icons.description_outlined, label: l10n.docNewReports, value: '${m('recent_reports_7d')}', caption: l10n.docNewReportsCaption),
    ]);

    final attention = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l10n.docNeedsAttention, subtitle: l10n.docNeedsAttentionSubtitle),
      if (d.needsAttention.isEmpty)
        AppCard(child: EmptyState(icon: Icons.check_circle_outline, title: l10n.docNothingNeedsAttention, compact: true))
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
                  for (final r in a.reasons) Text('${r.reason}${r.at != null ? ' · ${Fmt.relative(l10n, r.at)}' : ''}', style: t.bodySmall),
                ]),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
    ]);

    final actions = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l10n.docQuickActions),
      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
        FilledButton.icon(onPressed: () => context.push('/d/patients/add'), icon: const Icon(Icons.person_add_alt_outlined), label: Text(l10n.docAddPatient)),
        OutlinedButton.icon(onPressed: () => context.go('/d/patients'), icon: const Icon(Icons.people_outline), label: Text(l10n.docMyPatients)),
        OutlinedButton.icon(onPressed: () => context.go('/d/requests'), icon: const Icon(Icons.verified_user_outlined), label: Text(l10n.docAccessRequests)),
      ]),
    ]);

    final activity = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l10n.docRecentActivity),
      AppCard(
        child: d.recentActivity.isEmpty
            ? Text(l10n.docNoRecentActivity, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final a in d.recentActivity)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.sentence, style: t.bodyMedium),
                      Text(Fmt.relative(l10n, a.createdAt), style: t.bodySmall),
                    ]),
                  ),
              ]),
      ),
    ]);

    const gap = SizedBox(height: AppSpacing.section);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${Fmt.greeting(l10n)}, ${l10n.commonDrName(Fmt.firstName(d.doctorName))}', style: t.headlineSmall),
      if (d.today.isNotEmpty) Text(_todaySummary(l10n, d.today), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: AppSpacing.lg),
      _TodaySchedule(items: d.today, l10n: l10n),
      gap,
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

  /// "Today you have 2 appointments, 1 follow-up and 1 surgery." Built only from real items —
  /// never a fabricated count. Only called when [items] is non-empty; the empty case is its
  /// own "Your schedule is clear today." card below, not repeated here.
  String _todaySummary(AppLocalizations l10n, List<ScheduleItem> items) {
    int count(ScheduleItemType t) => items.where((i) => i.type == t).length;
    final parts = [
      if (count(ScheduleItemType.appointment) > 0) l10n.docSummaryAppointments(count(ScheduleItemType.appointment)),
      if (count(ScheduleItemType.followUp) > 0) l10n.docSummaryFollowUps(count(ScheduleItemType.followUp)),
      if (count(ScheduleItemType.surgery) > 0) l10n.docSummarySurgeries(count(ScheduleItemType.surgery)),
    ];
    final joined = parts.length == 1 ? parts.first : '${parts.sublist(0, parts.length - 1).join(', ')} ${l10n.commonAnd} ${parts.last}';
    return l10n.docTodaySummary(joined);
  }
}

/// Today's appointments, follow-ups and surgeries, earliest first, with a type filter.
/// "My Day" — PART 28: a doctor should be able to see and open today's schedule directly.
class _TodaySchedule extends StatefulWidget {
  const _TodaySchedule({required this.items, required this.l10n});
  final List<ScheduleItem> items;
  final AppLocalizations l10n;

  @override
  State<_TodaySchedule> createState() => _TodayScheduleState();
}

class _TodayScheduleState extends State<_TodaySchedule> {
  ScheduleItemType? _filter;

  static String _typeLabel(ScheduleItemType t, AppLocalizations l10n) => switch (t) {
        ScheduleItemType.appointment => l10n.docAppointmentType,
        ScheduleItemType.followUp => l10n.docFollowUpType,
        ScheduleItemType.surgery => l10n.docSurgeryType,
      };

  static IconData _typeIcon(ScheduleItemType t) => switch (t) {
        ScheduleItemType.appointment => Icons.event_available_outlined,
        ScheduleItemType.followUp => Icons.event_repeat_outlined,
        ScheduleItemType.surgery => Icons.local_hospital_outlined,
      };

  /// appointment -> patient overview (no dedicated doctor appointment screen exists); follow-up
  /// and surgery -> their tab on the patient's detail page.
  static String _route(ScheduleItem i) => switch (i.type) {
        ScheduleItemType.appointment => '/d/patients/${i.patientId}',
        ScheduleItemType.followUp => '/d/patients/${i.patientId}?tab=8',
        ScheduleItemType.surgery => '/d/patients/${i.patientId}?tab=9',
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = widget.l10n;
    final items = widget.items;
    final shown = _filter == null ? items : items.where((i) => i.type == _filter).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l10n.docToday),
      if (items.isNotEmpty) ...[
        Wrap(spacing: AppSpacing.sm, children: [
          ChoiceChip(label: Text(l10n.docAll), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
          for (final type in ScheduleItemType.values)
            ChoiceChip(label: Text(_typeLabel(type, l10n)), selected: _filter == type, onSelected: (_) => setState(() => _filter = type)),
        ]),
        const SizedBox(height: AppSpacing.md),
      ],
      if (items.isEmpty)
        AppCard(child: EmptyState(icon: Icons.event_available_outlined, title: l10n.docScheduleClear, compact: true))
      else
        for (final i in shown) ...[
          AppCard(
            onTap: () => context.push(_route(i)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconBadge(_typeIcon(i.type)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.title, style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text([i.patientName, i.patientCode].whereType<String>().join(' · '), style: t.bodySmall),
                ]),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(i.at == null ? l10n.docTodayAt : Fmt.time(i.at), style: t.labelLarge?.copyWith(color: AppColors.primaryDeep, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
    ]);
  }
}
