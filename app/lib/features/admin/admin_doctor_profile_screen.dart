import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/activity_timeline.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/labels.dart';
import '../../core/widgets/profile_widgets.dart';
import '../../core/widgets/responsive_table.dart';
import '../../data/models/admin.dart';
import '../../core/widgets/charts.dart';
import '../../data/models/patient.dart';
import '../../data/providers.dart';
import 'admin_common.dart';
import 'admin_screens.dart';

/// Admin's read-only view of a doctor's complete record and current workload.
/// Editing is a separate action ([Edit Doctor]) that opens the form.
class AdminDoctorProfileScreen extends ConsumerWidget {
  const AdminDoctorProfileScreen({super.key, required this.doctorId, this.initialTab});
  final String doctorId;
  final String? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminDoctorProvider(doctorId));
    void back() => context.canPop() ? context.pop() : context.go('/a/doctors');

    return value.when(
      skipLoadingOnRefresh: true,
      loading: () => const _ProfileSkeleton(),
      error: (e, _) => AppPage(
        title: 'Doctor',
        body: Column(children: [
          ErrorState(error: e, title: e is NotFoundFailure ? null : 'Unable to load profile.', onRetry: () => ref.invalidate(adminDoctorProvider(doctorId))),
          TextButton.icon(onPressed: back, icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Back to Doctors')),
        ]),
      ),
      data: (d) {
        final p = d.profile;
        return TabbedProfile(
          initialTab: initialTab,
          header: ProfileHeader(
            name: 'Dr. ${p.fullName}',
            backLabel: 'Back to Doctors',
            onBack: back,
            breadcrumbs: ['Admin', 'Doctors', 'Dr. ${p.fullName}'],
            idLabel: 'Doctor ID: ${p.doctorCode}',
            details: [p.specialization ?? 'Specialization not recorded', if (d.lastActivityAt != null) 'Last active ${Fmt.relative(d.lastActivityAt)}'],
            status: activePill(p.isActive),
            badges: [if (p.isDemo) const DemoBadge()],
            actions: [
              FilledButton.icon(onPressed: () => context.push('/a/doctors/${p.id}/edit'), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit Doctor')),
              _DoctorMoreMenu(detail: d),
            ],
          ),
          tabs: [
            ProfileTab('overview', 'Overview', _OverviewTab(detail: d)),
            ProfileTab('patients', 'Patients', _PatientsTab(doctorId: doctorId)),
            ProfileTab('reports', 'Reports', _ReportsTab(doctorId: doctorId)),
            ProfileTab('prescriptions', 'Prescriptions', _PrescriptionsTab(doctorId: doctorId)),
            ProfileTab('appointments', 'Appointments', _AppointmentsTab(doctorId: doctorId)),
            ProfileTab('side-effects', 'Side Effects', _SideEffectsTab(doctorId: doctorId)),
            ProfileTab('activity', 'Activity', _ActivityTab(doctorId: doctorId)),
            ProfileTab('profile', 'Profile', _ProfileTab(detail: d)),
            ProfileTab('audit', 'Audit', _AuditTab(doctorId: doctorId)),
          ],
        );
      },
    );
  }
}

class _DoctorMoreMenu extends ConsumerWidget {
  const _DoctorMoreMenu({required this.detail});
  final AdminDoctorDetail detail;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final p = detail.profile;
    if (p.isActive) {
      final ok = await confirmAction(
        context,
        title: 'Deactivate Dr. ${p.fullName}?',
        message: 'They will be signed out and cannot sign in. Their past records remain in patient histories.',
        confirmLabel: 'Deactivate',
        destructive: true,
      );
      if (!ok) return;
    }
    try {
      await ref.read(adminRepositoryProvider).updateDoctor(p.id, {'is_active': !p.isActive});
      ref.invalidate(adminDoctorProvider(p.id));
      ref.invalidate(adminDoctorsProvider);
      if (context.mounted) showToast(context, p.isActive ? 'Doctor deactivated' : 'Doctor reactivated');
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'More actions',
      onSelected: (a) => switch (a) {
        'patients' => TabbedProfile.goTo(context, 'patients'),
        'activity' => TabbedProfile.goTo(context, 'activity'),
        'audit' => TabbedProfile.goTo(context, 'audit'),
        _ => _toggle(context, ref),
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'patients', child: Text('View patients')),
        const PopupMenuItem(value: 'activity', child: Text('View activity')),
        const PopupMenuItem(value: 'audit', child: Text('View audit log')),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'toggle', child: Text(detail.profile.isActive ? 'Deactivate doctor' : 'Reactivate doctor', style: TextStyle(color: detail.profile.isActive ? AppColors.errorText : null))),
      ],
      child: const _MoreButton(),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.buttonBorder, border: Border.all(color: AppColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('More', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.primary)),
        const SizedBox(width: AppSpacing.xs),
        const Icon(Icons.expand_more, size: 18, color: AppColors.primary),
      ]),
    );
  }
}

