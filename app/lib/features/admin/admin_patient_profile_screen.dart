import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/activity_timeline.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/labels.dart';
import '../../core/widgets/profile_widgets.dart';
import '../../core/widgets/responsive_table.dart';
import '../../data/models/admin.dart';
import '../../data/models/diabetes_risk.dart';
import '../../data/models/ai_summary.dart';
import '../../data/models/care.dart';
import '../../data/models/patient.dart';
import '../../data/models/report.dart';
import '../../data/models/tracking.dart';
import '../../data/providers.dart';
import '../ai/ai_summary_section.dart';
import '../diabetes/risk_widgets.dart';
import '../diabetes/diabetes_screen.dart';
import '../follow_ups/follow_ups_screens.dart';
import '../food/food_screen.dart';
import '../glucose/glucose_screen.dart';
import '../lifestyle/lifestyle_screen.dart';
import '../lifestyle/trend_card.dart';
import '../patient/profile_screen.dart';
import '../patient/timeline_screen.dart';
import '../prescriptions/prescriptions_screens.dart';
import '../reports/reports_providers.dart';
import '../reports/reports_screen.dart';
import '../side_effects/side_effects_screens.dart';
import '../surgery/surgery_screens.dart';
import '../visits/visits_screens.dart';
import 'admin_common.dart';
import 'admin_doctor_profile_screen.dart' show AuditTable;
import 'admin_screens.dart';

/// Admin's read-only view of a patient's complete system record. The clinical tabs reuse the
/// same views doctors see; they show no write actions to an admin, and the backend refuses
/// every clinical write from an admin regardless.
class AdminPatientProfileScreen extends ConsumerWidget {
  const AdminPatientProfileScreen({super.key, required this.patientId, this.initialTab});
  final String patientId;
  final String? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminPatientProvider(patientId));
    void back() => context.canPop() ? context.pop() : context.go('/a/patients');

    return value.when(
      skipLoadingOnRefresh: true,
      loading: () => const _Skeleton(),
      error: (e, _) => AppPage(
        title: 'Patient',
        body: Column(children: [
          ErrorState(error: e, title: e is NotFoundFailure ? null : 'Unable to load patient details.', onRetry: () => ref.invalidate(adminPatientProvider(patientId))),
          TextButton.icon(onPressed: back, icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Back to Patients')),
        ]),
      ),
      data: (d) {
        final p = d.profile;
        return TabbedProfile(
          initialTab: initialTab,
          header: ProfileHeader(
            name: p.fullName,
            backLabel: 'Back to Patients',
            onBack: back,
            breadcrumbs: ['Admin', 'Patients', p.fullName],
            idLabel: 'Patient ID: ${p.patientCode}',
            details: [if (p.age != null) '${p.age} years', ?p.gender, if (d.lastActivityAt != null) 'Last activity ${Fmt.relative(d.lastActivityAt)}'],
            status: activePill(d.isActive),
            badges: [if (p.isDemo) const DemoBadge()],
            actions: [
              FilledButton.icon(onPressed: () => context.push('/a/patients/${p.id}/edit'), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit Patient')),
              _PatientMoreMenu(detail: d),
            ],
          ),
          tabs: [
            ProfileTab('overview', 'Overview', _OverviewTab(detail: d)),
            ProfileTab('diabetes', 'Diabetes', DiabetesView(patientId: patientId, embedded: true)),
            ProfileTab('reports', 'Reports', ReportsView(patientId: patientId, uploadRoute: '/a/patients/$patientId/upload', embedded: true)),
            ProfileTab('glucose', 'Glucose', GlucoseView(patientId: patientId, embedded: true, ranges: TrendCard.clinicalRanges)),
            ProfileTab('lifestyle', 'Lifestyle', LifestyleView(patientId: patientId, embedded: true, ranges: TrendCard.clinicalRanges)),
            ProfileTab('food', 'Food', _FoodTab(patientId: patientId)),
            ProfileTab('prescriptions', 'Prescriptions', PrescriptionsView(patientId: patientId, embedded: true)),
            ProfileTab('visits', 'Visits', VisitsView(patientId: patientId, embedded: true)),
            ProfileTab('appointments', 'Appointments', _AppointmentsTab(detail: d)),
            ProfileTab('follow-ups', 'Follow-ups', FollowUpsView(patientId: patientId, embedded: true)),
            ProfileTab('surgeries', 'Surgeries', SurgeriesView(patientId: patientId, embedded: true)),
            ProfileTab('side-effects', 'Side Effects', SideEffectsView(patientId: patientId, embedded: true)),
            ProfileTab('ai', 'AI Summaries', _AiTab(patientId: patientId)),
            ProfileTab('doctors', 'Doctors', _DoctorsTab(detail: d)),
            ProfileTab('activity', 'Activity', _ActivityTab(patientId: patientId)),
            ProfileTab('audit', 'Audit', _AuditTab(patientId: patientId)),
          ],
        );
      },
    );
  }
}

