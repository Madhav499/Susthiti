import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final surgeriesProvider = FutureProvider.autoDispose.family<List<Surgery>, String>(
  (ref, pid) => ref.watch(patientRepositoryProvider).surgeries(pid),
);

class SurgeryScreen extends StatelessWidget {
  const SurgeryScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context) => AppPage(title: 'Surgeries', body: SurgeriesView(patientId: patientId));
}

/// Patient: sees only patient-visible fields -- `internalNotes` is simply absent from the
/// backend's response for a patient's own request, never hidden only here. Doctor: full fields
/// plus schedule / edit / complete / cancel actions.
class SurgeriesView extends ConsumerWidget {
  const SurgeriesView({super.key, required this.patientId, this.embedded = false});
  final String patientId;
  final bool embedded;

  static int _rank(Surgery s) => switch (s.status) {
        FollowUpStatus.scheduled => s.isOverdue ? 1 : 0,
        FollowUpStatus.completed => 2,
        FollowUpStatus.cancelled => 3,
      };

  static List<Surgery> _sorted(List<Surgery> items) => [...items]..sort((a, b) {
      final r = _rank(a).compareTo(_rank(b));
      if (r != 0) return r;
      final ad = a.scheduledAt, bd = b.scheduledAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });

  Future<void> _schedule(BuildContext context, WidgetRef ref) async {
    final done = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _SurgeryFormSheet(patientId: patientId));
    if (done == true) ref.invalidate(surgeriesProvider(patientId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDoctor = ref.watch(currentUserProvider)?.role == UserRole.doctor;
    final value = ref.watch(surgeriesProvider(patientId));

    final content = AsyncBody(
      value: value,
      onRetry: () => ref.invalidate(surgeriesProvider(patientId)),
      data: (items) => items.isEmpty
          ? EmptyState(
              icon: Icons.local_hospital_outlined,
              title: 'No surgeries scheduled.',
              compact: embedded,
              actionLabel: isDoctor ? 'Schedule Surgery' : null,
              onAction: isDoctor ? () => _schedule(context, ref) : null,
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (isDoctor) ...[
                Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _schedule(context, ref), icon: const Icon(Icons.add), label: const Text('Schedule Surgery'))),
                const SizedBox(height: AppSpacing.md),
              ],
              for (final s in _sorted(items)) ...[
                _SurgeryCard(surgery: s, isDoctor: isDoctor, patientId: patientId, onChanged: () => ref.invalidate(surgeriesProvider(patientId))),
                const SizedBox(height: AppSpacing.sm),
              ],
            ]),
    );

    if (embedded) {
      return PageBody(maxWidth: 860, padding: EdgeInsets.zero, onRefresh: () async => ref.invalidate(surgeriesProvider(patientId)), children: [content]);
    }
    return PageBody(maxWidth: 760, onRefresh: () async => ref.invalidate(surgeriesProvider(patientId)), children: [content]);
  }
}

class _SurgeryCard extends ConsumerWidget {
  const _SurgeryCard({required this.surgery, required this.isDoctor, required this.patientId, required this.onChanged});
  final Surgery surgery;
  final bool isDoctor;
  final String patientId;
  final VoidCallback onChanged;

  Future<void> _act(BuildContext context, Future<void> Function() action, String success) async {
    try {
      await action();
      onChanged();
      if (context.mounted) showToast(context, success);
    } on Failure catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(context, title: 'Mark as completed?', message: 'This surgery will be marked as done.', confirmLabel: 'Mark Completed');
    if (!context.mounted || !ok) return;
    await _act(context, () => ref.read(doctorRepositoryProvider).completeSurgery(surgery.id), 'Surgery marked completed');
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(context, title: 'Cancel this surgery?', message: 'The patient will be notified that it was cancelled.', confirmLabel: 'Cancel Surgery', destructive: true);
    if (!context.mounted || !ok) return;
    await _act(context, () => ref.read(doctorRepositoryProvider).cancelSurgery(surgery.id), 'Surgery cancelled');
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final done = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _SurgeryFormSheet(patientId: patientId, existing: surgery));
    if (done == true) onChanged();
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref) async {
    final done = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _RescheduleSurgerySheet(surgery: surgery));
    if (done == true) onChanged();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final s = surgery;
    final tone = s.isOverdue ? StatusTone.attention : s.status.tone;
    final statusLabel = s.isOverdue ? 'Overdue' : s.status.label;
    final when = s.scheduledAt == null ? 'Date to be confirmed' : Fmt.dateTime(s.scheduledAt);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(Icons.local_hospital_outlined),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(s.name, style: t.titleSmall)), StatusPill(statusLabel, tone: tone)]),
              const SizedBox(height: 2),
              Text(s.purpose, style: t.bodyMedium),
              const SizedBox(height: 4),
              Text('Dr. ${s.doctorName} · $when', style: t.bodySmall),
              if (s.hospital != null && s.hospital!.isNotEmpty) Text(s.hospital!, style: t.bodySmall),
              if (s.patientInstructions != null && s.patientInstructions!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Instructions', style: t.labelMedium),
                Text(s.patientInstructions!, style: t.bodySmall),
              ],
              // Not gated on role: the backend already omits internal_notes entirely from a
              // patient's own response, so its mere presence here means it's safe to show.
              if (s.internalNotes != null && s.internalNotes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Internal notes (not shown to the patient)', style: t.labelMedium?.copyWith(color: AppColors.textSecondary)),
                Text(s.internalNotes!, style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ]),
          ),
        ]),
        if (isDoctor && s.status == FollowUpStatus.scheduled) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            OutlinedButton(onPressed: () => _edit(context, ref), child: const Text('Edit')),
            OutlinedButton(onPressed: () => _reschedule(context, ref), child: const Text('Reschedule')),
            OutlinedButton(onPressed: () => _complete(context, ref), child: const Text('Mark Completed')),
            TextButton(onPressed: () => _cancel(context, ref), child: const Text('Cancel')),
          ]),
        ],
      ]),
    );
  }
}

