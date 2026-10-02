import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/debouncer.dart';
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

typedef PrescriptionsKey = ({String patientId, String query});

final prescriptionsProvider = FutureProvider.autoDispose.family<List<Prescription>, PrescriptionsKey>(
  (ref, k) => ref.watch(prescriptionRepositoryProvider).list(k.patientId, query: k.query),
);
final prescriptionProvider = FutureProvider.autoDispose.family<Prescription, String>((ref, id) => ref.watch(prescriptionRepositoryProvider).get(id));

class PrescriptionsScreen extends ConsumerWidget {
  const PrescriptionsScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDoctor = ref.watch(currentUserProvider)?.role == UserRole.doctor;
    return AppPage(
      title: 'Prescriptions',
      floatingActionButton: isDoctor
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/d/patients/$patientId/prescriptions/new'),
              icon: const Icon(Icons.add),
              label: const Text('New Prescription'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 1,
            )
          : null,
      body: PrescriptionsView(patientId: patientId),
    );
  }
}

class PrescriptionsView extends ConsumerStatefulWidget {
  const PrescriptionsView({super.key, required this.patientId, this.embedded = false});
  final String patientId;
  final bool embedded;

  @override
  ConsumerState<PrescriptionsView> createState() => _PrescriptionsViewState();
}

class _PrescriptionsViewState extends ConsumerState<PrescriptionsView> {
  final _debouncer = Debouncer();
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _debouncer.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = (patientId: widget.patientId, query: _query);
    final value = ref.watch(prescriptionsProvider(key));
    return PageBody(
      maxWidth: 820,
      padding: widget.embedded ? const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xxl) : null,
      onRefresh: () async => ref.invalidate(prescriptionsProvider(key)),
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: 'Search by medicine, doctor or ID',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
          onChanged: (v) => _debouncer(() => setState(() => _query = v.trim())),
        ),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: value,
          onRetry: () => ref.invalidate(prescriptionsProvider(key)),
          data: (items) => items.isEmpty
              ? EmptyState(
                  icon: Icons.medication_outlined,
                  title: _query.isEmpty ? 'No prescriptions yet.' : 'No prescriptions match "$_query".',
                  message: _query.isEmpty ? 'Prescriptions from your doctor will appear here.' : null,
                )
              : Column(children: [
                  for (final p in items) ...[
                    PrescriptionTile(prescription: p, onTap: () => context.push('/r/${widget.patientId}/prescriptions/${p.id}')),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ]),
        ),
      ],
    );
  }
}

class PrescriptionTile extends StatelessWidget {
  const PrescriptionTile({super.key, required this.prescription, required this.onTap});
  final Prescription prescription;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = prescription;
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        const IconBadge(Icons.medication_outlined),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.medicines.map((m) => m.medicine).join(', '), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
            const SizedBox(height: 2),
            Text('Dr. ${p.doctorName} · ${Fmt.date(p.prescribedOn)} · ${p.code}', style: t.bodySmall),
            if (p.followUpDate != null) Text('Follow-up ${Fmt.date(p.followUpDate)}', style: t.bodySmall?.copyWith(color: AppColors.primary)),
          ]),
        ),
        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ]),
    );
  }
}

class PrescriptionDetailScreen extends ConsumerWidget {
  const PrescriptionDetailScreen({super.key, required this.prescriptionId});
  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'Prescription',
      body: PageBody(maxWidth: 760, children: [
        AsyncBody(
          value: ref.watch(prescriptionProvider(prescriptionId)),
          onRetry: () => ref.invalidate(prescriptionProvider(prescriptionId)),
          data: (p) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                KeyValueRow('Prescription ID', p.code),
                KeyValueRow('Doctor', 'Dr. ${p.doctorName}'),
                KeyValueRow('Date', Fmt.date(p.prescribedOn)),
                if (p.followUpDate != null) KeyValueRow('Follow-up', Fmt.date(p.followUpDate)),
              ]),
            ),
            const SizedBox(height: AppSpacing.section),
            const SectionHeader('Medicines'),
            for (final m in p.medicines) ...[
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.medicine, style: t.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  KeyValueRow('Dosage', m.dosage),
                  KeyValueRow('Frequency', m.frequency),
                  KeyValueRow('Duration', m.duration),
                  if (m.instructions != null && m.instructions!.isNotEmpty) KeyValueRow('Instructions', m.instructions!),
                ]),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if ((p.instructions ?? '').isNotEmpty || (p.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if ((p.instructions ?? '').isNotEmpty) ...[Text('Instructions', style: t.titleSmall), const SizedBox(height: 4), Text(p.instructions!, style: t.bodyMedium)],
                  if ((p.notes ?? '').isNotEmpty) ...[const SizedBox(height: AppSpacing.md), Text('Notes', style: t.titleSmall), const SizedBox(height: 4), Text(p.notes!, style: t.bodyMedium)],
                ]),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text('Prescriptions are never edited. A change is issued as a new prescription.', style: t.bodySmall),
          ]),
        ),
      ]),
    );
  }
}