class _PatientMoreMenu extends ConsumerWidget {
  const _PatientMoreMenu({required this.detail});
  final AdminPatientDetail detail;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final p = detail.profile;
    if (detail.isActive) {
      final ok = await confirmAction(context, title: 'Deactivate ${p.fullName}?', message: 'They will be signed out and cannot sign in. Their records are kept.', confirmLabel: 'Deactivate', destructive: true);
      if (!ok) return;
    }
    try {
      await ref.read(adminRepositoryProvider).setPatientActive(p.id, !detail.isActive);
      ref.invalidate(adminPatientProvider(p.id));
      ref.invalidate(adminPatientsProvider);
      if (context.mounted) showToast(context, detail.isActive ? 'Patient deactivated' : 'Patient reactivated');
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = detail.profile;
    return PopupMenuButton<String>(
      tooltip: 'More actions',
      onSelected: (a) => switch (a) {
        'upload' => context.push('/a/patients/${p.id}/upload'),
        'toggle' => _toggle(context, ref),
        _ => TabbedProfile.goTo(context, a),
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'reports', child: Text('View reports')),
        const PopupMenuItem(value: 'activity', child: Text('View activity')),
        const PopupMenuItem(value: 'doctors', child: Text('View doctors')),
        const PopupMenuItem(value: 'upload', child: Text('Upload report for patient')),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'toggle', child: Text(detail.isActive ? 'Deactivate account' : 'Reactivate account', style: TextStyle(color: detail.isActive ? AppColors.errorText : null))),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.buttonBorder, border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('More', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.primary)),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.expand_more, size: 18, color: AppColors.primary),
        ]),
      ),
    );
  }
}

