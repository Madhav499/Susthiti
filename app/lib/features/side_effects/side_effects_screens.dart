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
import '../authentication/auth_controller.dart';

final sideEffectsProvider = FutureProvider.autoDispose.family<List<SideEffect>, String>((ref, pid) => ref.watch(sideEffectRepositoryProvider).list(pid));
final sideEffectProvider = FutureProvider.autoDispose.family<SideEffect, String>((ref, id) => ref.watch(sideEffectRepositoryProvider).get(id));

class SideEffectsScreen extends ConsumerWidget {
  const SideEffectsScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPatient = ref.watch(currentUserProvider)?.role == UserRole.patient;
    return AppPage(
      title: 'Side Effects',
      floatingActionButton: isPatient
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/p/side-effects/new'),
              icon: const Icon(Icons.add),
              label: const Text('Report Side Effect'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 1,
            )
          : null,
      body: SideEffectsView(patientId: patientId, canReport: isPatient),
    );
  }
}

class SideEffectsView extends ConsumerWidget {
  const SideEffectsView({super.key, required this.patientId, this.canReport = false, this.embedded = false});
  final String patientId;
  final bool canReport;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(sideEffectsProvider(patientId));
    return PageBody(
      maxWidth: 820,
      padding: embedded ? const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xxl) : null,
      onRefresh: () async => ref.invalidate(sideEffectsProvider(patientId)),
      children: [
        AsyncBody(
          value: value,
          onRetry: () => ref.invalidate(sideEffectsProvider(patientId)),
          data: (items) => items.isEmpty
              ? EmptyState(
                  icon: Icons.healing_outlined,
                  title: 'No side effects reported.',
                  message: canReport ? 'If a medicine makes you feel unwell, report it here so your doctor can review it.' : null,
                  actionLabel: canReport ? 'Report Side Effect' : null,
                  onAction: canReport ? () => context.push('/p/side-effects/new') : null,
                )
              : Column(children: [
                  for (final s in items) ...[
                    SideEffectTile(effect: s, onTap: () => context.push('/r/$patientId/side-effects/${s.id}')),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ]),
        ),
      ],
    );
  }
}

class SideEffectTile extends StatelessWidget {
  const SideEffectTile({super.key, required this.effect, required this.onTap});
  final SideEffect effect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = effect;
    return AppCard(
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(Icons.healing_outlined, tone: s.severity.tone),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
            const SizedBox(height: 2),
            Text('${s.code} · ${Fmt.dateTime(s.occurredAt)}${s.relatedMedication != null ? ' · ${s.relatedMedication}' : ''}', style: t.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
              StatusPill(s.severity.label, tone: s.severity.tone),
              StatusPill(s.status.label, tone: s.status.tone),
              if (s.priorityFlag) const StatusPill('Priority', tone: StatusTone.critical),
            ]),
          ]),
        ),
        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ]),
    );
  }
}

/// Patient reports a side effect. The severity is the patient's own; it only sets priority.
class ReportSideEffectScreen extends ConsumerStatefulWidget {
  const ReportSideEffectScreen({super.key, required this.patientId});
  final String patientId;

  @override
  ConsumerState<ReportSideEffectScreen> createState() => _ReportSideEffectScreenState();
}