// ---------- Overview ----------

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.detail});
  final AdminDoctorDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = detail.profile.id;
    final patients = ref.watch(adminDoctorPatientsProvider(id));
    final activity = ref.watch(adminDoctorActivityProvider((id: id, scope: 'actions')));
    void goTo(String tab) => TabbedProfile.goTo(context, tab);
    final s = detail.stat;

    return _TabBody(
      onRefresh: () async {
        ref.invalidate(adminDoctorProvider(id));
        ref.invalidate(adminDoctorPatientsProvider(id));
        ref.invalidate(adminDoctorActivityProvider);
      },
      children: [
        ResponsiveGrid(minItemWidth: 180, maxColumns: 5, children: [
          StatBlock(icon: Icons.people_outline, label: 'Active patients', value: '${s('active_patients')}', caption: '${s('total_patients')} total · ${s('pending_requests')} pending', onTap: () => goTo('patients')),
          StatBlock(icon: Icons.description_outlined, label: 'Reports', value: '${s('reports_uploaded_this_month')}', caption: 'this month · ${s('reports_uploaded')} total', onTap: () => goTo('reports')),
          StatBlock(icon: Icons.medication_outlined, label: 'Prescriptions', value: '${s('prescriptions_this_month')}', caption: 'this month · ${s('prescriptions')} total', onTap: () => goTo('prescriptions')),
          StatBlock(icon: Icons.event_outlined, label: 'Upcoming', value: '${s('upcoming_appointments') + s('upcoming_follow_ups')}', caption: '${s('upcoming_follow_ups')} follow-ups · ${s('upcoming_appointments')} appts', onTap: () => goTo('appointments')),
          StatBlock(icon: Icons.healing_outlined, label: 'Side effects', value: '${s('side_effects_pending')}', caption: 'pending · ${s('side_effects_resolved')} resolved', onTap: () => goTo('side-effects')),
        ]),
        const SizedBox(height: AppSpacing.lg),
        TwoColumn(
          leftFlex: 3,
          rightFlex: 2,
          left: AsyncSection<List<DoctorPatientLink>>(
            title: 'Active Patients',
            value: patients,
            onRetry: () => ref.invalidate(adminDoctorPatientsProvider(id)),
            action: TextButton(onPressed: () => goTo('patients'), child: const Text('View all')),
            builder: (links) {
              final active = [for (final l in links) if (l.access.status == AccessStatus.approved) l];
              if (active.isEmpty) return const EmptyLine('No active patients.', icon: Icons.people_outline);
              return Column(children: [
                for (var i = 0; i < active.length && i < 6; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _PatientProgressRow(snapshot: active[i].snapshot),
                ],
              ]);
            },
          ),
          right: AsyncSection<({List<LinkedAuditEntry> items, int total})>(
            title: 'Recent Activity',
            value: activity,
            onRetry: () => ref.invalidate(adminDoctorActivityProvider),
            action: TextButton(onPressed: () => goTo('activity'), child: const Text('View all')),
            builder: (r) => ActivityTimeline(
              emptyMessage: 'No recorded activity yet.',
              entries: [for (final e in r.items.take(8)) auditTimelineEntry(e, showActor: false, open: (route) => context.push(route))],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TwoColumn(
          leftFlex: 3,
          rightFlex: 2,
          left: _ProgressCard(progress: detail.progress),
          right: AsyncSection<List<DoctorPatientLink>>(
            title: 'Patient Access',
            subtitle: 'Relationships approved or pending through patient authorization',
            value: patients,
            onRetry: () => ref.invalidate(adminDoctorPatientsProvider(id)),
            builder: (links) => links.isEmpty
                ? const EmptyLine('No access requests yet.', icon: Icons.verified_user_outlined)
                : Column(children: [
                    for (final l in links.take(8))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.snapshot.ref.name),
                        subtitle: Text('${l.snapshot.ref.patientCode} · requested ${Fmt.date(l.access.requestedAt)}'),
                        trailing: accessPill(l.access.status),
                        onTap: () => context.push(adminPatientRoute(l.snapshot.ref.id)),
                      ),
                  ]),
          ),
        ),
        const Disclaimer(text: 'Figures are counted from recorded data. SUSTHITI does not calculate a health score.'),
      ],
    );
  }
}