// ---------- Overview ----------

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.detail});
  final AdminPatientDetail detail;

  String get _pid => detail.profile.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final lifestyle = ref.watch(lifestyleOverviewProvider(_pid));
    const reportsQuery = ReportQuery();
    final reports = ref.watch(reportsControllerProvider((patientId: _pid, query: reportsQuery)));
    final timeline = ref.watch(timelineProvider((patientId: _pid, type: 'all')));
    final prescriptions = ref.watch(prescriptionsProvider((patientId: _pid, query: '')));
    final sideEffects = ref.watch(sideEffectsProvider(_pid));
    final appointments = ref.watch(appointmentsProvider(_pid));
    final devices = ref.watch(adminPatientDevicesProvider(_pid));
    void goTo(String tab) => TabbedProfile.goTo(context, tab);

    Widget metric(LifestyleMetricType m, IconData icon) => lifestyle.when(
          skipLoadingOnRefresh: true,
          loading: () => const Skeleton(height: 118, radius: 16),
          error: (_, _) => StatBlock(icon: icon, label: m.label, value: '—', caption: 'Unable to load'),
          data: (o) {
            final latest = o.metrics[m]?.latest;
            return StatBlock(
              icon: icon,
              label: m.label,
              value: latest == null ? 'No data' : m.format(latest.value, latest.value2),
              caption: latest == null ? 'Not recorded' : (o.metrics[m]!.isToday ? 'Today' : 'Last recorded ${Fmt.shortDate(latest.date)}'),
              onTap: () => goTo('lifestyle'),
            );
          },
        );

    return PageBody(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.huge),
      onRefresh: () async {
        ref.invalidate(adminPatientProvider(_pid));
        ref.invalidate(lifestyleOverviewProvider(_pid));
        ref.invalidate(timelineProvider);
        ref.invalidate(sideEffectsProvider(_pid));
        ref.invalidate(appointmentsProvider(_pid));
        ref.invalidate(prescriptionsProvider);
        ref.invalidate(reportsControllerProvider);
      },
      children: [
        if (detail.attention.isNotEmpty) ...[
          _AttentionBanner(patientId: _pid, reasons: detail.attention),
          const SizedBox(height: AppSpacing.lg),
        ],
        ResponsiveGrid(minItemWidth: 190, maxColumns: 4, children: [
          StatBlock(
            icon: Icons.water_drop_outlined,
            label: 'Latest glucose',
            value: detail.latestGlucose == null ? 'No data' : '${detail.latestGlucose!.round()} mg/dL',
            caption: detail.latestGlucose == null ? 'No readings yet' : '${Fmt.relative(detail.latestGlucoseAt)} · ${trendLabel(detail.glucoseTrend)}',
            onTap: () => goTo('glucose'),
          ),
          metric(LifestyleMetricType.steps, Icons.directions_walk_outlined),
          metric(LifestyleMetricType.heartRate, Icons.favorite_border),
          metric(LifestyleMetricType.sleep, Icons.bedtime_outlined),
        ]),
        const SizedBox(height: AppSpacing.lg),
        TwoColumn(
          left: _AssessmentCard(detail: detail),
          right: AppCard(
            padding: const EdgeInsets.all(AppSpacing.lgPlus),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionHeader('Current Doctors', action: TextButton(onPressed: () => goTo('doctors'), child: const Text('All relationships'))),
              if (detail.currentDoctors.isEmpty)
                const EmptyLine('No doctor currently has access.', icon: Icons.medical_services_outlined)
              else
                for (final a in detail.currentDoctors) _DoctorRow(access: a),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TwoColumn(
          left: AsyncSection(
            title: 'Recent Reports',
            value: reports,
            onRetry: () => ref.invalidate(reportsControllerProvider((patientId: _pid, query: reportsQuery))),
            action: TextButton(onPressed: () => goTo('reports'), child: const Text('View all')),
            builder: (r) => r.items.isEmpty
                ? const EmptyLine('No reports available.', icon: Icons.description_outlined)
                : Column(children: [
                    for (final report in r.items.take(4)) ...[
                      ReportTile(report: report, onTap: () => context.push('/r/$_pid/reports/${report.id}')),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ]),
          ),
          right: AsyncSection<({List<TimelineEvent> items, bool hasMore})>(
            title: 'Recent Activity',
            value: timeline,
            onRetry: () => ref.invalidate(timelineProvider((patientId: _pid, type: 'all'))),
            action: TextButton(onPressed: () => goTo('activity'), child: const Text('View all')),
            builder: (r) => ActivityTimeline(
              emptyMessage: 'No recorded history yet.',
              entries: [for (final e in r.items.take(7)) _timelineEntry(context, e)],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ResponsiveGrid(minItemWidth: 280, maxColumns: 3, spacing: AppSpacing.lg, children: [
          AsyncSection<List<Prescription>>(
            title: 'Prescriptions',
            value: prescriptions,
            onRetry: () => ref.invalidate(prescriptionsProvider((patientId: _pid, query: ''))),
            action: TextButton(onPressed: () => goTo('prescriptions'), child: const Text('View all')),
            builder: (items) => items.isEmpty
                ? const EmptyLine('No prescriptions recorded.', icon: Icons.medication_outlined)
                : Column(children: [
                    for (final rx in items.take(3))
                      _CompactRow(
                        title: rx.code,
                        subtitle: 'Dr. ${rx.doctorName} · ${Fmt.date(rx.prescribedOn)} · ${rx.medicines.length} medicine${rx.medicines.length == 1 ? '' : 's'}',
                        onTap: () => context.push('/r/$_pid/prescriptions/${rx.id}'),
                      ),
                  ]),
          ),
          AsyncSection<List<SideEffect>>(
            title: 'Side Effects',
            value: sideEffects,
            onRetry: () => ref.invalidate(sideEffectsProvider(_pid)),
            action: TextButton(onPressed: () => goTo('side-effects'), child: const Text('View all')),
            builder: (items) => items.isEmpty
                ? const EmptyLine('No side effects reported.', icon: Icons.healing_outlined)
                : Column(children: [
                    for (final s in items.take(3))
                      _CompactRow(
                        title: s.description,
                        subtitle: '${s.severity.label} · ${Fmt.date(s.occurredAt)}',
                        trailing: StatusPill(s.status.label, tone: s.status.tone),
                        onTap: () => context.push('/r/$_pid/side-effects/${s.id}'),
                      ),
                  ]),
          ),
          AsyncSection<List<AppointmentRecommendation>>(
            title: 'Appointments',
            value: appointments,
            onRetry: () => ref.invalidate(appointmentsProvider(_pid)),
            action: TextButton(onPressed: () => goTo('appointments'), child: const Text('View all')),
            builder: (items) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _CompactRow(
                title: detail.nextFollowUp == null ? 'No upcoming follow-up' : 'Next follow-up ${Fmt.date(detail.nextFollowUp)}',
                subtitle: 'From visits and prescriptions',
              ),
              if (items.isEmpty)
                const EmptyLine('No appointment recommendations.', icon: Icons.event_available_outlined)
              else
                for (final a in items.take(2))
                  _CompactRow(title: a.reason, subtitle: 'Dr. ${a.doctorName} · ${a.recommendedFor == null ? Fmt.date(a.createdAt) : 'for ${Fmt.date(a.recommendedFor)}'}'),
            ]),
          ),
        ]),
        const SizedBox(height: AppSpacing.section),
        SectionHeader('Longitudinal Trends', subtitle: 'Recorded values only. Nothing is estimated or filled in.', action: TextButton(onPressed: () => goTo('glucose'), child: const Text('Glucose details'))),
        TwoColumn(
          left: TrendCard(patientId: _pid, metric: 'glucose', title: 'Glucose (mg/dL)', ranges: TrendCard.clinicalRanges),
          right: TrendCard(patientId: _pid, metric: 'steps', title: 'Steps', ranges: TrendCard.clinicalRanges, bars: true),
        ),
        const SizedBox(height: AppSpacing.section),
        TwoColumn(
          left: _PersonalCard(detail: detail),
          right: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _EmergencyCard(contact: detail.profile.emergencyContact),
            const SizedBox(height: AppSpacing.lg),
            AsyncSection<List<WearableConnection>>(
              title: 'Connected Devices',
              value: devices,
              onRetry: () => ref.invalidate(adminPatientDevicesProvider(_pid)),
              builder: (items) => items.isEmpty
                  ? const EmptyLine('No devices connected.', icon: Icons.watch_outlined)
                  : Column(children: [
                      for (final dv in items)
                        _CompactRow(
                          title: dv.deviceName,
                          subtitle: dv.status == 'disconnected'
                              ? 'Disconnected'
                              : 'Last synced ${dv.lastSyncedAt == null ? 'never' : Fmt.relative(dv.lastSyncedAt)}${dv.syncFailed ? ' · sync failed' : ''}',
                          trailing: dv.isDemo ? const DemoBadge() : null,
                        ),
                    ]),
            ),
          ]),
        ),
        Text('Counts: ${detail.count('reports')} reports · ${detail.count('assessments')} assessments · ${detail.count('glucose_readings')} glucose readings · '
            '${detail.count('prescriptions')} prescriptions · ${detail.count('visits')} visits · ${detail.count('side_effects')} side effects', style: t.bodySmall),
        const Disclaimer(),
      ],
    );
  }

  TimelineEntry _timelineEntry(BuildContext context, TimelineEvent e) => _eventEntry(context, e, _pid);
}