class _ReportSideEffectScreenState extends ConsumerState<ReportSideEffectScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _medication = TextEditingController();
  final _notes = TextEditingController();
  Severity? _severity;
  DateTime? _at = DateTime.now();

  @override
  void dispose() {
    _description.dispose();
    _medication.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    try {
      final s = await ref.read(sideEffectRepositoryProvider).report(
            widget.patientId,
            description: _description.text,
            severity: _severity!,
            relatedMedication: _medication.text,
            occurredAt: _at!,
            notes: _notes.text,
          );
      ref.invalidate(sideEffectsProvider(widget.patientId));
      if (!mounted) return;
      showToast(context, 'Side effect reported. Your doctor has been notified.');
      context.pushReplacement('/r/${widget.patientId}/side-effects/${s.id}');
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final urgent = _severity == Severity.severe || _severity == Severity.emergency;
    return AppPage(
      title: 'Report Side Effect',
      body: PageBody(maxWidth: 640, children: [
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppTextField(
              label: 'What are you experiencing?',
              controller: _description,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().length < 3) ? 'Please describe what you are experiencing.' : null,
            ),
            ChoiceField<Severity>(label: 'How severe is it?', options: Severity.values, value: _severity, labelOf: (s) => s.label, onChanged: (s) => setState(() => _severity = s)),
            if (urgent)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.errorSoft, borderRadius: AppRadius.controlBorder),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.local_hospital_outlined, color: AppColors.errorText, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'If you feel your symptoms need urgent care, contact your local emergency services or go to the nearest hospital now. SUSTHITI is not monitored in real time.',
                      style: t.bodySmall?.copyWith(color: AppColors.errorText),
                    ),
                  ),
                ]),
              ),
            AppTextField(label: 'Related medicine', controller: _medication, optional: true, hint: 'e.g. Metformin'),
            DateTimeField(label: 'When did it start?', value: _at, includeTime: true, onChanged: (d) => setState(() => _at = d), validator: (d) => Validators.notFuture(d, 'Time')),
            AppTextField(label: 'Notes', controller: _notes, optional: true, maxLines: 3, textCapitalization: TextCapitalization.sentences),
            const SizedBox(height: AppSpacing.sm),
            BusyButton(label: 'Submit report', onPressed: _submit, expand: true),
            const Disclaimer(),
          ]),
        ),
      ]),
    );
  }
}

class SideEffectDetailScreen extends ConsumerWidget {
  const SideEffectDetailScreen({super.key, required this.patientId, required this.sideEffectId});
  final String patientId;
  final String sideEffectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(sideEffectProvider(sideEffectId));
    final isDoctor = ref.watch(currentUserProvider)?.role == UserRole.doctor;
    final t = Theme.of(context).textTheme;
    void refresh() {
      ref.invalidate(sideEffectProvider(sideEffectId));
      ref.invalidate(sideEffectsProvider(patientId));
    }

