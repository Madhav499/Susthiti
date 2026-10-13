import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/l10n/enum_labels.dart';
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
import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(adminDoctorProvider(doctorId));
    void back() => context.canPop() ? context.pop() : context.go('/a/doctors');

    return value.when(
      skipLoadingOnRefresh: true,
      loading: () => const _ProfileSkeleton(),
      error: (e, _) => AppPage(
        title: l10n.commonDoctorLabel,
        body: Column(children: [
          ErrorState(error: e, title: e is NotFoundFailure ? null : l10n.adocUnableToLoadProfile, onRetry: () => ref.invalidate(adminDoctorProvider(doctorId))),
          TextButton.icon(onPressed: back, icon: const Icon(Icons.arrow_back, size: 18), label: Text(l10n.adocBackToDoctors)),
        ]),
      ),
      data: (d) {
        final p = d.profile;
        return TabbedProfile(
          initialTab: initialTab,
          header: ProfileHeader(
            name: l10n.commonDrName(p.fullName),
            backLabel: l10n.adocBackToDoctors,
            onBack: back,
            breadcrumbs: [l10n.adminDashboardTitle, l10n.navDoctors, l10n.commonDrName(p.fullName)],
            idLabel: l10n.adocDoctorIdColon(p.doctorCode),
            details: [p.specialization ?? l10n.adocSpecializationNotRecorded, if (d.lastActivityAt != null) l10n.adminLastActiveLabel(Fmt.relative(l10n, d.lastActivityAt))],
            status: activePill(l10n, p.isActive),
            badges: [if (p.isDemo) const DemoBadge()],
            actions: [
              FilledButton.icon(onPressed: () => context.push('/a/doctors/${p.id}/edit'), icon: const Icon(Icons.edit_outlined, size: 18), label: Text(l10n.adminEditDoctorButton)),
              _DoctorMoreMenu(detail: d),
            ],
          ),
          tabs: [
            ProfileTab('overview', l10n.tabOverview, _OverviewTab(detail: d)),
            ProfileTab('patients', l10n.navPatients, _PatientsTab(doctorId: doctorId)),
            ProfileTab('reports', l10n.navReports, _ReportsTab(doctorId: doctorId)),
            ProfileTab('prescriptions', l10n.navPrescriptions, _PrescriptionsTab(doctorId: doctorId)),
            ProfileTab('appointments', l10n.navAppointments, _AppointmentsTab(doctorId: doctorId)),
            ProfileTab('side-effects', l10n.navSideEffects, _SideEffectsTab(doctorId: doctorId)),
            ProfileTab('activity', l10n.commonActivityTab, _ActivityTab(doctorId: doctorId)),
            ProfileTab('profile', l10n.profileTitle, _ProfileTab(detail: d)),
            ProfileTab('audit', l10n.commonAuditTab, _AuditTab(doctorId: doctorId)),
          ],
        );
      },
    );
  }
}

class _DoctorMoreMenu extends ConsumerWidget {
  const _DoctorMoreMenu({required this.detail});
  final AdminDoctorDetail detail;