TimelineEntry _eventEntry(BuildContext context, TimelineEvent e, String pid) {
  final route = switch (e.type) {
    'report' => '/r/$pid/reports/${e.id}',
    'assessment' => '/r/$pid/assessments/${e.id}',
    'prescription' => '/r/$pid/prescriptions/${e.id}',
    'visit' => '/r/$pid/visits/${e.id}',
    'side_effect' => '/r/$pid/side-effects/${e.id}',
    'appointment_recommendation' => adminPatientRoute(pid, tab: 'appointments'),
    'ai_summary' => adminPatientRoute(pid, tab: 'ai'),
    _ => null,
  };
  return TimelineEntry(
    title: e.title,
    subtitle: [e.subtitle, ?e.code].where((s) => s.isNotEmpty).join(' · '),
    at: e.date,
    tone: e.type == 'side_effect' ? StatusTone.attention : StatusTone.info,
    onTap: route == null ? null : () => route.startsWith('/a/patients/$pid?') ? TabbedProfile.goTo(context, route.split('tab=').last) : context.push(route),
  );
}

class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.patientId, required this.reasons});
  final String patientId;
  final List<AttentionReason> reasons;

  /// Identical reasons (e.g. three new reports) collapse into one chip with a count.
  List<List<AttentionReason>> _grouped() {
    final groups = <String, List<AttentionReason>>{};
    for (final r in reasons) {
      groups.putIfAbsent(r.reason, () => []).add(r);
    }
    return groups.values.toList();
  }

  /// A single record opens directly; several open the matching tab.
  void _open(BuildContext context, List<AttentionReason> group) {
    final r = group.first;
    switch (r.entityType) {
      case 'side_effect':
        group.length == 1 ? context.push('/r/$patientId/side-effects/${r.entityId}') : TabbedProfile.goTo(context, 'side-effects');
      case 'report':
        group.length == 1 ? context.push('/r/$patientId/reports/${r.entityId}') : TabbedProfile.goTo(context, 'reports');
      default:
        TabbedProfile.goTo(context, 'appointments');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: AppRadius.cardBorder, border: Border.all(color: const Color(0x33D9A441))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.flag_outlined, color: AppColors.warningText),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Needs attention', style: t.titleSmall?.copyWith(color: AppColors.warningText)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
              for (final group in _grouped())
                ActionChip(
                  label: Text(group.length == 1 ? group.first.reason : '${group.first.reason} (${group.length})'),
                  onPressed: () => _open(context, group),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.detail});
  final AdminPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = detail.latestAssessment;
    final pid = detail.profile.id;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lgPlus),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader(RiskWording.title, action: TextButton(onPressed: () => TabbedProfile.goTo(context, 'diabetes'), child: Text('History (${detail.count('assessments')})'))),
        if (a == null)
          const EmptyLine('No risk estimate recorded yet.', icon: Icons.insights_outlined)
        else
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(a.percentLabel, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              RiskCategoryPill(a.riskCategory),
            ]),
            Text(RiskWording.estimateLabel, style: t.bodyMedium),
            Text(a.reportAvailable ? 'Included medical report values' : 'Symptoms and risk factors only', style: t.bodySmall),
            Text('Assessed ${Fmt.date(a.assessedAt)}${a.modelVersion == null ? '' : ' · model ${a.modelVersion}'}', style: t.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => context.push('/r/$pid/diabetes-risk/${a.id}'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
              child: const Text('Open estimate'),
            ),
          ]),
      ]),
    );
  }
}