    return AppPage(
      title: 'Side Effect',
      body: PageBody(maxWidth: 760, onRefresh: () async => refresh(), children: [
        AsyncBody(
          value: value,
          onRetry: refresh,
          data: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                  StatusPill(s.status.label, tone: s.status.tone),
                  StatusPill(s.severity.label, tone: s.severity.tone),
                  if (s.priorityFlag) const StatusPill('Priority', tone: StatusTone.critical),
                ]),
                const SizedBox(height: AppSpacing.md),
                Text(s.description, style: t.titleMedium),
                const SizedBox(height: AppSpacing.md),
                KeyValueRow('Reference', s.code),
                KeyValueRow('Started', Fmt.dateTime(s.occurredAt)),
                KeyValueRow('Related medicine', s.relatedMedication ?? 'Not specified'),
                if (s.notes != null) KeyValueRow('Notes', s.notes!),
                KeyValueRow('Reported', Fmt.dateTime(s.createdAt)),
                if (s.priorityFlag) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text('Marked as priority because the patient selected ${s.severity.label.toLowerCase()} severity. This is not a clinical judgement.', style: t.bodySmall),
                ],
              ]),
            ),
            if (isDoctor && s.status != SideEffectStatus.resolved) ...[
              const SizedBox(height: AppSpacing.lg),
              _DoctorActions(effect: s, onChanged: refresh),
            ],
            const SizedBox(height: AppSpacing.section),
            const SectionHeader('History'),
            AppCard(
              child: Column(children: [
                for (var i = 0; i < s.history.length; i++) _HistoryEvent(event: s.history[i], isLast: i == s.history.length - 1),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _HistoryEvent extends StatelessWidget {
  const _HistoryEvent({required this.event, required this.isLast});
  final SideEffectEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = event;
    final who = e.actorRole == 'doctor' ? 'Dr. ${e.actorName}' : e.actorName;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: e.status.tone.indicator, shape: BoxShape.circle)),
          if (!isLast) Expanded(child: Container(width: 2, color: AppColors.border)),
        ]),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.response?.label ?? e.status.label, style: t.titleSmall),
              Text('$who · ${Fmt.dateTime(e.createdAt)}', style: t.bodySmall),
              if (e.message != null && e.message!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(e.message!, style: t.bodyMedium),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

/// The doctor chooses the response. Nothing here is suggested by AI.
class _DoctorActions extends ConsumerWidget {
  const _DoctorActions({required this.effect, required this.onChanged});
  final SideEffect effect;
  final VoidCallback onChanged;

  Future<void> _setStatus(BuildContext context, WidgetRef ref, SideEffectStatus status) async {
    try {
      await ref.read(sideEffectRepositoryProvider).setStatus(effect.id, status);
      onChanged();
      if (context.mounted) showToast(context, status == SideEffectStatus.resolved ? 'Marked as resolved' : 'Marked as under review');
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      tinted: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Doctor actions', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          FilledButton.icon(
            onPressed: () async {
              final done = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _RespondSheet(effect: effect));
              if (done == true) {
                onChanged();
                if (context.mounted) showToast(context, 'Response sent to the patient');
              }
            },
            icon: const Icon(Icons.reply_outlined),
            label: const Text('Respond'),
          ),
          if (effect.status == SideEffectStatus.newReport)
            OutlinedButton(onPressed: () => _setStatus(context, ref, SideEffectStatus.underReview), child: const Text('Mark under review')),
          OutlinedButton(onPressed: () => _setStatus(context, ref, SideEffectStatus.resolved), child: const Text('Mark resolved')),
        ]),
      ]),
    );
  }
}

class _RespondSheet extends ConsumerStatefulWidget {
  const _RespondSheet({required this.effect});
  final SideEffect effect;

  @override
  ConsumerState<_RespondSheet> createState() => _RespondSheetState();
}

class _RespondSheetState extends ConsumerState<_RespondSheet> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  final _reason = TextEditingController();
  DoctorResponse? _response;
  DateTime? _appointmentFor;

  @override
  void dispose() {
    _message.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final appointment = _response == DoctorResponse.appointmentRecommended;
    try {
      await ref.read(sideEffectRepositoryProvider).respond(
            widget.effect.id,
            response: _response!,
            message: _message.text.trim().isEmpty ? null : _message.text.trim(),
            appointmentReason: appointment ? _reason.text.trim() : null,
            appointmentFor: appointment ? _appointmentFor : null,
          );
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SheetForm(
      title: 'Respond to ${widget.effect.code}',
      form: _form,
      children: [
        ChoiceField<DoctorResponse>(label: 'Response', options: DoctorResponse.values, value: _response, labelOf: (r) => r.label, onChanged: (r) => setState(() => _response = r)),
        AppTextField(label: 'Message to patient', controller: _message, optional: _response != DoctorResponse.urgentMedicalAttention, maxLines: 3, textCapitalization: TextCapitalization.sentences,
            validator: (v) => _response == DoctorResponse.urgentMedicalAttention && (v == null || v.trim().isEmpty) ? 'Tell the patient what to do next.' : null),
        if (_response == DoctorResponse.appointmentRecommended) ...[
          AppTextField(label: 'Appointment reason', controller: _reason, validator: (v) => Validators.required(v, 'Reason'), textCapitalization: TextCapitalization.sentences),
          DateTimeField(
            label: 'Suggested date',
            optional: true,
            value: _appointmentFor,
            firstDate: now,
            lastDate: now.add(const Duration(days: 365)),
            onChanged: (d) => setState(() => _appointmentFor = d),
          ),
        ],
        BusyButton(label: 'Send response', onPressed: _send, expand: true),
      ],
    );
  }
}
