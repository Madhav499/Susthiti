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

final followUpTasksProvider = FutureProvider.autoDispose.family<List<FollowUpTask>, String>(
  (ref, pid) => ref.watch(patientRepositoryProvider).followUps(pid),
);

class FollowUpsScreen extends StatelessWidget {
  const FollowUpsScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context) => AppPage(title: 'Follow-ups', body: FollowUpsView(patientId: patientId));
}

/// Patient: read-only. Doctor: can schedule, complete, cancel and reschedule a follow-up task
/// for any patient they have approved access to.
class FollowUpsView extends ConsumerWidget {
  const FollowUpsView({super.key, required this.patientId, this.embedded = false});
  final String patientId;
  final bool embedded;

  static int _rank(FollowUpTask f) => switch (f.status) {
        FollowUpStatus.scheduled => f.isOverdue ? 1 : 0,
        FollowUpStatus.completed => 2,
        FollowUpStatus.cancelled => 3,
      };

  /// Upcoming first, then overdue-but-still-scheduled, then completed, then cancelled.
  static List<FollowUpTask> _sorted(List<FollowUpTask> items) => [...items]..sort((a, b) {
      final r = _rank(a).compareTo(_rank(b));
      return r != 0 ? r : a.dueDate.compareTo(b.dueDate);
    });

  Future<void> _schedule(BuildContext context, WidgetRef ref) async {
    final done = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _ScheduleSheet(patientId: patientId));
    if (done == true) ref.invalidate(followUpTasksProvider(patientId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDoctor = ref.watch(currentUserProvider)?.role == UserRole.doctor;
    final value = ref.watch(followUpTasksProvider(patientId));

    final content = AsyncBody(
      value: value,
      onRetry: () => ref.invalidate(followUpTasksProvider(patientId)),
      data: (items) => items.isEmpty
          ? EmptyState(
              icon: Icons.event_repeat_outlined,
              title: 'No follow-ups scheduled.',
              compact: embedded,
              actionLabel: isDoctor ? 'Schedule Follow-up' : null,
              onAction: isDoctor ? () => _schedule(context, ref) : null,
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (isDoctor) ...[
                Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _schedule(context, ref), icon: const Icon(Icons.add), label: const Text('Schedule Follow-up'))),
                const SizedBox(height: AppSpacing.md),
              ],
              for (final f in _sorted(items)) ...[
                _FollowUpCard(followUp: f, isDoctor: isDoctor, onChanged: () => ref.invalidate(followUpTasksProvider(patientId))),
                const SizedBox(height: AppSpacing.sm),
              ],
            ]),
    );

    if (embedded) {
      return PageBody(maxWidth: 860, padding: EdgeInsets.zero, onRefresh: () async => ref.invalidate(followUpTasksProvider(patientId)), children: [content]);
    }
    return PageBody(maxWidth: 760, onRefresh: () async => ref.invalidate(followUpTasksProvider(patientId)), children: [content]);
  }
}

class _FollowUpCard extends ConsumerWidget {
  const _FollowUpCard({required this.followUp, required this.isDoctor, required this.onChanged});
  final FollowUpTask followUp;
  final bool isDoctor;
  final VoidCallback onChanged;

  Future<void> _act(BuildContext context, WidgetRef ref, Future<void> Function() action, String success) async {
    try {
      await action();
      onChanged();
      if (context.mounted) showToast(context, success);
    } on Failure catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(context, title: 'Mark as completed?', message: 'This follow-up will be marked as done.', confirmLabel: 'Mark Completed');
    if (!context.mounted || !ok) return;
    await _act(context, ref, () => ref.read(doctorRepositoryProvider).completeFollowUp(followUp.id), 'Follow-up marked completed');
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(context, title: 'Cancel this follow-up?', message: 'The patient will be notified that it was cancelled.', confirmLabel: 'Cancel Follow-up', destructive: true);
    if (!context.mounted || !ok) return;
    await _act(context, ref, () => ref.read(doctorRepositoryProvider).cancelFollowUp(followUp.id), 'Follow-up cancelled');
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref) async {
    final done = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _RescheduleSheet(followUp: followUp));
    if (done == true) onChanged();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final f = followUp;
    final tone = f.isOverdue ? StatusTone.attention : f.status.tone;
    final statusLabel = f.isOverdue ? 'Overdue' : f.status.label;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(Icons.event_repeat_outlined),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(f.purpose, style: t.titleSmall)), StatusPill(statusLabel, tone: tone)]),
              const SizedBox(height: 2),
              Text('Dr. ${f.doctorName} · Due ${Fmt.date(f.dueDate)}', style: t.bodySmall),
              if (f.notes != null && f.notes!.isNotEmpty) ...[const SizedBox(height: 4), Text(f.notes!, style: t.bodySmall?.copyWith(color: AppColors.textSecondary))],
            ]),
          ),
        ]),
        if (isDoctor && f.status == FollowUpStatus.scheduled) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            OutlinedButton(onPressed: () => _complete(context, ref), child: const Text('Mark Completed')),
            OutlinedButton(onPressed: () => _reschedule(context, ref), child: const Text('Reschedule')),
            TextButton(onPressed: () => _cancel(context, ref), child: const Text('Cancel')),
          ]),
        ],
      ]),
    );
  }
}

class _ScheduleSheet extends ConsumerStatefulWidget {
  const _ScheduleSheet({required this.patientId});
  final String patientId;

  @override
  ConsumerState<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends ConsumerState<_ScheduleSheet> {
  final _form = GlobalKey<FormState>();
  final _purpose = TextEditingController();
  DateTime? _due;

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _due == null) return;
    try {
      await ref.read(doctorRepositoryProvider).createFollowUp(widget.patientId, purpose: _purpose.text, dueDate: _due!);
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SheetForm(title: 'Schedule Follow-up', form: _form, children: [
      AppTextField(label: 'Purpose', controller: _purpose, maxLines: 2, validator: (v) => Validators.required(v, 'Purpose'), textCapitalization: TextCapitalization.sentences),
      const SizedBox(height: AppSpacing.md),
      DateTimeField(label: 'Due date', value: _due, firstDate: now, lastDate: now.add(const Duration(days: 365)), onChanged: (d) => setState(() => _due = d)),
      const SizedBox(height: AppSpacing.lg),
      BusyButton(label: 'Schedule Follow-up', onPressed: _save, expand: true),
    ]);
  }
}

class _RescheduleSheet extends ConsumerStatefulWidget {
  const _RescheduleSheet({required this.followUp});
  final FollowUpTask followUp;

  @override
  ConsumerState<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends ConsumerState<_RescheduleSheet> {
  late DateTime? _due = widget.followUp.dueDate;

  Future<void> _save() async {
    if (_due == null) return;
    try {
      await ref.read(doctorRepositoryProvider).rescheduleFollowUp(widget.followUp.id, _due!);
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SheetForm(title: 'Reschedule Follow-up', form: GlobalKey<FormState>(), children: [
      Text(widget.followUp.purpose, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: AppSpacing.md),
      DateTimeField(label: 'New due date', value: _due, firstDate: now, lastDate: now.add(const Duration(days: 365)), onChanged: (d) => setState(() => _due = d)),
      const SizedBox(height: AppSpacing.lg),
      BusyButton(label: 'Save New Date', onPressed: _save, expand: true),
    ]);
  }
}