class _DoctorRow extends StatelessWidget {
  const _DoctorRow({required this.access});
  final AccessRequest access;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const IconBadge(Icons.medical_services_outlined, size: 36),
      title: Text('Dr. ${access.doctorName}'),
      subtitle: Text([access.doctorSpecialization ?? 'Specialization not recorded', if (access.respondedAt != null) 'Access since ${Fmt.date(access.respondedAt)}'].join(' · ')),
      trailing: accessPill(access.status),
      onTap: () => context.push(adminDoctorRoute(access.doctorId)),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.title, required this.subtitle, this.onTap, this.trailing});
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.controlBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(subtitle, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
          if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}

class _PersonalCard extends StatelessWidget {
  const _PersonalCard({required this.detail});
  final AdminPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final p = detail.profile;
    const none = 'Not provided';
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lgPlus),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionHeader('Personal Information'),
        KeyValueRow('Full name', p.fullName),
        KeyValueRow('Patient ID', p.patientCode),
        KeyValueRow('Date of birth', p.dateOfBirth == null ? none : Fmt.date(p.dateOfBirth)),
        KeyValueRow('Age', p.age == null ? none : '${p.age} years'),
        KeyValueRow('Gender', p.gender ?? none),
        KeyValueRow('Height / weight', [
          if (p.body.heightCm != null) '${p.body.heightCm!.toStringAsFixed(p.body.heightCm! % 1 == 0 ? 0 : 1)} cm',
          if (p.body.weightKg != null) '${p.body.weightKg!.toStringAsFixed(p.body.weightKg! % 1 == 0 ? 0 : 1)} kg',
        ].join(' · ').orIfEmpty(none)),
        KeyValueRow('BMI (calculated)', p.body.bmi?.toStringAsFixed(1) ?? none),
        KeyValueRow('Phone', p.phone ?? none),
        KeyValueRow('Email', p.email),
        const Divider(height: AppSpacing.xl),
        KeyValueRow('Account', '', valueWidget: Align(alignment: Alignment.centerLeft, child: activePill(detail.isActive))),
        KeyValueRow('Last sign-in', detail.lastLoginAt == null ? 'Never' : Fmt.dateTime(detail.lastLoginAt)),
      ]),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.contact});
  final EmergencyContact contact;

  @override
  Widget build(BuildContext context) {
    const none = 'Not provided';
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lgPlus),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionHeader('Emergency Contact'),
        if (contact.isEmpty)
          const EmptyLine('No emergency contact recorded.', icon: Icons.contact_phone_outlined)
        else ...[
          KeyValueRow('Name', contact.name ?? none),
          KeyValueRow('Relationship', contact.relationship ?? none),
          KeyValueRow('Phone', contact.phone ?? none),
        ],
      ]),
    );
  }
}

// ---------- Food ----------

