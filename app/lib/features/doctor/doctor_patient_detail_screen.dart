import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../health_profile/body_card.dart';
import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/labels.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../ai/ai_screens.dart';
import '../diabetes/diabetes_screen.dart';
import '../follow_ups/follow_ups_screens.dart';
import '../glucose/glucose_screen.dart';
import '../heart/heart_screen.dart';
import '../lifestyle/lifestyle_screen.dart';
import '../lifestyle/trend_card.dart';
import '../patient/profile_screen.dart';
import '../patient/timeline_screen.dart';
import '../prescriptions/prescriptions_screens.dart';
import '../reports/reports_screen.dart';
import '../side_effects/side_effects_screens.dart';
import '../surgery/surgery_screens.dart';
import '../visits/visits_screens.dart';

const _tabCount = 12;

List<String> _tabLabels(AppLocalizations l10n) => [
      l10n.tabOverview,
      l10n.tabAiSummary,
      l10n.navDiabetes,
      l10n.navHeart,
      l10n.navReports,
      l10n.navGlucose,
      l10n.navLifestyle,
      l10n.navPrescriptions,
      l10n.tabVisits,
      l10n.navFollowUps,
      l10n.navSurgeries,
      l10n.navSideEffects,
    ];

/// Everything here is read through endpoints that re-check the doctor's approved access.
class DoctorPatientDetailScreen extends ConsumerWidget {
  const DoctorPatientDetailScreen({super.key, required this.patientId, this.initialTab = 0});
  final String patientId;
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(patientProfileProvider(patientId));
    final name = profile.value?.fullName ?? l10n.patientFallbackName;
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width >= Breakpoints.tablet ? AppSpacing.xxl : AppSpacing.lg;
    Widget tab(Widget child) => Padding(padding: EdgeInsets.symmetric(horizontal: gutter), child: child);

