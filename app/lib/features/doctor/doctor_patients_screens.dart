import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../data/models/patient.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../access/access_screens.dart';
import '../notifications/notifications.dart';
import 'doctor_patient_detail_screen.dart';

typedef DoctorPatientsKey = ({String query, String filter});

final doctorPatientsProvider = FutureProvider.autoDispose.family<List<DoctorPatientSummary>, DoctorPatientsKey>(
  (ref, k) => ref.watch(doctorRepositoryProvider).patients(query: k.query, filter: k.filter),
);

const doctorPatientFilters = {'all': 'All', 'recent_activity': 'Recent activity', 'follow_up': 'Follow-up due', 'side_effects': 'Side effects'};

class DoctorPatientsScreen extends ConsumerStatefulWidget {
  const DoctorPatientsScreen({super.key, this.initialFilter = 'all'});
  final String initialFilter;

  @override
  ConsumerState<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends ConsumerState<DoctorPatientsScreen> {
  final _debouncer = Debouncer();
  final _search = TextEditingController();
  String _query = '';
  late String _filter = doctorPatientFilters.containsKey(widget.initialFilter) ? widget.initialFilter : 'all';

  /// Desktop list | details: the selected patient shows beside the list.
  String? _selected;

  @override
  void didUpdateWidget(DoctorPatientsScreen old) {
    super.didUpdateWidget(old);
    if (old.initialFilter != widget.initialFilter && doctorPatientFilters.containsKey(widget.initialFilter)) _filter = widget.initialFilter;
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = (query: _query, filter: _filter);
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'Patients',
      large: true,
      actions: const [NotificationBell()],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/d/patients/add'),
        icon: const Icon(Icons.person_add_alt_outlined),
        label: const Text('Add Patient'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: context.screenSize != ScreenSize.desktop
          ? _list(key, t, push: true)
          : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: 420, child: _list(key, t, push: false)),
              const VerticalDivider(width: 1),
              Expanded(
                child: _selected == null
                    ? const Center(child: EmptyState(icon: Icons.people_outline, title: 'Select a patient', message: 'Their overview, records and lifestyle data appear here.'))
                    : DoctorPatientDetailScreen(key: ValueKey(_selected), patientId: _selected!),
              ),
            ]),
    );
  }

  Widget _list(DoctorPatientsKey key, TextTheme t, {required bool push}) {
    return PageBody(maxWidth: 900, onRefresh: () async => ref.invalidate(doctorPatientsProvider(key)), children: [
        TextField(
          controller: _search,
          decoration: const InputDecoration(hintText: 'Search by name or Patient ID', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => _debouncer(() => setState(() => _query = v.trim())),
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final e in doctorPatientFilters.entries)
              Padding(padding: const EdgeInsets.only(right: AppSpacing.sm), child: ChoiceChip(label: Text(e.value), selected: _filter == e.key, onSelected: (_) => setState(() => _filter = e.key))),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: ref.watch(doctorPatientsProvider(key)),
          onRetry: () => ref.invalidate(doctorPatientsProvider(key)),
          data: (items) => items.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline,
                  title: _query.isEmpty && _filter == 'all' ? 'No patients yet.' : 'No patients match.',
                  message: _query.isEmpty && _filter == 'all' ? 'Request access with the patient\'s name and Patient ID. They approve it in their app.' : null,
                  actionLabel: _query.isEmpty && _filter == 'all' ? 'Add Patient' : null,
                  onAction: () => context.push('/d/patients/add'),
                )
              : Column(children: [
                  for (final p in items) ...[
                    AppCard(
                      tinted: !push && p.id == _selected,
                      onTap: push ? () => context.push('/d/patients/${p.id}') : () => setState(() => _selected = p.id),
                      child: Row(children: [
                        CircleAvatar(backgroundColor: AppColors.primarySoft, child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.name, style: t.titleSmall),
                            Text([p.patientCode, if (p.age != null) '${p.age} yrs', ?p.gender].join(' · '), style: t.bodySmall),
                            if (p.lastActivityAt != null) Text('Last activity ${Fmt.relative(p.lastActivityAt)}', style: t.bodySmall),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          if (p.openSideEffects > 0) StatusPill('${p.openSideEffects} side effect${p.openSideEffects == 1 ? '' : 's'}', tone: StatusTone.attention),
                          if (p.nextFollowUp != null) ...[const SizedBox(height: 4), Text('Follow-up ${Fmt.shortDate(p.nextFollowUp)}', style: t.labelMedium?.copyWith(color: AppColors.primary))],
                        ]),
                        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      ]),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ]),
        ),
      ]);
  }
}

/// Doctor requests access with the patient's name AND Patient ID. Both must match; the patient
/// then approves or rejects in their own app. Error wording never reveals whether an ID exists.
class AddPatientScreen extends ConsumerStatefulWidget {
  const AddPatientScreen({super.key});

  @override
  ConsumerState<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends ConsumerState<AddPatientScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _message = TextEditingController();
  AccessRequest? _sent;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    try {
      final r = await ref.read(doctorRepositoryProvider).requestAccess(patientName: _name.text, patientCode: _code.text, message: _message.text);
      ref.invalidate(accessRequestsProvider(UserRole.doctor));
      setState(() => _sent = r);
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'Add Patient',
      body: PageBody(maxWidth: 560, children: [
        if (_sent != null)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconBadge(Icons.mark_email_read_outlined, tone: StatusTone.positive),
              const SizedBox(height: AppSpacing.md),
              Text('Request sent', style: t.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text('${_sent!.patientName} (${_sent!.patientCode}) will be asked to approve your request. You will be notified when they respond.', style: t.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              Wrap(spacing: AppSpacing.sm, children: [
                FilledButton(onPressed: () => context.go('/d/requests'), child: const Text('View requests')),
                OutlinedButton(
                  onPressed: () {
                    _name.clear();
                    _code.clear();
                    _message.clear();
                    setState(() => _sent = null);
                  },
                  child: const Text('Add another'),
                ),
              ]),
            ]),
          )
        else
          Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Enter the patient\'s full name and Patient ID exactly as shown in their SUSTHITI profile. The patient must approve before you can see any records.', style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(label: 'Patient full name', controller: _name, validator: (v) => Validators.required(v, 'Patient name'), textCapitalization: TextCapitalization.words),
              LabeledField(
                label: 'Patient ID',
                child: TextFormField(
                  controller: _code,
                  validator: Validators.patientId,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')), _UpperCaseFormatter()],
                  decoration: const InputDecoration(hintText: 'SUS-P-XXXXXX'),
                ),
              ),
              AppTextField(label: 'Message to patient', controller: _message, optional: true, maxLines: 3, textCapitalization: TextCapitalization.sentences),
              BusyButton(label: 'Send access request', onPressed: _submit, expand: true),
            ]),
          ),
      ]),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) => newValue.copyWith(text: newValue.text.toUpperCase());
}