class _FoodTab extends ConsumerWidget {
  const _FoodTab({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final key = (patientId: patientId, start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)), end: DateTime(now.year, now.month, now.day));
    return PageBody(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.huge),
      maxWidth: 900,
      onRefresh: () async => ref.invalidate(foodEntriesProvider(key)),
      children: [
        Text('Food logged in the last 30 days. Edited entries keep their earlier versions.', style: t.bodySmall),
        const SizedBox(height: AppSpacing.md),
        AsyncBody(
          value: ref.watch(foodEntriesProvider(key)),
          onRetry: () => ref.invalidate(foodEntriesProvider(key)),
          loading: const SkeletonList(count: 4),
          data: (items) {
            if (items.isEmpty) return const EmptyState(icon: Icons.restaurant_outlined, title: 'No food logged in the last 30 days.');
            final byDay = <DateTime, List<FoodEntry>>{};
            for (final e in items) {
              final l = e.eatenAt.toLocal();
              byDay.putIfAbsent(DateTime(l.year, l.month, l.day), () => []).add(e);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final day in byDay.keys) ...[
                Padding(padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm), child: Text(Fmt.date(day), style: t.labelLarge)),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  child: Column(children: [
                    for (final e in byDay[day]!)
                      _CompactRow(title: '${e.foodName} · ${e.quantity}', subtitle: '${e.mealType.label} · ${Fmt.time(e.eatenAt)}${e.isEdited ? ' · edited' : ''}'),
                  ]),
                ),
              ],
            ]);
          },
        ),
      ],
    );
  }
}

// ---------- Appointments ----------

class _AppointmentsTab extends ConsumerWidget {
  const _AppointmentsTab({required this.detail});
  final AdminPatientDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pid = detail.profile.id;
    final t = Theme.of(context).textTheme;
    return PageBody(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.huge),
      maxWidth: 900,
      onRefresh: () async => ref.invalidate(appointmentsProvider(pid)),
      children: [
        AppCard(
          tinted: true,
          child: Row(children: [
            const IconBadge(Icons.event_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(detail.nextFollowUp == null ? 'No upcoming follow-up recorded.' : 'Next follow-up: ${Fmt.date(detail.nextFollowUp)}', style: t.titleSmall),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AsyncSection<List<AppointmentRecommendation>>(
          title: 'Appointment Recommendations',
          value: ref.watch(appointmentsProvider(pid)),
          onRetry: () => ref.invalidate(appointmentsProvider(pid)),
          builder: (items) => items.isEmpty
              ? const EmptyLine('No appointment recommendations.', icon: Icons.event_available_outlined)
              : Column(children: [
                  for (final a in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const IconBadge(Icons.event_available_outlined, size: 36),
                      title: Text(a.reason),
                      subtitle: Text([
                        'Dr. ${a.doctorName}',
                        a.recommendedFor == null ? 'Recommended ${Fmt.date(a.createdAt)}' : 'Suggested for ${Fmt.date(a.recommendedFor)}',
                        if (a.sideEffectId != null) 'Related to a side-effect report',
                      ].join(' · ')),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      onTap: a.sideEffectId != null
                          ? () => context.push('/r/$pid/side-effects/${a.sideEffectId}')
                          : (a.doctorId == null ? null : () => context.push(adminDoctorRoute(a.doctorId!))),
                    ),
                ]),
        ),
      ],
    );
  }
}

// ---------- AI ----------

class _AiTab extends ConsumerWidget {
  const _AiTab({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return PageBody(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.huge),
      maxWidth: 900,
      onRefresh: () async => ref.invalidate(adminPatientAiSummariesProvider(patientId)),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(color: AppColors.primaryFaint, borderRadius: AppRadius.cardBorder, border: Border.all(color: AppColors.primaryBorder)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AiLabel(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'AI summaries are generated from available records. They are not a doctor\'s clinical conclusion and do not replace medical advice. '
                'Every generation is kept; nothing here is regenerated when you view it.',
                style: t.bodySmall?.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: ref.watch(adminPatientAiSummariesProvider(patientId)),
          onRetry: () => ref.invalidate(adminPatientAiSummariesProvider(patientId)),
          loading: const SkeletonList(count: 3),
          data: (items) => items.isEmpty
              ? const EmptyState(icon: Icons.auto_awesome_outlined, title: 'No AI summaries generated yet.')
              : Column(children: [
                  for (final s in items) ...[
                    _SummaryCard(summary: s),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ]),
        ),
      ],
    );
  }
}

class _SummaryCard extends ConsumerStatefulWidget {
  const _SummaryCard({required this.summary});
  final AISummary summary;

  @override
  ConsumerState<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends ConsumerState<_SummaryCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = widget.summary;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(
          leading: const IconBadge(Icons.auto_awesome_outlined, size: 36),
          title: Text(s.kind.label),
          subtitle: Text('Generated ${Fmt.dateTime(s.generatedAt)}${s.generatedByRole == null ? '' : ' by ${s.generatedByRole}'}${s.isStale ? ' · newer records exist' : ''}'),
          trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              AiSummaryContent(s),
              const SizedBox(height: AppSpacing.md),
              if (s.basedOn.isNotEmpty) Text('Based on: ${s.basedOn.join(', ')}', style: t.bodySmall),
              Text('AI model: ${s.model}', style: t.bodySmall),
              if (s.disclaimer.isNotEmpty) ...[const SizedBox(height: AppSpacing.sm), Text(s.disclaimer, style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic))],
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await ref.read(pdfServiceProvider).view(s);
                    } catch (e) {
                      if (context.mounted) showFailure(context, e);
                    }
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await ref.read(pdfServiceProvider).download(s);
                    } catch (e) {
                      if (context.mounted) showFailure(context, e);
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Download PDF'),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }
}

// ---------- Doctors ----------

class _DoctorsTab extends StatelessWidget {
  const _DoctorsTab({required this.detail});
  final AdminPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PageBody(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.huge),
      children: [
        Text('Every doctor relationship, including past ones. Doctors see records only while access is approved by the patient.', style: t.bodySmall),
        const SizedBox(height: AppSpacing.md),
        if (detail.doctors.isEmpty)
          const EmptyState(icon: Icons.medical_services_outlined, title: 'No doctor has requested access yet.')
        else
          ResponsiveTable<AccessRequest>(
            rows: detail.doctors,
            onRowTap: (a) => context.push(adminDoctorRoute(a.doctorId)),
            columns: [
              TableColumnSpec('Doctor', (a) => CellText('Dr. ${a.doctorName}', secondary: a.doctorCode, bold: true), flex: 3),
              TableColumnSpec('Specialization', (a) => CellText(a.doctorSpecialization ?? '—'), flex: 3),
              TableColumnSpec('Access', (a) => PillCell(accessPill(a.status)), flex: 2),
              TableColumnSpec('Requested', (a) => CellText(Fmt.date(a.requestedAt)), flex: 2, tabletVisible: false),
              TableColumnSpec(
                'Granted / ended',
                (a) => CellText(a.revokedAt != null ? 'Ended ${Fmt.date(a.revokedAt)}' : (a.respondedAt == null ? '—' : Fmt.date(a.respondedAt))),
                flex: 2,
              ),
            ],
            mobileCard: (a) => AppCard(
              onTap: () => context.push(adminDoctorRoute(a.doctorId)),
              child: Row(children: [
                Expanded(child: CellText('Dr. ${a.doctorName}', secondary: '${a.doctorSpecialization ?? 'Specialization not recorded'} · requested ${Fmt.date(a.requestedAt)}', bold: true)),
                accessPill(a.status),
              ]),
            ),
          ),
      ],
    );
  }
}