/// One patient's current state as factual signals: model classification, latest glucose and its
/// direction, last activity, and anything needing attention.
class _PatientProgressRow extends StatelessWidget {
  const _PatientProgressRow({required this.snapshot});
  final PatientSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = snapshot;
    return InkWell(
      onTap: () => context.push(adminPatientRoute(s.ref.id)),
      borderRadius: AppRadius.controlBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.ref.name, style: t.titleSmall, overflow: TextOverflow.ellipsis),
              Text(s.ref.patientCode, style: t.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                diabetesStatusPill(s.latestAssessment?.riskCategory),
                if (s.latestGlucose != null) _Fact(icon: trendIcon(s.glucoseTrend), text: '${s.latestGlucose!.round()} mg/dL'),
                _Fact(icon: Icons.schedule, text: s.lastActivityAt == null ? 'No activity' : Fmt.relative(s.lastActivityAt)),
              ]),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          progressPill(s),
        ]),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(text, style: Theme.of(context).textTheme.labelMedium),
    ]);
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});
  final ProgressSummary progress;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = progress['patients'];
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lgPlus),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Patient Progress', style: t.titleMedium),
        Text('Across $total active patient${total == 1 ? '' : 's'}', style: t.bodySmall),
        const SizedBox(height: AppSpacing.lg),
        if (total == 0)
          const EmptyLine('No active patients.', icon: Icons.people_outline)
        else ...[
          Text('Latest diabetes model classification', style: t.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          DistributionBar(segments: [
            (label: 'Pattern detected', value: progress['elevated_risk_pattern'], color: AppColors.warning),
            (label: 'No pattern detected', value: progress['lower_risk_pattern'], color: AppColors.success),
            (label: 'Not assessed', value: progress['not_assessed'], color: AppColors.textMuted),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Text('Glucose, last 7 days vs previous weeks', style: t.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          DistributionBar(segments: [
            (label: 'Higher', value: progress['glucose_higher'], color: AppColors.warning),
            (label: 'Similar', value: progress['glucose_stable'], color: AppColors.secondary),
            (label: 'Lower', value: progress['glucose_lower'], color: AppColors.primary),
            (label: 'Too few readings', value: total - progress['glucose_higher'] - progress['glucose_stable'] - progress['glucose_lower'], color: AppColors.border),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            StatusPill('${progress['needs_attention']} need attention', tone: progress['needs_attention'] > 0 ? StatusTone.attention : StatusTone.inactive),
            StatusPill('${progress['open_side_effects']} with open side effects', tone: progress['open_side_effects'] > 0 ? StatusTone.attention : StatusTone.inactive),
            StatusPill('${progress['assessed_last_30d']} assessed in 30 days', tone: StatusTone.info),
            StatusPill('${progress['no_activity_30d']} inactive for 30 days', tone: StatusTone.inactive),
          ]),
        ],
      ]),
    );
  }
}

// ---------- Patients ----------

class _PatientsTab extends ConsumerStatefulWidget {
  const _PatientsTab({required this.doctorId});
  final String doctorId;