  Future<void> _toggle(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final p = detail.profile;
    if (p.isActive) {
      final ok = await confirmAction(
        context,
        title: l10n.adminDeactivateDoctorTitle(p.fullName),
        message: l10n.adminDeactivateDoctorMessage,
        confirmLabel: l10n.commonDeactivate,
        destructive: true,
      );
      if (!ok) return;
    }
    try {
      await ref.read(adminRepositoryProvider).updateDoctor(p.id, {'is_active': !p.isActive});
      ref.invalidate(adminDoctorProvider(p.id));
      ref.invalidate(adminDoctorsProvider);
      if (context.mounted) showToast(context, p.isActive ? l10n.adminDoctorDeactivatedToast : l10n.adminDoctorReactivatedToast);
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: l10n.adocMoreActionsTooltip,
      onSelected: (a) => switch (a) {
        'patients' => TabbedProfile.goTo(context, 'patients'),
        'activity' => TabbedProfile.goTo(context, 'activity'),
        'audit' => TabbedProfile.goTo(context, 'audit'),
        _ => _toggle(context, ref, l10n),
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'patients', child: Text(l10n.adminViewPatientsMenuItem)),
        PopupMenuItem(value: 'activity', child: Text(l10n.commonViewActivity)),
        PopupMenuItem(value: 'audit', child: Text(l10n.adocViewAuditLogMenuItem)),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'toggle', child: Text(detail.profile.isActive ? l10n.adminDeactivateDoctorButton : l10n.adminReactivateDoctorButton, style: TextStyle(color: detail.profile.isActive ? AppColors.errorText : null))),
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
        Text(AppLocalizations.of(context).navMore, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.primary)),
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
    final l10n = AppLocalizations.of(context);
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
          StatBlock(icon: Icons.people_outline, label: l10n.adminActivePatientsLabel, value: '${s('active_patients')}', caption: l10n.adocTotalPendingCaption('${s('total_patients')}', '${s('pending_requests')}'), onTap: () => goTo('patients')),
          StatBlock(icon: Icons.description_outlined, label: l10n.navReports, value: '${s('reports_uploaded_this_month')}', caption: l10n.adocThisMonthTotalCaption('${s('reports_uploaded_this_month')}', '${s('reports_uploaded')}'), onTap: () => goTo('reports')),
          StatBlock(icon: Icons.medication_outlined, label: l10n.navPrescriptions, value: '${s('prescriptions_this_month')}', caption: l10n.adocThisMonthTotalCaption('${s('prescriptions_this_month')}', '${s('prescriptions')}'), onTap: () => goTo('prescriptions')),
          StatBlock(icon: Icons.event_outlined, label: l10n.adocUpcomingLabel, value: '${s('upcoming_appointments') + s('upcoming_follow_ups')}', caption: l10n.adocFollowUpsApptsCaption('${s('upcoming_follow_ups')}', '${s('upcoming_appointments')}'), onTap: () => goTo('appointments')),
          StatBlock(icon: Icons.healing_outlined, label: l10n.navSideEffects, value: '${s('side_effects_pending')}', caption: l10n.adocPendingResolvedCaption('${s('side_effects_pending')}', '${s('side_effects_resolved')}'), onTap: () => goTo('side-effects')),
        ]),
        const SizedBox(height: AppSpacing.lg),
        TwoColumn(
          leftFlex: 3,
          rightFlex: 2,
          left: AsyncSection<List<DoctorPatientLink>>(
            title: l10n.adocActivePatientsHeader,
            value: patients,
            onRetry: () => ref.invalidate(adminDoctorPatientsProvider(id)),
            action: TextButton(onPressed: () => goTo('patients'), child: Text(l10n.commonViewAll)),
            builder: (links) {
              final active = [for (final l in links) if (l.access.status == AccessStatus.approved) l];
              if (active.isEmpty) return EmptyLine(l10n.adocNoActivePatients, icon: Icons.people_outline);
              return Column(children: [
                for (var i = 0; i < active.length && i < 6; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _PatientProgressRow(snapshot: active[i].snapshot),
                ],
              ]);
            },
          ),
          right: AsyncSection<({List<LinkedAuditEntry> items, int total})>(
            title: l10n.adocRecentActivityHeader,
            value: activity,
            onRetry: () => ref.invalidate(adminDoctorActivityProvider),
            action: TextButton(onPressed: () => goTo('activity'), child: Text(l10n.commonViewAll)),
            builder: (r) => ActivityTimeline(
              emptyMessage: l10n.adocNoRecordedActivityYet,
              entries: [for (final e in r.items.take(8)) auditTimelineEntry(l10n, e, showActor: false, open: (route) => context.push(route))],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TwoColumn(
          leftFlex: 3,
          rightFlex: 2,
          left: _ProgressCard(progress: detail.progress),
          right: AsyncSection<List<DoctorPatientLink>>(
            title: l10n.adocPatientAccessHeader,
            subtitle: l10n.adocPatientAccessSubtitle,
            value: patients,
            onRetry: () => ref.invalidate(adminDoctorPatientsProvider(id)),
            builder: (links) => links.isEmpty
                ? EmptyLine(l10n.adocNoAccessRequestsYet, icon: Icons.verified_user_outlined)
                : Column(children: [
                    for (final l in links.take(8))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.snapshot.ref.name),
                        subtitle: Text(l10n.adocRequestedOnCaption(l.snapshot.ref.patientCode, Fmt.date(l.access.requestedAt))),
                        trailing: accessPill(l10n, l.access.status),
                        onTap: () => context.push(adminPatientRoute(l.snapshot.ref.id)),
                      ),
                  ]),
          ),
        ),
        Disclaimer(text: l10n.adocFiguresDisclaimer),
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
    final l10n = AppLocalizations.of(context);
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
                diabetesStatusPill(l10n, s.latestAssessment?.riskCategory),
                if (s.latestGlucose != null) _Fact(icon: trendIcon(s.glucoseTrend), text: '${s.latestGlucose!.round()} mg/dL'),
                _Fact(icon: Icons.schedule, text: s.lastActivityAt == null ? l10n.adocNoActivity : Fmt.relative(l10n, s.lastActivityAt)),
              ]),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          progressPill(l10n, s),
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
    final l10n = AppLocalizations.of(context);
    final total = progress['patients'];
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lgPlus),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l10n.adocPatientProgressHeader, style: t.titleMedium),
        Text(l10n.adocAcrossActivePatients(total), style: t.bodySmall),
        const SizedBox(height: AppSpacing.lg),
        if (total == 0)
          EmptyLine(l10n.adocNoActivePatients, icon: Icons.people_outline)
        else ...[
          Text(l10n.adocLatestClassificationLabel, style: t.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          DistributionBar(segments: [
            (label: l10n.adocPatternDetected, value: progress['elevated_risk_pattern'], color: AppColors.warning),
            (label: l10n.adocNoPatternDetected, value: progress['lower_risk_pattern'], color: AppColors.success),
            (label: l10n.diabetesNotAssessed, value: progress['not_assessed'], color: AppColors.textMuted),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.adocGlucoseLast7DaysLabel, style: t.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          DistributionBar(segments: [
            (label: l10n.glucoseTrendHigher, value: progress['glucose_higher'], color: AppColors.warning),
            (label: l10n.adocSimilarLabel, value: progress['glucose_stable'], color: AppColors.secondary),
            (label: l10n.glucoseTrendLower, value: progress['glucose_lower'], color: AppColors.primary),
            (label: l10n.adocTooFewReadings, value: total - progress['glucose_higher'] - progress['glucose_stable'] - progress['glucose_lower'], color: AppColors.border),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            StatusPill(l10n.adocNeedAttentionPill('${progress['needs_attention']}'), tone: progress['needs_attention'] > 0 ? StatusTone.attention : StatusTone.inactive),
            StatusPill(l10n.adocOpenSideEffectsPill('${progress['open_side_effects']}'), tone: progress['open_side_effects'] > 0 ? StatusTone.attention : StatusTone.inactive),
            StatusPill(l10n.adocAssessedIn30DaysPill('${progress['assessed_last_30d']}'), tone: StatusTone.info),
            StatusPill(l10n.adocInactiveFor30DaysPill('${progress['no_activity_30d']}'), tone: StatusTone.inactive),
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
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(adminDoctorPatientsProvider(widget.doctorId));
    final t = Theme.of(context).textTheme;
    return _TabBody(
      onRefresh: () async => ref.invalidate(adminDoctorPatientsProvider(widget.doctorId)),
      children: [
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          for (final s in <AccessStatus?>[AccessStatus.approved, AccessStatus.pending, AccessStatus.revoked, AccessStatus.rejected, null])
            ChoiceChip(label: Text(s == null ? l10n.notifFilterAll : (s == AccessStatus.approved ? l10n.commonActive : accessStatusLabel(l10n, s))), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
        ]),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: value,
          onRetry: () => ref.invalidate(adminDoctorPatientsProvider(widget.doctorId)),
          loading: const SkeletonList(count: 4),
          data: (links) {
            final rows = [for (final l in links) if (_status == null || l.access.status == _status) l];
            if (rows.isEmpty) {
              return EmptyState(icon: Icons.people_outline, title: _status == AccessStatus.approved ? l10n.adocNoActivePatients : l10n.adocNoPatientsInGroup);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l10n.adocPatientsCountLabel(rows.length), style: t.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              ResponsiveTable<DoctorPatientLink>(
                rows: rows,
                onRowTap: (l) => context.push(adminPatientRoute(l.snapshot.ref.id)),
                columns: [
                  TableColumnSpec(l10n.adminColPatient, (l) => CellText(l.snapshot.ref.name, secondary: l.snapshot.ref.patientCode, bold: true), flex: 3),
                  TableColumnSpec(l10n.adminColDiabetesStatus, (l) => PillCell(diabetesStatusPill(l10n, l.snapshot.latestAssessment?.riskCategory)), flex: 3),
                  TableColumnSpec(
                    l10n.adocLatestGlucoseCol,
                    (l) => CellText(l.snapshot.latestGlucose == null ? '—' : '${l.snapshot.latestGlucose!.round()} mg/dL', secondary: l.snapshot.latestGlucose == null ? null : trendLabel(l10n, l.snapshot.glucoseTrend)),
                    flex: 3,
                    tabletVisible: false,
                  ),
                  TableColumnSpec(l10n.adminColLastActivity, (l) => CellText(l.snapshot.lastActivityAt == null ? '—' : Fmt.relative(l10n, l.snapshot.lastActivityAt)), flex: 2),
                  TableColumnSpec(l10n.adocProgressCol, (l) => PillCell(progressPill(l10n, l.snapshot)), flex: 2, tabletVisible: false),
                  TableColumnSpec(l10n.adocAccessCol, (l) => PillCell(accessPill(l10n, l.access.status)), flex: 2),
                ],
                mobileCard: (l) => AppCard(
                  onTap: () => context.push(adminPatientRoute(l.snapshot.ref.id)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: CellText(l.snapshot.ref.name, secondary: l.snapshot.ref.patientCode, bold: true)),
                      accessPill(l10n, l.access.status),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                      diabetesStatusPill(l10n, l.snapshot.latestAssessment?.riskCategory),
                      if (l.access.status == AccessStatus.approved) progressPill(l10n, l.snapshot),
                    ]),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        if (l.snapshot.latestGlucose != null) l10n.adocGlucoseMgDl('${l.snapshot.latestGlucose!.round()}'),
                        l10n.adocLastActivityLine(l.snapshot.lastActivityAt == null ? '—' : Fmt.relative(l10n, l.snapshot.lastActivityAt)),
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
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(adminDoctorReportsProvider(doctorId));
    void retry() => ref.invalidate(adminDoctorReportsProvider(doctorId));
    Widget reportRow(ReportWithPatient r, {bool opened = false}) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const IconBadge(Icons.description_outlined, size: 36),
          title: Text(r.report.title),
          subtitle: Text([
            if (r.patient != null) l10n.auditPatientPrefix(r.patient!.name),
            l10n.adocReportDateLabel(Fmt.date(r.report.reportDate)),
            opened ? l10n.adocOpenedLabel(Fmt.relative(l10n, r.openedAt)) : l10n.adocUploadedLabel(Fmt.date(r.report.uploadedAt)),
          ].join(' · ')),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          onTap: () => context.push('/r/${r.report.patientId}/reports/${r.report.id}'),
        );
    return _TabBody(
      onRefresh: () async => retry(),
      children: [
        AsyncSection<DoctorReportActivity>(
          title: l10n.adocReportsUploadedHeader,
          value: value,
          onRetry: retry,
          builder: (d) => d.uploaded.isEmpty ? EmptyLine(l10n.adocNoReportsUploadedByDoctor) : Column(children: [for (final r in d.uploaded) reportRow(r)]),
        ),
        const SizedBox(height: AppSpacing.lg),
        TwoColumn(
          left: AsyncSection<DoctorReportActivity>(
            title: l10n.adocReportsOpenedHeader,
            subtitle: l10n.adocReportsOpenedSubtitle,
            value: value,
            onRetry: retry,
            builder: (d) => d.opened.isEmpty ? EmptyLine(l10n.adocNoRecentReportActivity) : Column(children: [for (final r in d.opened) reportRow(r, opened: true)]),
          ),
          right: AsyncSection<DoctorReportActivity>(
            title: l10n.adocAiSummariesHeader,
            value: value,
            onRetry: retry,
            builder: (d) => d.summaries.isEmpty
                ? EmptyLine(l10n.adocNoSummariesGenerated, icon: Icons.auto_awesome_outlined)
                : Column(children: [
                    for (final s in d.summaries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const IconBadge(Icons.auto_awesome_outlined, size: 36),
                        title: Text(s.kind == 'all_reports' ? l10n.adocAllReportsSummaryTitle : l10n.adocReportSummaryTitle),
                        subtitle: Text([if (s.patient != null) l10n.auditPatientPrefix(s.patient!.name), Fmt.dateTime(s.generatedAt)].join(' · ')),
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
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(adminDoctorPrescriptionsProvider(doctorId));
    final t = Theme.of(context).textTheme;
    void open(PrescriptionWithPatient p) => context.push('/r/${p.prescription.patientId ?? p.patient?.id}/prescriptions/${p.prescription.id}');
    return _TabBody(
      onRefresh: () async => ref.invalidate(adminDoctorPrescriptionsProvider(doctorId)),
      children: [
        Text(l10n.adocPrescriptionsHistoricalNote, style: t.bodySmall),
        const SizedBox(height: AppSpacing.md),
        AsyncBody(
          value: value,
          onRetry: () => ref.invalidate(adminDoctorPrescriptionsProvider(doctorId)),
          loading: const SkeletonList(count: 4),
          data: (r) => r.items.isEmpty
              ? EmptyState(icon: Icons.medication_outlined, title: l10n.adocNoPrescriptionsRecorded)
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(l10n.adocPrescriptionsCountLabel(r.total), style: t.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ResponsiveTable<PrescriptionWithPatient>(
                    rows: r.items,
                    onRowTap: open,
                    columns: [
                      TableColumnSpec(l10n.adocPrescriptionCol, (p) => CellText(p.prescription.code, bold: true), flex: 2),
                      TableColumnSpec(l10n.adminColPatient, (p) => CellText(p.patient?.name ?? '—', secondary: p.patient?.patientCode), flex: 3),
                      TableColumnSpec(l10n.rxDateLabel, (p) => CellText(Fmt.date(p.prescription.prescribedOn)), flex: 2),
                      TableColumnSpec(l10n.adocMedicinesCol, (p) => CellText('${p.prescription.medicines.length}', secondary: p.prescription.medicines.map((m) => m.medicine).join(', ')), flex: 3, tabletVisible: false),
                      TableColumnSpec(l10n.visitFollowUpLabel, (p) => CellText(p.prescription.followUpDate == null ? '—' : Fmt.date(p.prescription.followUpDate)), flex: 2),
                    ],
                    mobileCard: (p) => AppCard(
                      onTap: () => open(p),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Expanded(child: Text(p.prescription.code, style: t.titleSmall)), Text(Fmt.date(p.prescription.prescribedOn), style: t.bodySmall)]),
                        Text(l10n.auditPatientPrefix(p.patient?.name ?? '—'), style: t.bodyMedium),
                        Text(
                          '${l10n.adocMedicinesCountLabel(p.prescription.medicines.length)}${p.prescription.followUpDate == null ? '' : ' · ${l10n.visitsFollowUpOn(Fmt.date(p.prescription.followUpDate))}'}',
                          style: t.bodySmall,
                        ),
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
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(adminDoctorAppointmentsProvider(doctorId));
    void retry() => ref.invalidate(adminDoctorAppointmentsProvider(doctorId));
    return _TabBody(
      onRefresh: () async => retry(),
      children: [
        TwoColumn(
          left: AsyncSection<DoctorAppointments>(
            title: l10n.adocUpcomingFollowUpsHeader,
            subtitle: l10n.adocUpcomingFollowUpsSubtitle,
            value: value,
            onRetry: retry,
            builder: (d) => d.followUps.isEmpty
                ? EmptyLine(l10n.adocNoUpcomingFollowUps, icon: Icons.event_outlined)
                : Column(children: [
                    for (final f in d.followUps)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _DateBadge(f.date),
                        title: Text(f.patient?.name ?? l10n.commonPatientFallback),
                        subtitle: Text('${_followUpSourceLabel(l10n, f)}${f.code == null ? '' : ' · ${f.code}'}${f.reason == null ? '' : ' · ${f.reason}'}'),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        onTap: f.patient == null ? null : () => context.push(_followUpRoute(f)),
                      ),
                  ]),
          ),
          right: AsyncSection<DoctorAppointments>(
            title: l10n.adocAppointmentRecommendationsHeader,
            value: value,
            onRetry: retry,
            builder: (d) => d.recommendations.isEmpty
                ? EmptyLine(l10n.adocNoAppointmentRecommendations, icon: Icons.event_available_outlined)
                : Column(children: [
                    for (final a in d.recommendations)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const IconBadge(Icons.event_available_outlined, size: 36),
                        title: Text(a.patient?.name ?? l10n.commonPatientFallback),
                        subtitle: Text('${a.appointment.reason}\n${a.appointment.recommendedFor == null ? l10n.adocRecommendedOn(Fmt.date(a.appointment.createdAt)) : l10n.adocSuggestedFor(Fmt.date(a.appointment.recommendedFor))}'),
                        isThreeLine: true,
                        onTap: a.patient == null ? null : () => context.push(adminPatientRoute(a.patient!.id, tab: 'appointments')),
                      ),
                  ]),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AsyncSection<DoctorAppointments>(
          title: l10n.adocRecentVisitsHeader,
          value: value,
          onRetry: retry,
          builder: (d) => d.visits.isEmpty
              ? EmptyLine(l10n.adocNoVisitsRecorded, icon: Icons.event_note_outlined)
              : Column(children: [
                  for (final v in d.visits)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const IconBadge(Icons.event_note_outlined, size: 36),
                      title: Text('${v.patient?.name ?? l10n.commonPatientFallback} · ${v.reason}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${v.code} · ${Fmt.date(v.visitDate)}${v.followUpDate == null ? '' : ' · ${l10n.visitsFollowUpOn(Fmt.date(v.followUpDate))}'}'),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      onTap: v.patient == null ? null : () => context.push('/r/${v.patient!.id}/visits/${v.id}'),
                    ),
                ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AsyncSection<DoctorAppointments>(
          title: l10n.adocScheduledSurgeriesHeader,
          value: value,
          onRetry: retry,
          builder: (d) => d.surgeries.isEmpty
              ? EmptyLine(l10n.surgeriesEmptyTitle, icon: Icons.local_hospital_outlined)
              : Column(children: [
                  for (final s in d.surgeries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const IconBadge(Icons.local_hospital_outlined, size: 36),
                      title: Text('${s.patient?.name ?? l10n.commonPatientFallback} · ${s.surgery.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${s.surgery.status.label}${s.surgery.scheduledAt == null ? '' : ' · ${Fmt.dateTime(s.surgery.scheduledAt)}'}'),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      onTap: s.patient == null ? null : () => context.push(adminPatientRoute(s.patient!.id, tab: 'surgeries')),
                    ),
                ]),
        ),
      ],
    );
  }
}

String _followUpSourceLabel(AppLocalizations l10n, FollowUp f) => switch (f.source) {
      'visit' => l10n.adocVisitFollowUpLabel,
      'prescription' => l10n.adocPrescriptionFollowUpLabel,
      'follow_up_task' => l10n.adocFollowUpStatusLabel(f.status == null ? '' : ' · ${f.status}'),
      _ => f.source,
    };

String _followUpRoute(FollowUp f) {
  final pid = f.patient!.id;
  return switch (f.source) {
    'visit' => '/r/$pid/visits/${f.recordId}',
    'prescription' => '/r/$pid/prescriptions/${f.recordId}',
    _ => adminPatientRoute(pid, tab: 'follow-ups'),
  };
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
    final l10n = AppLocalizations.of(context);
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
              StatBlock(icon: Icons.hourglass_empty, label: l10n.adocPendingReviewLabel, value: '${d.pending}'),
              StatBlock(icon: Icons.task_alt, label: l10n.commonResolvedLabel, value: '${d.resolved}'),
              StatBlock(icon: Icons.forum_outlined, label: l10n.adocRespondedByDoctorLabel, value: '${d.items.where((i) => i.doctorResponse != null).length}'),
            ]),
            const SizedBox(height: AppSpacing.lg),
            if (d.items.isEmpty)
              EmptyState(icon: Icons.healing_outlined, title: l10n.adocNoSideEffectReports)
            else
              ResponsiveTable<SideEffectWithPatient>(
                rows: d.items,
                onRowTap: (s) => context.push('/r/${s.sideEffect.patientId}/side-effects/${s.sideEffect.id}'),
                columns: [
                  TableColumnSpec(l10n.adminColPatient, (s) => CellText(s.patient?.name ?? '—', secondary: s.sideEffect.code, bold: true), flex: 3),
                  TableColumnSpec(l10n.adocSideEffectCol, (s) => CellText(s.sideEffect.description), flex: 4, tabletVisible: false),
                  TableColumnSpec(l10n.adocSeverityCol, (s) => PillCell(StatusPill(s.sideEffect.severity.label, tone: s.sideEffect.severity.tone)), flex: 2),
                  TableColumnSpec(l10n.adminColStatus, (s) => PillCell(StatusPill(s.sideEffect.status.label, tone: s.sideEffect.status.tone)), flex: 3),
                  TableColumnSpec(l10n.adocReportedCol, (s) => CellText(Fmt.date(s.sideEffect.occurredAt)), flex: 2),
                  TableColumnSpec(l10n.adocDoctorResponseCol, (s) => CellText(s.doctorResponse?.label ?? l10n.commonNoneYet, secondary: s.doctorRespondedAt == null ? null : Fmt.relative(l10n, s.doctorRespondedAt)), flex: 3, tabletVisible: false),
                ],
                mobileCard: (s) => AppCard(
                  onTap: () => context.push('/r/${s.sideEffect.patientId}/side-effects/${s.sideEffect.id}'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(s.patient?.name ?? l10n.commonPatientFallback, style: t.titleSmall)), StatusPill(s.sideEffect.status.label, tone: s.sideEffect.status.tone)]),
                    const SizedBox(height: AppSpacing.xs),
                    Text(s.sideEffect.description, style: t.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xs),
                    Text('${s.sideEffect.severity.label} · ${Fmt.date(s.sideEffect.occurredAt)} · ${s.doctorResponse?.label ?? l10n.adocNoResponseYet}', style: t.bodySmall),
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
    final l10n = AppLocalizations.of(context);
    final key = (id: doctorId, scope: 'actions');
    return _TabBody(
      onRefresh: () async => ref.invalidate(adminDoctorActivityProvider(key)),
      children: [
        AsyncSection<({List<LinkedAuditEntry> items, int total})>(
          title: l10n.adocRecentActivityHeader,
          subtitle: l10n.adocDoctorActivitySubtitle,
          value: ref.watch(adminDoctorActivityProvider(key)),
          onRetry: () => ref.invalidate(adminDoctorActivityProvider(key)),
          loadingLines: 6,
          builder: (r) => ActivityTimeline(
            emptyMessage: l10n.adocNoRecordedActivityYet,
            entries: [for (final e in r.items) auditTimelineEntry(l10n, e, showActor: false, open: (route) => context.push(route))],
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
    final l10n = AppLocalizations.of(context);
    final key = (id: doctorId, scope: 'audit');
    return _TabBody(
      onRefresh: () async => ref.invalidate(adminDoctorActivityProvider(key)),
      children: [
        AsyncBody(
          value: ref.watch(adminDoctorActivityProvider(key)),
          onRetry: () => ref.invalidate(adminDoctorActivityProvider(key)),
          loading: const SkeletonList(count: 5),
          data: (r) => r.items.isEmpty ? EmptyState(icon: Icons.receipt_long_outlined, title: l10n.adminNoAuditEntries) : AuditTable(entries: r.items, total: r.total),
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
    final l10n = AppLocalizations.of(context);
    String related(LinkedAuditEntry e) => [?e.entry.entityLabel, if (e.patient != null) l10n.auditPatientPrefix(e.patient!.name)].join(' · ');
    void open(LinkedAuditEntry e) {
      final route = routeForAudit(e);
      if (route != null) context.push(route);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(total > entries.length ? l10n.adocLatestOfTotalEntries(entries.length, total) : l10n.adocEntriesCountLabel(total), style: t.labelMedium),
      const SizedBox(height: AppSpacing.sm),
      ResponsiveTable<LinkedAuditEntry>(
        rows: entries,
        onRowTap: open,
        columns: [
          TableColumnSpec(l10n.commonDateColumnLabel, (e) => CellText(Fmt.date(e.entry.createdAt), secondary: Fmt.time(e.entry.createdAt)), flex: 2),
          TableColumnSpec(l10n.adocActionCol, (e) => CellText(auditActionText(l10n, e.entry.action), bold: true), flex: 4),
          TableColumnSpec(l10n.adocRelatedRecordCol, (e) => CellText(related(e).isEmpty ? '—' : related(e)), flex: 4, tabletVisible: false),
          TableColumnSpec(l10n.adocPerformedByCol, (e) => CellText(auditActor(l10n, e.entry)), flex: 3),
        ],
        mobileCard: (e) => AppCard(
          onTap: routeForAudit(e) == null ? null : () => open(e),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(auditActionText(l10n, e.entry.action), style: t.titleSmall),
            Text('${Fmt.dateTime(e.entry.createdAt)} · ${auditActor(l10n, e.entry)}', style: t.bodySmall),
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
    final l10n = AppLocalizations.of(context);
    final p = detail.profile;
    final notRecorded = l10n.commonNotRecorded;
    return _TabBody(
      children: [
        TwoColumn(
          left: AppCard(
            padding: const EdgeInsets.all(AppSpacing.lgPlus),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionHeader(l10n.adocDoctorInformationHeader),
              KeyValueRow(l10n.authFullName, l10n.commonDrName(p.fullName)),
              KeyValueRow(l10n.adminColDoctorId, p.doctorCode),
              KeyValueRow(l10n.commonSpecializationLabel, p.specialization ?? notRecorded),
              KeyValueRow(l10n.adocLicenseRegistrationLabel, p.licenseNumber ?? notRecorded),
              KeyValueRow(l10n.authEmailLabel, p.email),
              KeyValueRow(l10n.authPhone, p.phone ?? notRecorded),
            ]),
          ),
          right: AppCard(
            padding: const EdgeInsets.all(AppSpacing.lgPlus),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionHeader(l10n.settingsAccount),
              KeyValueRow(l10n.adminColStatus, '', valueWidget: Align(alignment: Alignment.centerLeft, child: activePill(l10n, p.isActive))),
              KeyValueRow(l10n.adocAccountCreatedLabel, Fmt.date(p.createdAt)),
              KeyValueRow(l10n.adocLastSignInLabel, detail.lastLoginAt == null ? l10n.commonNever : Fmt.dateTime(detail.lastLoginAt)),
              KeyValueRow(l10n.adminColLastActivity, detail.lastActivityAt == null ? l10n.commonNoneRecorded : Fmt.dateTime(detail.lastActivityAt)),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(onPressed: () => context.push('/a/doctors/${p.id}/edit'), icon: const Icon(Icons.edit_outlined, size: 18), label: Text(l10n.adminEditDoctorButton)),
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