// ---------- Activity / audit ----------

class _ActivityTab extends ConsumerStatefulWidget {
  const _ActivityTab({required this.patientId});
  final String patientId;

  @override
  ConsumerState<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<_ActivityTab> {
  String _type = 'all';

  @override
  Widget build(BuildContext context) {
    final key = (patientId: widget.patientId, type: _type);
    return PageBody(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.huge),
      maxWidth: 900,
      onRefresh: () async => ref.invalidate(timelineProvider(key)),
      children: [
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          for (final f in timelineFilters.entries) ChoiceChip(label: Text(f.value), selected: _type == f.key, onSelected: (_) => setState(() => _type = f.key)),
        ]),
        const SizedBox(height: AppSpacing.lg),
        AsyncSection<({List<TimelineEvent> items, bool hasMore})>(
          title: 'Longitudinal History',
          subtitle: 'Each record keeps its own medical date. Open an entry to see the record.',
          value: ref.watch(timelineProvider(key)),
          onRetry: () => ref.invalidate(timelineProvider(key)),
          loadingLines: 6,
          builder: (r) => ActivityTimeline(emptyMessage: 'Nothing recorded in this category.', entries: [for (final e in r.items) _eventEntry(context, e, widget.patientId)]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AsyncSection(
          title: 'Notifications Sent to the Patient',
          value: ref.watch(adminPatientNotificationsProvider(widget.patientId)),
          onRetry: () => ref.invalidate(adminPatientNotificationsProvider(widget.patientId)),
          builder: (items) => items.isEmpty
              ? const EmptyLine('No notifications sent.', icon: Icons.notifications_none_outlined)
              : Column(children: [
                  for (final n in items.take(20))
                    _CompactRow(title: n.title, subtitle: '${Fmt.dateTime(n.createdAt)} · ${n.isRead ? 'Read' : 'Unread'}'),
                ]),
        ),
      ],
    );
  }
}