  @override
  ConsumerState<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends ConsumerState<_PatientsTab> {
  AccessStatus? _status = AccessStatus.approved;

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminDoctorPatientsProvider(widget.doctorId));
    final t = Theme.of(context).textTheme;
    return _TabBody(
      onRefresh: () async => ref.invalidate(adminDoctorPatientsProvider(widget.doctorId)),
      children: [
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          for (final s in <AccessStatus?>[AccessStatus.approved, AccessStatus.pending, AccessStatus.revoked, AccessStatus.rejected, null])
            ChoiceChip(label: Text(s == null ? 'All' : (s == AccessStatus.approved ? 'Active' : s.label)), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
        ]),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: value,
          onRetry: () => ref.invalidate(adminDoctorPatientsProvider(widget.doctorId)),
          loading: const SkeletonList(count: 4),
          data: (links) {
            final rows = [for (final l in links) if (_status == null || l.access.status == _status) l];
            if (rows.isEmpty) {
              return EmptyState(icon: Icons.people_outline, title: _status == AccessStatus.approved ? 'No active patients.' : 'No patients in this group.');
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${rows.length} patient${rows.length == 1 ? '' : 's'}', style: t.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              ResponsiveTable<DoctorPatientLink>(
                rows: rows,
                onRowTap: (l) => context.push(adminPatientRoute(l.snapshot.ref.id)),
                columns: [
                  TableColumnSpec('Patient', (l) => CellText(l.snapshot.ref.name, secondary: l.snapshot.ref.patientCode, bold: true), flex: 3),
                  TableColumnSpec('Diabetes status', (l) => PillCell(diabetesStatusPill(l.snapshot.latestAssessment?.riskCategory)), flex: 3),
                  TableColumnSpec(
                    'Latest glucose',
                    (l) => CellText(l.snapshot.latestGlucose == null ? '—' : '${l.snapshot.latestGlucose!.round()} mg/dL', secondary: l.snapshot.latestGlucose == null ? null : trendLabel(l.snapshot.glucoseTrend)),
                    flex: 3,
                    tabletVisible: false,
                  ),
                  TableColumnSpec('Last activity', (l) => CellText(l.snapshot.lastActivityAt == null ? '—' : Fmt.relative(l.snapshot.lastActivityAt)), flex: 2),
                  TableColumnSpec('Progress', (l) => PillCell(progressPill(l.snapshot)), flex: 2, tabletVisible: false),
                  TableColumnSpec('Access', (l) => PillCell(accessPill(l.access.status)), flex: 2),
                ],
                mobileCard: (l) => AppCard(
                  onTap: () => context.push(adminPatientRoute(l.snapshot.ref.id)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: CellText(l.snapshot.ref.name, secondary: l.snapshot.ref.patientCode, bold: true)),
                      accessPill(l.access.status),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                      diabetesStatusPill(l.snapshot.latestAssessment?.riskCategory),
                      if (l.access.status == AccessStatus.approved) progressPill(l.snapshot),
                    ]),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        if (l.snapshot.latestGlucose != null) 'Glucose ${l.snapshot.latestGlucose!.round()} mg/dL',
                        'Last activity ${l.snapshot.lastActivityAt == null ? '—' : Fmt.relative(l.snapshot.lastActivityAt)}',
                      ].join(' · '),
                      style: t.bodySmall,
                    ),
                  ]),
                ),
              ),
            ]);
          },
        ),
      ],
    );
  }
}