    if (profile.hasError && !profile.hasValue) {
      return AppPage(title: l10n.patientFallbackName, body: ErrorState(error: profile.error!, onRetry: () => ref.invalidate(patientProfileProvider(patientId))));
    }
    return DefaultTabController(
      length: _tabCount,
      initialIndex: initialTab.clamp(0, _tabCount - 1),
      child: AppPage(
        title: name,
        bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in _tabLabels(l10n)) Tab(text: t)]),
        body: TabBarView(children: [
          tab(_OverviewTab(patientId: patientId)),
          tab(PatientSummaryView(patientId: patientId, embedded: true)),
          tab(DiabetesView(patientId: patientId, embedded: true, canAssess: true)),
          tab(HeartView(patientId: patientId, embedded: true, canAssess: true)),
          tab(ReportsView(patientId: patientId, uploadRoute: '/r/$patientId/reports/upload', embedded: true)),
          tab(GlucoseView(patientId: patientId, embedded: true, ranges: TrendCard.clinicalRanges)),
          tab(LifestyleView(patientId: patientId, embedded: true, ranges: TrendCard.clinicalRanges)),
          tab(PrescriptionsView(patientId: patientId, embedded: true)),
          tab(VisitsView(patientId: patientId, embedded: true)),
          tab(FollowUpsView(patientId: patientId, embedded: true)),
          tab(SurgeriesView(patientId: patientId, embedded: true)),
          tab(SideEffectsView(patientId: patientId, embedded: true)),
        ]),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return PageBody(
      maxWidth: 900,
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xxl),
      onRefresh: () async => ref.invalidate(patientProfileProvider(patientId)),
      children: [
        AsyncBody(
          value: ref.watch(patientProfileProvider(patientId)),
          onRetry: () => ref.invalidate(patientProfileProvider(patientId)),
          data: (p) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              PatientAvatar(patientId: p.id, name: p.fullName, hasPhoto: p.hasPhoto),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Flexible(child: Text(p.fullName, style: t.titleLarge)), if (p.isDemo) ...[const SizedBox(width: 6), const DemoBadge()]]),
                  Text([if (p.age != null) '${p.age} yrs', ?p.gender].join(' · '), style: t.bodySmall),
                ]),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            PatientIdTile(p.patientCode, compact: true),
            const SizedBox(height: AppSpacing.section),
            SectionHeader(l10n.doctorBodyMeasurementsHeader),
            BodyMeasurementsCard(body: p.body, patientId: p.id, canEdit: true),
            const SizedBox(height: AppSpacing.section),
            SectionHeader(l10n.commonActionsHeader),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              FilledButton.icon(onPressed: () => context.push('/d/patients/$patientId/prescriptions/new'), icon: const Icon(Icons.medication_outlined), label: Text(l10n.doctorNewPrescriptionButton)),
              OutlinedButton.icon(onPressed: () => context.push('/d/patients/$patientId/visits/new'), icon: const Icon(Icons.event_note_outlined), label: Text(l10n.visitsRecordVisit)),
              OutlinedButton.icon(onPressed: () => context.push('/r/$patientId/reports/upload'), icon: const Icon(Icons.upload_file_outlined), label: Text(l10n.dashUploadReport)),
              OutlinedButton.icon(onPressed: () => _recommend(context, ref), icon: const Icon(Icons.event_available_outlined), label: Text(l10n.doctorRecommendAppointmentButton)),
            ]),
            const SizedBox(height: AppSpacing.section),
            SectionHeader(l10n.commonContactHeader),
            AppCard(
              child: Column(children: [
                KeyValueRow(l10n.authEmailLabel, p.email),
                KeyValueRow(l10n.authPhone, p.phone ?? l10n.commonNotProvided),
                KeyValueRow(l10n.authDateOfBirth, p.dateOfBirth == null ? l10n.commonNotProvided : Fmt.date(p.dateOfBirth)),
                KeyValueRow(l10n.doctorEmergencyContactLabel, p.emergencyContact.isEmpty ? l10n.commonNotProvided : [p.emergencyContact.name, p.emergencyContact.relationship, p.emergencyContact.phone].whereType<String>().join(' · ')),
              ]),
            ),
            const SizedBox(height: AppSpacing.section),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(leading: const Icon(Icons.timeline_outlined, color: AppColors.primary), title: Text(l10n.dashHealthTimeline), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/d/patients/$patientId/timeline')),
                const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                ListTile(leading: const Icon(Icons.restaurant_outlined, color: AppColors.primary), title: Text(l10n.navFoodLog), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/d/patients/$patientId/food')),
                const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                ListTile(leading: const Icon(Icons.auto_awesome_outlined, color: AppColors.primary), title: Text(l10n.doctorAllReportsSummaryLabel), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/r/$patientId/reports-summary')),
              ]),
            ),
          ]),
        ),
      ],
    );
  }

  Future<void> _recommend(BuildContext context, WidgetRef ref) async {
    final done = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _RecommendSheet(patientId: patientId));
    if (done == true) {
      ref.invalidate(appointmentsProvider(patientId));
      if (context.mounted) showToast(context, AppLocalizations.of(context).doctorAppointmentRecommendationSentToast);
    }
  }
}

class _RecommendSheet extends ConsumerStatefulWidget {
  const _RecommendSheet({required this.patientId});
  final String patientId;

  @override
  ConsumerState<_RecommendSheet> createState() => _RecommendSheetState();
}

class _RecommendSheetState extends ConsumerState<_RecommendSheet> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  DateTime? _for;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      await ref.read(doctorRepositoryProvider).recommendAppointment(widget.patientId, reason: _reason.text, recommendedFor: _for);
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    return SheetForm(title: l10n.doctorRecommendAppointmentButton, form: _form, children: [
      AppTextField(label: l10n.commonReasonLabel, controller: _reason, maxLines: 3, validator: (v) => Validators.required(l10n, v, l10n.commonReasonLabel), textCapitalization: TextCapitalization.sentences),
      DateTimeField(label: l10n.sideEffectSuggestedDateLabel, optional: true, value: _for, firstDate: now, lastDate: now.add(const Duration(days: 365)), onChanged: (d) => setState(() => _for = d)),
      BusyButton(label: l10n.doctorSendRecommendationButton, onPressed: _save, expand: true),
    ]);
  }
}