class _AuditTab extends ConsumerWidget {
  const _AuditTab({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageBody(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.huge),
      onRefresh: () async => ref.invalidate(adminPatientAuditProvider(patientId)),
      children: [
        AsyncBody(
          value: ref.watch(adminPatientAuditProvider(patientId)),
          onRetry: () => ref.invalidate(adminPatientAuditProvider(patientId)),
          loading: const SkeletonList(count: 5),
          data: (r) => r.items.isEmpty ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No audit entries.') : AuditTable(entries: r.items, total: r.total),
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Skeleton(height: 20, width: 150),
            SizedBox(height: AppSpacing.xl),
            Row(children: [
              Skeleton(height: 72, width: 72, radius: 36),
              SizedBox(width: AppSpacing.lg),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Skeleton(height: 24, width: 220), SizedBox(height: AppSpacing.sm), Skeleton(height: 16, width: 160)])),
            ]),
            SizedBox(height: AppSpacing.xxl),
            Skeleton(height: 40),
            SizedBox(height: AppSpacing.xl),
            Row(children: [Expanded(child: Skeleton(height: 110, radius: 16)), SizedBox(width: AppSpacing.md), Expanded(child: Skeleton(height: 110, radius: 16))]),
            SizedBox(height: AppSpacing.lg),
            SkeletonList(count: 2),
          ]),
        ),
      ),
    );
  }
}

// ---------- Edit ----------

/// Separate from viewing: corrects administrative details only. Date of birth and gender are the
/// patient's own inputs to the diabetes model and are not editable here.
class AdminPatientEditScreen extends ConsumerStatefulWidget {
  const AdminPatientEditScreen({super.key, required this.patientId});
  final String patientId;

  @override
  ConsumerState<AdminPatientEditScreen> createState() => _AdminPatientEditScreenState();
}

class _AdminPatientEditScreenState extends ConsumerState<AdminPatientEditScreen> {
  final _form = GlobalKey<FormState>();
  TextEditingController? _name, _phone, _eName, _eRelationship, _ePhone;

  @override
  void dispose() {
    for (final c in [_name, _phone, _eName, _eRelationship, _ePhone]) {
      c?.dispose();
    }
    super.dispose();
  }

  void _init(PatientProfile p) {
    if (_name != null) return;
    _name = TextEditingController(text: p.fullName);
    _phone = TextEditingController(text: p.phone);
    _eName = TextEditingController(text: p.emergencyContact.name);
    _eRelationship = TextEditingController(text: p.emergencyContact.relationship);
    _ePhone = TextEditingController(text: p.emergencyContact.phone);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    String? v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    try {
      await ref.read(adminRepositoryProvider).updatePatient(widget.patientId, {
        'full_name': _name!.text.trim(),
        'phone': v(_phone!),
        'emergency_name': v(_eName!),
        'emergency_relationship': v(_eRelationship!),
        'emergency_phone': v(_ePhone!),
      });
      ref.invalidate(adminPatientProvider(widget.patientId));
      ref.invalidate(patientProfileProvider(widget.patientId));
      ref.invalidate(adminPatientsProvider);
      if (!mounted) return;
      showToast(context, 'Patient details updated');
      context.pop();
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'Edit Patient',
      body: PageBody(maxWidth: 600, children: [
        AsyncBody(
          value: ref.watch(patientProfileProvider(widget.patientId)),
          onRetry: () => ref.invalidate(patientProfileProvider(widget.patientId)),
          data: (p) {
            _init(p);
            return Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AppCard(
                  child: Row(children: [
                    Expanded(child: CellText(p.patientCode, secondary: p.email, bold: true)),
                    Text([if (p.age != null) '${p.age} yrs', ?p.gender].join(' · '), style: t.bodySmall),
                  ]),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(label: 'Full name', controller: _name, validator: (v) => Validators.required(v, 'Full name'), textCapitalization: TextCapitalization.words),
                AppTextField(label: 'Phone', controller: _phone, optional: true, keyboardType: TextInputType.phone, validator: Validators.optionalPhone),
                const SizedBox(height: AppSpacing.sm),
                Text('Emergency contact', style: t.titleSmall),
                const SizedBox(height: AppSpacing.md),
                AppTextField(label: 'Name', controller: _eName, optional: true, textCapitalization: TextCapitalization.words),
                AppTextField(label: 'Relationship', controller: _eRelationship, optional: true, textCapitalization: TextCapitalization.words),
                AppTextField(label: 'Phone', controller: _ePhone, optional: true, keyboardType: TextInputType.phone, validator: Validators.optionalPhone),
                BusyButton(label: 'Save changes', onPressed: _save, expand: true),
                const SizedBox(height: AppSpacing.md),
                Text('Date of birth and gender are provided by the patient and used by the diabetes model, so they are not editable here. '
                    'Medical records cannot be changed from this screen. Changes are recorded in the audit log.', style: t.bodySmall),
              ]),
            );
          },
        ),
      ]),
    );
  }
}


extension on String {
  String orIfEmpty(String fallback) => isEmpty ? fallback : this;
}