// ---------- Reports ----------

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab({required this.doctorId});
  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminDoctorReportsProvider(doctorId));
    void retry() => ref.invalidate(adminDoctorReportsProvider(doctorId));
    Widget reportRow(ReportWithPatient r, {bool opened = false}) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const IconBadge(Icons.description_outlined, size: 36),
          title: Text(r.report.title),
          subtitle: Text([
            if (r.patient != null) 'Patient: ${r.patient!.name}',
            'Report date ${Fmt.date(r.report.reportDate)}',
            opened ? 'Opened ${Fmt.relative(r.openedAt)}' : 'Uploaded ${Fmt.date(r.report.uploadedAt)}',
          ].join(' · ')),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          onTap: () => context.push('/r/${r.report.patientId}/reports/${r.report.id}'),
        );
    return _TabBody(
      onRefresh: () async => retry(),
      children: [
        AsyncSection<DoctorReportActivity>(
          title: 'Reports Uploaded',
          value: value,
          onRetry: retry,
          builder: (d) => d.uploaded.isEmpty ? const EmptyLine('No reports uploaded by this doctor.') : Column(children: [for (final r in d.uploaded) reportRow(r)]),
        ),
        const SizedBox(height: AppSpacing.lg),
        TwoColumn(
          left: AsyncSection<DoctorReportActivity>(
            title: 'Reports Opened',
            subtitle: 'Original files the doctor viewed or downloaded',
            value: value,
            onRetry: retry,
            builder: (d) => d.opened.isEmpty ? const EmptyLine('No recent report activity.') : Column(children: [for (final r in d.opened) reportRow(r, opened: true)]),
          ),
          right: AsyncSection<DoctorReportActivity>(
            title: 'AI Report Summaries Generated',
            value: value,
            onRetry: retry,
            builder: (d) => d.summaries.isEmpty
                ? const EmptyLine('No report summaries generated.', icon: Icons.auto_awesome_outlined)
                : Column(children: [
                    for (final s in d.summaries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const IconBadge(Icons.auto_awesome_outlined, size: 36),
                        title: Text(s.kind == 'all_reports' ? 'All-reports summary' : 'Report summary'),
                        subtitle: Text([if (s.patient != null) 'Patient: ${s.patient!.name}', Fmt.dateTime(s.generatedAt)].join(' · ')),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        onTap: s.patient == null
                            ? null
                            : () => context.push(s.kind == 'individual_report' && s.subjectId != null ? '/r/${s.patient!.id}/reports/${s.subjectId}' : '/r/${s.patient!.id}/reports-summary'),
                      ),
                  ]),
          ),
        ),
      ],
    );
  }
}

// ---------- Prescriptions ----------

class _PrescriptionsTab extends ConsumerWidget {
  const _PrescriptionsTab({required this.doctorId});
  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminDoctorPrescriptionsProvider(doctorId));
    final t = Theme.of(context).textTheme;
    void open(PrescriptionWithPatient p) => context.push('/r/${p.prescription.patientId ?? p.patient?.id}/prescriptions/${p.prescription.id}');
    return _TabBody(
      onRefresh: () async => ref.invalidate(adminDoctorPrescriptionsProvider(doctorId)),
      children: [
        Text('Prescriptions are historical records. Viewing them never changes them.', style: t.bodySmall),
        const SizedBox(height: AppSpacing.md),
        AsyncBody(
          value: value,
          onRetry: () => ref.invalidate(adminDoctorPrescriptionsProvider(doctorId)),
          loading: const SkeletonList(count: 4),
          data: (r) => r.items.isEmpty
              ? const EmptyState(icon: Icons.medication_outlined, title: 'No prescriptions recorded.')
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('${r.total} prescription${r.total == 1 ? '' : 's'}', style: t.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ResponsiveTable<PrescriptionWithPatient>(
                    rows: r.items,
                    onRowTap: open,
                    columns: [
                      TableColumnSpec('Prescription', (p) => CellText(p.prescription.code, bold: true), flex: 2),
                      TableColumnSpec('Patient', (p) => CellText(p.patient?.name ?? '—', secondary: p.patient?.patientCode), flex: 3),
                      TableColumnSpec('Date', (p) => CellText(Fmt.date(p.prescription.prescribedOn)), flex: 2),
                      TableColumnSpec('Medicines', (p) => CellText('${p.prescription.medicines.length}', secondary: p.prescription.medicines.map((m) => m.medicine).join(', ')), flex: 3, tabletVisible: false),
                      TableColumnSpec('Follow-up', (p) => CellText(p.prescription.followUpDate == null ? '—' : Fmt.date(p.prescription.followUpDate)), flex: 2),
                    ],
                    mobileCard: (p) => AppCard(
                      onTap: () => open(p),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Expanded(child: Text(p.prescription.code, style: t.titleSmall)), Text(Fmt.date(p.prescription.prescribedOn), style: t.bodySmall)]),
                        Text('Patient: ${p.patient?.name ?? '—'}', style: t.bodyMedium),
                        Text('${p.prescription.medicines.length} medicine${p.prescription.medicines.length == 1 ? '' : 's'}${p.prescription.followUpDate == null ? '' : ' · Follow-up ${Fmt.date(p.prescription.followUpDate)}'}', style: t.bodySmall),
                      ]),
                    ),
                  ),
                ]),
        ),
      ],
    );
  }
}