class _SurgeryFormSheet extends ConsumerStatefulWidget {
  const _SurgeryFormSheet({required this.patientId, this.existing});
  final String patientId;
  final Surgery? existing;

  @override
  ConsumerState<_SurgeryFormSheet> createState() => _SurgeryFormSheetState();
}

class _SurgeryFormSheetState extends ConsumerState<_SurgeryFormSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _purpose = TextEditingController(text: widget.existing?.purpose);
  late final _hospital = TextEditingController(text: widget.existing?.hospital);
  late final _instructions = TextEditingController(text: widget.existing?.patientInstructions);
  late final _notes = TextEditingController(text: widget.existing?.internalNotes);
  DateTime? _scheduledAt;

  @override
  void initState() {
    super.initState();
    _scheduledAt = widget.existing?.scheduledAt;
  }

  @override
  void dispose() {
    _name.dispose();
    _purpose.dispose();
    _hospital.dispose();
    _instructions.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      final existing = widget.existing;
      if (existing == null) {
        await ref.read(doctorRepositoryProvider).createSurgery(
              widget.patientId,
              name: _name.text,
              purpose: _purpose.text,
              scheduledAt: _scheduledAt,
              hospital: _hospital.text.trim().isEmpty ? null : _hospital.text,
              patientInstructions: _instructions.text.trim().isEmpty ? null : _instructions.text,
              internalNotes: _notes.text.trim().isEmpty ? null : _notes.text,
            );
      } else {
        await ref.read(doctorRepositoryProvider).updateSurgery(existing.id, {
          'name': _name.text.trim(),
          'purpose': _purpose.text.trim(),
          'hospital': _hospital.text.trim().isEmpty ? null : _hospital.text.trim(),
          'patient_instructions': _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
          'internal_notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        });
      }
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final editing = widget.existing != null;
    return SheetForm(title: editing ? 'Edit Surgery' : 'Schedule Surgery', form: _form, children: [
      AppTextField(label: 'Surgery name', controller: _name, validator: (v) => Validators.required(v, 'Surgery name'), textCapitalization: TextCapitalization.sentences),
      const SizedBox(height: AppSpacing.md),
      AppTextField(label: 'Purpose', controller: _purpose, maxLines: 2, validator: (v) => Validators.required(v, 'Purpose'), textCapitalization: TextCapitalization.sentences),
      const SizedBox(height: AppSpacing.md),
      if (!editing) ...[
        DateTimeField(label: 'Scheduled date and time', value: _scheduledAt, includeTime: true, optional: true, firstDate: now, lastDate: now.add(const Duration(days: 365)), onChanged: (d) => setState(() => _scheduledAt = d)),
        const SizedBox(height: AppSpacing.md),
      ],
      AppTextField(label: 'Hospital / location', controller: _hospital, optional: true),
      const SizedBox(height: AppSpacing.md),
      AppTextField(label: 'Patient-visible instructions', controller: _instructions, maxLines: 3, optional: true, helper: 'Shown to the patient (e.g. fasting instructions).', textCapitalization: TextCapitalization.sentences),
      const SizedBox(height: AppSpacing.md),
      AppTextField(label: 'Internal notes', controller: _notes, maxLines: 3, optional: true, helper: 'Never shown to the patient.', textCapitalization: TextCapitalization.sentences),
      const SizedBox(height: AppSpacing.lg),
      BusyButton(label: editing ? 'Save Changes' : 'Schedule Surgery', onPressed: _save, expand: true),
    ]);
  }
}

class _RescheduleSurgerySheet extends ConsumerStatefulWidget {
  const _RescheduleSurgerySheet({required this.surgery});
  final Surgery surgery;

  @override
  ConsumerState<_RescheduleSurgerySheet> createState() => _RescheduleSurgerySheetState();
}

class _RescheduleSurgerySheetState extends ConsumerState<_RescheduleSurgerySheet> {
  late DateTime? _scheduledAt = widget.surgery.scheduledAt ?? DateTime.now().add(const Duration(days: 1));

  Future<void> _save() async {
    if (_scheduledAt == null) return;
    try {
      await ref.read(doctorRepositoryProvider).rescheduleSurgery(widget.surgery.id, _scheduledAt!);
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SheetForm(title: 'Reschedule Surgery', form: GlobalKey<FormState>(), children: [
      Text(widget.surgery.name, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: AppSpacing.md),
      DateTimeField(label: 'New date and time', value: _scheduledAt, includeTime: true, firstDate: now, lastDate: now.add(const Duration(days: 365)), onChanged: (d) => setState(() => _scheduledAt = d)),
      const SizedBox(height: AppSpacing.lg),
      BusyButton(label: 'Save New Date', onPressed: _save, expand: true),
    ]);
  }
}
