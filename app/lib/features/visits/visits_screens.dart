import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../data/models/care.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../authentication/auth_controller.dart';

final visitsProvider = FutureProvider.autoDispose.family<List<Visit>, String>((ref, pid) => ref.watch(visitRepositoryProvider).list(pid));
final visitProvider = FutureProvider.autoDispose.family<Visit, String>((ref, id) => ref.watch(visitRepositoryProvider).get(id));

class VisitsScreen extends ConsumerWidget {
  const VisitsScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDoctor = ref.watch(currentUserProvider)?.role == UserRole.doctor;
    return AppPage(
      title: l10n.visitsPageTitle,
      floatingActionButton: isDoctor
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/d/patients/$patientId/visits/new'),
              icon: const Icon(Icons.add),
              label: Text(l10n.visitsRecordVisit),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 1,
            )
          : null,
      body: VisitsView(patientId: patientId),
    );
  }
}

class VisitsView extends ConsumerWidget {
  const VisitsView({super.key, required this.patientId, this.embedded = false});
  final String patientId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return PageBody(
      maxWidth: 820,
      padding: embedded ? const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xxl) : null,
      onRefresh: () async => ref.invalidate(visitsProvider(patientId)),
      children: [
        AsyncBody(
          value: ref.watch(visitsProvider(patientId)),
          onRetry: () => ref.invalidate(visitsProvider(patientId)),
          data: (items) => items.isEmpty
              ? EmptyState(icon: Icons.event_note_outlined, title: l10n.visitsEmptyTitle, message: l10n.visitsEmptyMessage)
              : Column(children: [
                  for (final v in items) ...[
                    AppCard(
                      onTap: () => context.push('/r/$patientId/visits/${v.id}'),
                      child: Row(children: [
                        const IconBadge(Icons.event_note_outlined),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(v.reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                            const SizedBox(height: 2),
                            Text(l10n.visitsDoctorDateCode(v.doctorName, Fmt.date(v.visitDate), v.code), style: t.bodySmall),
                            if (v.followUpDate != null) Text(l10n.visitsFollowUpOn(Fmt.date(v.followUpDate)), style: t.bodySmall?.copyWith(color: AppColors.primary)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      ]),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ]),
        ),
      ],
    );
  }
}

class VisitDetailScreen extends ConsumerWidget {
  const VisitDetailScreen({super.key, required this.visitId});
  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    Widget section(String title, String? body) => (body == null || body.isEmpty)
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: t.titleSmall), const SizedBox(height: 4), Text(body, style: t.bodyMedium)]),
          );
    return AppPage(
      title: l10n.visitDetailTitle,
      body: PageBody(maxWidth: 760, children: [
        AsyncBody(
          value: ref.watch(visitProvider(visitId)),
          onRetry: () => ref.invalidate(visitProvider(visitId)),
          data: (v) => AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.reason, style: t.titleMedium),
              const SizedBox(height: AppSpacing.md),
              KeyValueRow(l10n.visitIdLabel, v.code),
              KeyValueRow(l10n.commonDoctorLabel, l10n.commonDrName(v.doctorName)),
              KeyValueRow(l10n.visitDateLabel, Fmt.date(v.visitDate)),
              if (v.followUpDate != null) KeyValueRow(l10n.visitFollowUpLabel, Fmt.date(v.followUpDate)),
              section(l10n.visitClinicalNotesLabel, v.clinicalNotes),
              section(l10n.visitAssessmentLabel, v.assessment),
              section(l10n.visitDoctorReasoningLabel, v.doctorReasoning),
              section(l10n.visitTreatmentDecisionLabel, v.treatmentDecision),
              section(l10n.commonInstructionsLabel, v.instructions),
            ]),
          ),
        ),
      ]),
    );
  }
}

class RecordVisitScreen extends ConsumerStatefulWidget {
  const RecordVisitScreen({super.key, required this.patientId});
  final String patientId;

  @override
  ConsumerState<RecordVisitScreen> createState() => _RecordVisitScreenState();
}

class _RecordVisitScreenState extends ConsumerState<RecordVisitScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  final _assessment = TextEditingController();
  final _reasoning = TextEditingController();
  final _decision = TextEditingController();
  final _instructions = TextEditingController();
  DateTime? _date = DateTime.now();
  DateTime? _followUp;

  @override
  void dispose() {
    for (final c in [_reason, _notes, _assessment, _reasoning, _decision, _instructions]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save(AppLocalizations l10n) async {
    if (!_form.currentState!.validate()) return;
    try {
      final v = await ref.read(visitRepositoryProvider).create(widget.patientId, {
        'visit_date': Fmt.isoDate(_date!),
        'reason': _reason.text.trim(),
        'clinical_notes': _text(_notes),
        'assessment': _text(_assessment),
        'doctor_reasoning': _text(_reasoning),
        'treatment_decision': _text(_decision),
        'follow_up_date': _followUp == null ? null : Fmt.isoDate(_followUp!),
        'instructions': _text(_instructions),
      });
      ref.invalidate(visitsProvider(widget.patientId));
      if (!mounted) return;
      showToast(context, l10n.visitRecordedToast(v.code));
      context.pop();
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    AppTextField area(String label, TextEditingController c) => AppTextField(label: label, controller: c, optional: true, maxLines: 4, textCapitalization: TextCapitalization.sentences);
    return AppPage(
      title: l10n.visitsRecordVisit,
      body: PageBody(maxWidth: 760, children: [
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DateTimeField(label: l10n.visitDateLabel, value: _date, onChanged: (d) => setState(() => _date = d), validator: (d) => Validators.notFuture(l10n, d, l10n.visitDateLabel)),
            AppTextField(label: l10n.visitReasonForVisitLabel, controller: _reason, validator: (v) => Validators.required(l10n, v, l10n.commonReasonLabel), textCapitalization: TextCapitalization.sentences),
            area(l10n.visitClinicalNotesLabel, _notes),
            area(l10n.visitAssessmentLabel, _assessment),
            area(l10n.visitDoctorReasoningLabel, _reasoning),
            area(l10n.visitTreatmentDecisionLabel, _decision),
            area(l10n.visitInstructionsForPatientLabel, _instructions),
            DateTimeField(label: l10n.visitFollowUpDateLabel, optional: true, value: _followUp, firstDate: now, lastDate: now.add(const Duration(days: 730)), onChanged: (d) => setState(() => _followUp = d)),
            const SizedBox(height: AppSpacing.sm),
            BusyButton(label: l10n.visitSaveButton, onPressed: () => _save(l10n), expand: true),
          ]),
        ),
      ]),
    );
  }
}