// ---------- Appointments ----------

class _AppointmentsTab extends ConsumerWidget {
  const _AppointmentsTab({required this.doctorId});
  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminDoctorAppointmentsProvider(doctorId));
    void retry() => ref.invalidate(adminDoctorAppointmentsProvider(doctorId));
    return _TabBody(
      onRefresh: () async => retry(),
      children: [
        TwoColumn(
          left: AsyncSection<DoctorAppointments>(
            title: 'Upcoming Follow-ups',
            subtitle: 'Follow-up dates from this doctor\'s visits and prescriptions',
            value: value,
            onRetry: retry,
            builder: (d) => d.followUps.isEmpty
                ? const EmptyLine('No upcoming follow-ups.', icon: Icons.event_outlined)
                : Column(children: [
                    for (final f in d.followUps)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _DateBadge(f.date),
                        title: Text(f.patient?.name ?? 'Patient'),
                        subtitle: Text('${f.source == 'visit' ? 'Visit follow-up' : 'Prescription follow-up'} · ${f.code}${f.reason == null ? '' : ' · ${f.reason}'}'),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        onTap: f.patient == null ? null : () => context.push('/r/${f.patient!.id}/${f.source == 'visit' ? 'visits' : 'prescriptions'}/${f.recordId}'),
                      ),
                  ]),
          ),
          right: AsyncSection<DoctorAppointments>(
            title: 'Appointment Recommendations',
            value: value,
            onRetry: retry,
            builder: (d) => d.recommendations.isEmpty
                ? const EmptyLine('No appointment recommendations.', icon: Icons.event_available_outlined)
                : Column(children: [
                    for (final a in d.recommendations)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const IconBadge(Icons.event_available_outlined, size: 36),
                        title: Text(a.patient?.name ?? 'Patient'),
                        subtitle: Text('${a.appointment.reason}\n${a.appointment.recommendedFor == null ? 'Recommended ${Fmt.date(a.appointment.createdAt)}' : 'Suggested for ${Fmt.date(a.appointment.recommendedFor)}'}'),
                        isThreeLine: true,
                        onTap: a.patient == null ? null : () => context.push(adminPatientRoute(a.patient!.id, tab: 'appointments')),
                      ),
                  ]),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AsyncSection<DoctorAppointments>(
          title: 'Recent Visits',
          value: value,
          onRetry: retry,
          builder: (d) => d.visits.isEmpty
              ? const EmptyLine('No visits recorded.', icon: Icons.event_note_outlined)
              : Column(children: [
                  for (final v in d.visits)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const IconBadge(Icons.event_note_outlined, size: 36),
                      title: Text('${v.patient?.name ?? 'Patient'} · ${v.reason}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${v.code} · ${Fmt.date(v.visitDate)}${v.followUpDate == null ? '' : ' · Follow-up ${Fmt.date(v.followUpDate)}'}'),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      onTap: v.patient == null ? null : () => context.push('/r/${v.patient!.id}/visits/${v.id}'),
                    ),
                ]),
        ),
      ],
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge(this.date);
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final parts = Fmt.shortDate(date).split(' ');
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(parts.first, style: t.titleSmall?.copyWith(color: AppColors.primaryDeep, height: 1.1)),
        if (parts.length > 1) Text(parts[1], style: t.labelSmall?.copyWith(color: AppColors.primaryDeep)),
      ]),
    );
  }
}

// ---------- Side effects ----------

