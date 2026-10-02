import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/care.dart';
import '../../data/providers.dart';

typedef TimelineKey = ({String patientId, String type});

final timelineProvider = FutureProvider.autoDispose.family<({List<TimelineEvent> items, bool hasMore}), TimelineKey>(
  (ref, k) => ref.watch(patientRepositoryProvider).timeline(k.patientId, type: k.type),
);
final appointmentsProvider = FutureProvider.autoDispose.family<List<AppointmentRecommendation>, String>((ref, pid) => ref.watch(patientRepositoryProvider).appointments(pid));

/// Filter -> label. Keys are the server's timeline filter names.
const timelineFilters = {
  'all': 'All',
  'reports': 'Reports',
  'assessments': 'Assessments',
  'prescriptions': 'Prescriptions',
  'visits': 'Visits',
  'side_effects': 'Side effects',
  'appointments': 'Appointments',
  'ai': 'AI summaries',
};

/// Longitudinal history. Each event keeps its own medical date (a report is placed by its report
/// date, not by when it was uploaded).
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key, required this.patientId});
  final String patientId;

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  String _type = 'all';

  @override
  Widget build(BuildContext context) {
    final key = (patientId: widget.patientId, type: _type);
    return AppPage(
      title: 'Health Timeline',
      body: PageBody(maxWidth: 760, onRefresh: () async => ref.invalidate(timelineProvider(key)), children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final e in timelineFilters.entries)
              Padding(padding: const EdgeInsets.only(right: AppSpacing.sm), child: ChoiceChip(label: Text(e.value), selected: _type == e.key, onSelected: (_) => setState(() => _type = e.key))),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: ref.watch(timelineProvider(key)),
          onRetry: () => ref.invalidate(timelineProvider(key)),
          data: (r) => r.items.isEmpty
              ? const EmptyState(icon: Icons.timeline_outlined, title: 'No records yet.', message: 'Reports, assessments, prescriptions and visits will appear here in date order.')
              : AppCard(
                  child: Column(children: [
                    for (var i = 0; i < r.items.length; i++)
                      _TimelineRow(event: r.items[i], isLast: i == r.items.length - 1, route: timelineRoute(widget.patientId, r.items[i])),
                  ]),
                ),
        ),
      ]),
    );
  }
}

String? timelineRoute(String pid, TimelineEvent e) => switch (e.type) {
      'report' => '/r/$pid/reports/${e.id}',
      'assessment' => '/r/$pid/assessments/${e.id}',
      'diabetes_risk' => '/r/$pid/diabetes-risk/${e.id}',
      'prescription' => '/r/$pid/prescriptions/${e.id}',
      'visit' => '/r/$pid/visits/${e.id}',
      'side_effect' => '/r/$pid/side-effects/${e.id}',
      'ai_summary' => e.title.contains('Patient') ? '/r/$pid/patient-summary' : '/r/$pid/reports-summary',
      _ => null,
    };

IconData _icon(String type) => switch (type) {
      'report' => Icons.description_outlined,
      'assessment' => Icons.fact_check_outlined,
      'diabetes_risk' => Icons.insights_outlined,
      'prescription' => Icons.medication_outlined,
      'visit' => Icons.event_note_outlined,
      'side_effect' => Icons.healing_outlined,
      'appointment_recommendation' => Icons.event_available_outlined,
      'ai_summary' => Icons.auto_awesome_outlined,
      _ => Icons.circle_outlined,
    };

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast, this.route});
  final TimelineEvent event;
  final bool isLast;
  final String? route;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = event;
    return InkWell(
      onTap: route == null ? null : () => context.push(route!),
      borderRadius: AppRadius.controlBorder,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Column(children: [
            IconBadge(_icon(e.type), size: 34),
            if (!isLast) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: AppColors.border)),
          ]),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg, top: 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(e.title, style: t.titleSmall)),
                  if (e.type == 'ai_summary') ...[const SizedBox(width: 6), const AiLabel(text: 'AI')],
                ]),
                Text([Fmt.date(e.date), e.subtitle, e.code].whereType<String>().where((s) => s.isNotEmpty).join(' · '), style: t.bodySmall),
              ]),
            ),
          ),
          if (route != null) const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.chevron_right, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'Appointment Recommendations',
      body: PageBody(maxWidth: 760, onRefresh: () async => ref.invalidate(appointmentsProvider(patientId)), children: [
        Text('Recommendations from your doctor. Please contact the clinic to book a time.', style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: ref.watch(appointmentsProvider(patientId)),
          onRetry: () => ref.invalidate(appointmentsProvider(patientId)),
          data: (items) => items.isEmpty
              ? const EmptyState(icon: Icons.event_available_outlined, title: 'No appointment recommendations.')
              : Column(children: [
                  for (final a in items) ...[
                    AppCard(
                      onTap: a.sideEffectId == null ? null : () => context.push('/r/$patientId/side-effects/${a.sideEffectId}'),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const IconBadge(Icons.event_available_outlined),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.reason, style: t.titleSmall),
                            const SizedBox(height: 2),
                            Text('Dr. ${a.doctorName} · ${Fmt.date(a.createdAt)}', style: t.bodySmall),
                            if (a.recommendedFor != null) Text('Suggested for ${Fmt.date(a.recommendedFor)}', style: t.bodySmall?.copyWith(color: AppColors.primary)),
                            if (a.sideEffectId != null) Text('Related to a side-effect report', style: t.bodySmall),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ]),
        ),
      ]),
    );
  }
}