class _MedicineDraft {
  final medicine = TextEditingController();
  final dosage = TextEditingController();
  final frequency = TextEditingController();
  final duration = TextEditingController();
  final instructions = TextEditingController();

  void dispose() {
    for (final c in [medicine, dosage, frequency, duration, instructions]) {
      c.dispose();
    }
  }

  Medicine toMedicine() => Medicine(
        medicine: medicine.text.trim(),
        dosage: dosage.text.trim(),
        frequency: frequency.text.trim(),
        duration: duration.text.trim(),
        instructions: instructions.text.trim().isEmpty ? null : instructions.text.trim(),
      );
}

/// Doctor creates a structured prescription (one row per medicine).
class CreatePrescriptionScreen extends ConsumerStatefulWidget {
  const CreatePrescriptionScreen({super.key, required this.patientId});
  final String patientId;

  @override
  ConsumerState<CreatePrescriptionScreen> createState() => _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState extends ConsumerState<CreatePrescriptionScreen> {
  final _form = GlobalKey<FormState>();
  final _medicines = [_MedicineDraft()];
  final _instructions = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _date = DateTime.now();
  DateTime? _followUp;

  @override
  void dispose() {
    for (final m in _medicines) {
      m.dispose();
    }
    _instructions.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      final p = await ref.read(prescriptionRepositoryProvider).create(
            widget.patientId,
            prescribedOn: _date!,
            medicines: [for (final m in _medicines) m.toMedicine()],
            instructions: _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            followUpDate: _followUp,
          );
      ref.invalidate(prescriptionsProvider);
      if (!mounted) return;
      showToast(context, 'Prescription ${p.code} created');
      context.pop();
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    return AppPage(
      title: 'New Prescription',
      body: PageBody(maxWidth: 760, children: [
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DateTimeField(label: 'Prescription date', value: _date, onChanged: (d) => setState(() => _date = d), validator: (d) => Validators.notFuture(d, 'Prescription date')),
            const SectionHeader('Medicines'),
            for (var i = 0; i < _medicines.length; i++) ...[
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text('Medicine ${i + 1}', style: t.titleSmall)),
                    if (_medicines.length > 1)
                      IconButton(
                        tooltip: 'Remove medicine',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => _medicines.removeAt(i).dispose()),
                      ),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(label: 'Medicine', controller: _medicines[i].medicine, validator: (v) => Validators.required(v, 'Medicine')),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: AppTextField(label: 'Dosage', hint: 'e.g. 500 mg', controller: _medicines[i].dosage, validator: (v) => Validators.required(v, 'Dosage'))),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: AppTextField(label: 'Frequency', hint: 'e.g. Twice daily', controller: _medicines[i].frequency, validator: (v) => Validators.required(v, 'Frequency'))),
                  ]),
                  AppTextField(label: 'Duration', hint: 'e.g. 30 days', controller: _medicines[i].duration, validator: (v) => Validators.required(v, 'Duration')),
                  AppTextField(label: 'Instructions', hint: 'e.g. After meals', controller: _medicines[i].instructions, optional: true),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: () => setState(() => _medicines.add(_MedicineDraft())), icon: const Icon(Icons.add), label: const Text('Add medicine')),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(label: 'General instructions', controller: _instructions, optional: true, maxLines: 3, textCapitalization: TextCapitalization.sentences),
            AppTextField(label: 'Notes', controller: _notes, optional: true, maxLines: 3, textCapitalization: TextCapitalization.sentences),
            DateTimeField(label: 'Follow-up date', optional: true, value: _followUp, firstDate: now, lastDate: now.add(const Duration(days: 730)), onChanged: (d) => setState(() => _followUp = d)),
            const SizedBox(height: AppSpacing.sm),
            BusyButton(label: 'Create prescription', onPressed: _save, expand: true),
            const SizedBox(height: AppSpacing.md),
            Text('The patient is notified. Earlier prescriptions stay unchanged.', style: t.bodySmall),
          ]),
        ),
      ]),
    );
  }
}