class _SideEffectsTab extends ConsumerWidget {
  const _SideEffectsTab({required this.doctorId});
  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminDoctorSideEffectsProvider(doctorId));
    final t = Theme.of(context).textTheme;
    return _TabBody(
      onRefresh: () async => ref.invalidate(adminDoctorSideEffectsProvider(doctorId)),
      children: [
        AsyncBody(
          value: value,
          onRetry: () => ref.invalidate(adminDoctorSideEffectsProvider(doctorId)),
          loading: const SkeletonList(count: 4),
          data: (d) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ResponsiveGrid(minItemWidth: 180, maxColumns: 3, children: [
              StatBlock(icon: Icons.hourglass_empty, label: 'Pending review', value: '${d.pending}'),
              StatBlock(icon: Icons.task_alt, label: 'Resolved', value: '${d.resolved}'),
              StatBlock(icon: Icons.forum_outlined, label: 'Responded by this doctor', value: '${d.items.where((i) => i.doctorResponse != null).length}'),
            ]),
            const SizedBox(height: AppSpacing.lg),
            if (d.items.isEmpty)
              const EmptyState(icon: Icons.healing_outlined, title: 'No side-effect reports.')
            else
              ResponsiveTable<SideEffectWithPatient>(
                rows: d.items,
                onRowTap: (s) => context.push('/r/${s.sideEffect.patientId}/side-effects/${s.sideEffect.id}'),
                columns: [
                  TableColumnSpec('Patient', (s) => CellText(s.patient?.name ?? '—', secondary: s.sideEffect.code, bold: true), flex: 3),
                  TableColumnSpec('Side effect', (s) => CellText(s.sideEffect.description), flex: 4, tabletVisible: false),
                  TableColumnSpec('Severity', (s) => PillCell(StatusPill(s.sideEffect.severity.label, tone: s.sideEffect.severity.tone)), flex: 2),
                  TableColumnSpec('Status', (s) => PillCell(StatusPill(s.sideEffect.status.label, tone: s.sideEffect.status.tone)), flex: 3),
                  TableColumnSpec('Reported', (s) => CellText(Fmt.date(s.sideEffect.occurredAt)), flex: 2),
                  TableColumnSpec('Doctor response', (s) => CellText(s.doctorResponse?.label ?? 'None yet', secondary: s.doctorRespondedAt == null ? null : Fmt.relative(s.doctorRespondedAt)), flex: 3, tabletVisible: false),
                ],
                mobileCard: (s) => AppCard(
                  onTap: () => context.push('/r/${s.sideEffect.patientId}/side-effects/${s.sideEffect.id}'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(s.patient?.name ?? 'Patient', style: t.titleSmall)), StatusPill(s.sideEffect.status.label, tone: s.sideEffect.status.tone)]),
                    const SizedBox(height: AppSpacing.xs),
                    Text(s.sideEffect.description, style: t.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xs),
                    Text('${s.sideEffect.severity.label} · ${Fmt.date(s.sideEffect.occurredAt)} · ${s.doctorResponse?.label ?? 'No response yet'}', style: t.bodySmall),
                  ]),
                ),
              ),
          ]),
        ),
      ],
    );
  }
}

// ---------- Activity / audit ----------

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab({required this.doctorId});
  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (id: doctorId, scope: 'actions');
    return _TabBody(
      onRefresh: () async => ref.invalidate(adminDoctorActivityProvider(key)),
      children: [
        AsyncSection<({List<LinkedAuditEntry> items, int total})>(
          title: 'Recent Activity',
          subtitle: 'What this doctor has done in SUSTHITI. Open an entry to see the record.',
          value: ref.watch(adminDoctorActivityProvider(key)),
          onRetry: () => ref.invalidate(adminDoctorActivityProvider(key)),
          loadingLines: 6,
          builder: (r) => ActivityTimeline(
            emptyMessage: 'No recorded activity yet.',
            entries: [for (final e in r.items) auditTimelineEntry(e, showActor: false, open: (route) => context.push(route))],
          ),
        ),
      ],
    );
  }
}

class _AuditTab extends ConsumerWidget {
  const _AuditTab({required this.doctorId});
  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (id: doctorId, scope: 'audit');
    return _TabBody(
      onRefresh: () async => ref.invalidate(adminDoctorActivityProvider(key)),
      children: [
        AsyncBody(
          value: ref.watch(adminDoctorActivityProvider(key)),
          onRetry: () => ref.invalidate(adminDoctorActivityProvider(key)),
          loading: const SkeletonList(count: 5),
          data: (r) => r.items.isEmpty ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No audit entries.') : AuditTable(entries: r.items, total: r.total),
        ),
      ],
    );
  }
}

