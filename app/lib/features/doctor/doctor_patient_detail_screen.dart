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
import '../ai/ai_screens.dart';
import '../diabetes/diabetes_screen.dart';
import '../glucose/glucose_screen.dart';
import '../lifestyle/lifestyle_screen.dart';
import '../lifestyle/trend_card.dart';
import '../patient/profile_screen.dart';
import '../patient/timeline_screen.dart';
import '../prescriptions/prescriptions_screens.dart';
import '../reports/reports_screen.dart';
import '../side_effects/side_effects_screens.dart';
import '../visits/visits_screens.dart';

const _tabs = ['Overview', 'Diabetes', 'Reports', 'Glucose', 'Lifestyle', 'Prescriptions', 'Visits', 'Side Effects', 'AI Summary'];

/// Everything here is read through endpoints that re-check the doctor's approved access.
class DoctorPatientDetailScreen extends ConsumerWidget {
  const DoctorPatientDetailScreen({super.key, required this.patientId, this.initialTab = 0});
  final String patientId;
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(patientProfileProvider(patientId));
    final name = profile.value?.fullName ?? 'Patient';
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width >= Breakpoints.tablet ? AppSpacing.xxl : AppSpacing.lg;
    Widget tab(Widget child) => Padding(padding: EdgeInsets.symmetric(horizontal: gutter), child: child);

    if (profile.hasError && !profile.hasValue) {
      return AppPage(title: 'Patient', body: ErrorState(error: profile.error!, onRetry: () => ref.invalidate(patientProfileProvider(patientId))));
    }
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: initialTab.clamp(0, _tabs.length - 1),
      child: AppPage(
        title: name,
        bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in _tabs) Tab(text: t)]),
        body: TabBarView(children: [
          tab(_OverviewTab(patientId: patientId)),
          tab(DiabetesView(patientId: patientId, embedded: true, canAssess: true)),
          tab(ReportsView(patientId: patientId, uploadRoute: '/r/$patientId/reports/upload', embedded: true)),
          tab(GlucoseView(patientId: patientId, embedded: true, ranges: TrendCard.clinicalRanges)),
          tab(LifestyleView(patientId: patientId, embedded: true, ranges: TrendCard.clinicalRanges)),
          tab(PrescriptionsView(patientId: patientId, embedded: true)),
          tab(VisitsView(patientId: patientId, embedded: true)),
          tab(SideEffectsView(patientId: patientId, embedded: true)),
          tab(PatientSummaryView(patientId: patientId, embedded: true)),
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
            const SectionHeader('Body measurements'),
            BodyMeasurementsCard(body: p.body, patientId: p.id, canEdit: true),
            const SizedBox(height: AppSpacing.section),
            const SectionHeader('Actions'),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              FilledButton.icon(onPressed: () => context.push('/d/patients/$patientId/prescriptions/new'), icon: const Icon(Icons.medication_outlined), label: const Text('New Prescription')),
              OutlinedButton.icon(onPressed: () => context.push('/d/patients/$patientId/visits/new'), icon: const Icon(Icons.event_note_outlined), label: const Text('Record Visit')),
              OutlinedButton.icon(onPressed: () => context.push('/r/$patientId/reports/upload'), icon: const Icon(Icons.upload_file_outlined), label: const Text('Upload Report')),
              OutlinedButton.icon(onPressed: () => _recommend(context, ref), icon: const Icon(Icons.event_available_outlined), label: const Text('Recommend Appointment')),
            ]),
            const SizedBox(height: AppSpacing.section),
            const SectionHeader('Contact'),
            AppCard(
              child: Column(children: [
                KeyValueRow('Email', p.email),
                KeyValueRow('Phone', p.phone ?? 'Not provided'),
                KeyValueRow('Date of birth', p.dateOfBirth == null ? 'Not provided' : Fmt.date(p.dateOfBirth)),
                KeyValueRow('Emergency contact', p.emergencyContact.isEmpty ? 'Not provided' : [p.emergencyContact.name, p.emergencyContact.relationship, p.emergencyContact.phone].whereType<String>().join(' · ')),
              ]),
            ),
            const SizedBox(height: AppSpacing.section),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(leading: const Icon(Icons.timeline_outlined, color: AppColors.primary), title: const Text('Health timeline'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/d/patients/$patientId/timeline')),
                const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                ListTile(leading: const Icon(Icons.restaurant_outlined, color: AppColors.primary), title: const Text('Food log'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/d/patients/$patientId/food')),
                const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                ListTile(leading: const Icon(Icons.auto_awesome_outlined, color: AppColors.primary), title: const Text('All Reports Summary'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/r/$patientId/reports-summary')),
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
      if (context.mounted) showToast(context, 'Appointment recommendation sent to the patient');
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
    final now = DateTime.now();
    return SheetForm(title: 'Recommend Appointment', form: _form, children: [
      AppTextField(label: 'Reason', controller: _reason, maxLines: 3, validator: (v) => Validators.required(v, 'Reason'), textCapitalization: TextCapitalization.sentences),
      DateTimeField(label: 'Suggested date', optional: true, value: _for, firstDate: now, lastDate: now.add(const Duration(days: 365)), onChanged: (d) => setState(() => _for = d)),
      BusyButton(label: 'Send recommendation', onPressed: _save, expand: true),
    ]);
  }
}