/// Date, time, action, related record and who performed it. Shared with the patient profile.
class AuditTable extends StatelessWidget {
  const AuditTable({super.key, required this.entries, required this.total});
  final List<LinkedAuditEntry> entries;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    String related(LinkedAuditEntry e) => [?e.entry.entityLabel, if (e.patient != null) 'Patient: ${e.patient!.name}'].join(' · ');
    void open(LinkedAuditEntry e) {
      final route = routeForAudit(e);
      if (route != null) context.push(route);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(total > entries.length ? 'Latest ${entries.length} of $total entries' : '$total entr${total == 1 ? 'y' : 'ies'}', style: t.labelMedium),
      const SizedBox(height: AppSpacing.sm),
      ResponsiveTable<LinkedAuditEntry>(
        rows: entries,
        onRowTap: open,
        columns: [
          TableColumnSpec('Date', (e) => CellText(Fmt.date(e.entry.createdAt), secondary: Fmt.time(e.entry.createdAt)), flex: 2),
          TableColumnSpec('Action', (e) => CellText(auditActionText(e.entry.action), bold: true), flex: 4),
          TableColumnSpec('Related record', (e) => CellText(related(e).isEmpty ? '—' : related(e)), flex: 4, tabletVisible: false),
          TableColumnSpec('Performed by', (e) => CellText(auditActor(e.entry)), flex: 3),
        ],
        mobileCard: (e) => AppCard(
          onTap: routeForAudit(e) == null ? null : () => open(e),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(auditActionText(e.entry.action), style: t.titleSmall),
            Text('${Fmt.dateTime(e.entry.createdAt)} · ${auditActor(e.entry)}', style: t.bodySmall),
            if (related(e).isNotEmpty) Text(related(e), style: t.bodySmall),
          ]),
        ),
      ),
    ]);
  }
}

// ---------- Profile ----------

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.detail});
  final AdminDoctorDetail detail;

  @override
  Widget build(BuildContext context) {
    final p = detail.profile;
    const notRecorded = 'Not recorded';
    return _TabBody(
      children: [
        TwoColumn(
          left: AppCard(
            padding: const EdgeInsets.all(AppSpacing.lgPlus),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionHeader('Doctor Information'),
              KeyValueRow('Full name', 'Dr. ${p.fullName}'),
              KeyValueRow('Doctor ID', p.doctorCode),
              KeyValueRow('Specialization', p.specialization ?? notRecorded),
              KeyValueRow('License / registration', p.licenseNumber ?? notRecorded),
              KeyValueRow('Email', p.email),
              KeyValueRow('Phone', p.phone ?? notRecorded),
            ]),
          ),
          right: AppCard(
            padding: const EdgeInsets.all(AppSpacing.lgPlus),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionHeader('Account'),
              KeyValueRow('Status', '', valueWidget: Align(alignment: Alignment.centerLeft, child: activePill(p.isActive))),
              KeyValueRow('Account created', Fmt.date(p.createdAt)),
              KeyValueRow('Last sign-in', detail.lastLoginAt == null ? 'Never' : Fmt.dateTime(detail.lastLoginAt)),
              KeyValueRow('Last activity', detail.lastActivityAt == null ? 'None recorded' : Fmt.dateTime(detail.lastActivityAt)),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(onPressed: () => context.push('/a/doctors/${p.id}/edit'), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit Doctor')),
            ]),
          ),
        ),
      ],
    );
  }
}

// ---------- Shared bits ----------

class _TabBody extends StatelessWidget {
  const _TabBody({required this.children, this.onRefresh});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) => PageBody(
        padding: const EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.huge),
        onRefresh: onRefresh,
        children: children,
      );
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Skeleton(height: 20, width: 140),
            SizedBox(height: AppSpacing.xl),
            Row(children: [
              Skeleton(height: 72, width: 72, radius: 36),
              SizedBox(width: AppSpacing.lg),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Skeleton(height: 24, width: 240), SizedBox(height: AppSpacing.sm), Skeleton(height: 16, width: 180)])),
            ]),
            SizedBox(height: AppSpacing.xxl),
            Skeleton(height: 40),
            SizedBox(height: AppSpacing.xl),
            SkeletonList(count: 3),
          ]),
        ),
      ),
    );
  }
}
