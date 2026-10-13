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
import '../../l10n/app_localizations.dart';
import '../access/access_screens.dart';
import '../notifications/notifications.dart';
import 'doctor_patient_detail_screen.dart';

typedef DoctorPatientsKey = ({String query, String filter});

final doctorPatientsProvider = FutureProvider.autoDispose.family<List<DoctorPatientSummary>, DoctorPatientsKey>(
  (ref, k) => ref.watch(doctorRepositoryProvider).patients(query: k.query, filter: k.filter),
);

const doctorPatientFilterKeys = ['all', 'recent_activity', 'follow_up', 'side_effects'];

Map<String, String> doctorPatientFilterLabels(AppLocalizations l10n) =>
    {'all': l10n.notifFilterAll, 'recent_activity': l10n.doctorFilterRecentActivity, 'follow_up': l10n.doctorFilterFollowUpDue, 'side_effects': l10n.navSideEffects};

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
  late String _filter = doctorPatientFilterKeys.contains(widget.initialFilter) ? widget.initialFilter : 'all';

  /// Desktop list | details: the selected patient shows beside the list.
  String? _selected;

  @override
  void didUpdateWidget(DoctorPatientsScreen old) {
    super.didUpdateWidget(old);
    if (old.initialFilter != widget.initialFilter && doctorPatientFilterKeys.contains(widget.initialFilter)) _filter = widget.initialFilter;
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final key = (query: _query, filter: _filter);
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: l10n.navPatients,
      large: true,
      actions: [IconButton(tooltip: l10n.doctorScanPatientQrTooltip, onPressed: () => context.push('/d/scan'), icon: const Icon(Icons.qr_code_scanner_outlined)), const NotificationBell()],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/d/patients/add'),
        icon: const Icon(Icons.person_add_alt_outlined),
        label: Text(l10n.navAddPatient),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: context.screenSize != ScreenSize.desktop
          ? _list(l10n, key, t, push: true)
          : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: 420, child: _list(l10n, key, t, push: false)),
              const VerticalDivider(width: 1),
              Expanded(
                child: _selected == null
                    ? Center(child: EmptyState(icon: Icons.people_outline, title: l10n.doctorSelectPatientTitle, message: l10n.doctorSelectPatientMessage))
                    : DoctorPatientDetailScreen(key: ValueKey(_selected), patientId: _selected!),
              ),
            ]),
    );
  }

  Widget _list(AppLocalizations l10n, DoctorPatientsKey key, TextTheme t, {required bool push}) {
    final filterLabels = doctorPatientFilterLabels(l10n);
    return PageBody(maxWidth: 900, onRefresh: () async => ref.invalidate(doctorPatientsProvider(key)), children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(hintText: l10n.doctorSearchHint, prefixIcon: const Icon(Icons.search)),
          onChanged: (v) => _debouncer(() => setState(() => _query = v.trim())),
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final key in doctorPatientFilterKeys)
              Padding(padding: const EdgeInsets.only(right: AppSpacing.sm), child: ChoiceChip(label: Text(filterLabels[key]!), selected: _filter == key, onSelected: (_) => setState(() => _filter = key))),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: ref.watch(doctorPatientsProvider(key)),
          onRetry: () => ref.invalidate(doctorPatientsProvider(key)),
          data: (items) => items.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline,
                  title: _query.isEmpty && _filter == 'all' ? l10n.doctorNoPatientsYet : l10n.doctorNoPatientsMatch,
                  message: _query.isEmpty && _filter == 'all' ? l10n.doctorNoPatientsMessage : null,
                  actionLabel: _query.isEmpty && _filter == 'all' ? l10n.navAddPatient : null,
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
                            if (p.lastActivityAt != null) Text(l10n.doctorLastActivityLabel(Fmt.relative(l10n, p.lastActivityAt)), style: t.bodySmall),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          if (p.openSideEffects > 0) StatusPill(l10n.doctorSideEffectsCountPill(p.openSideEffects), tone: StatusTone.attention),
                          if (p.nextFollowUp != null) ...[const SizedBox(height: 4), Text(l10n.doctorFollowUpShortDate(Fmt.shortDate(p.nextFollowUp)), style: t.labelMedium?.copyWith(color: AppColors.primary))],
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

  Future<void> _submit(AppLocalizations l10n) async {
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
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: l10n.navAddPatient,
      actions: [IconButton(tooltip: l10n.doctorScanPatientQrTooltip, onPressed: () => context.push('/d/scan'), icon: const Icon(Icons.qr_code_scanner_outlined))],
      body: PageBody(maxWidth: 560, children: [
        if (_sent != null)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconBadge(Icons.mark_email_read_outlined, tone: StatusTone.positive),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.doctorRequestSentTitle, style: t.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.doctorRequestSentMessage(_sent!.patientName, _sent!.patientCode), style: t.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              Wrap(spacing: AppSpacing.sm, children: [
                FilledButton(onPressed: () => context.go('/d/requests'), child: Text(l10n.doctorViewRequestsButton)),
                OutlinedButton(
                  onPressed: () {
                    _name.clear();
                    _code.clear();
                    _message.clear();
                    setState(() => _sent = null);
                  },
                  child: Text(l10n.doctorAddAnotherButton),
                ),
              ]),
            ]),
          )
        else
          Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l10n.doctorAddPatientInstructions, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(label: l10n.doctorPatientFullNameLabel, controller: _name, validator: (v) => Validators.required(l10n, v, l10n.doctorPatientNameLabel), textCapitalization: TextCapitalization.words),
              LabeledField(
                label: l10n.doctorPatientIdLabel,
                child: TextFormField(
                  controller: _code,
                  validator: (v) => Validators.patientId(l10n, v),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')), _UpperCaseFormatter()],
                  decoration: const InputDecoration(hintText: 'SUS-P-XXXXXX'),
                ),
              ),
              AppTextField(label: l10n.doctorMessageToPatientLabel, controller: _message, optional: true, maxLines: 3, textCapitalization: TextCapitalization.sentences),
              BusyButton(label: l10n.doctorRequestAccessButton, onPressed: () => _submit(l10n), expand: true),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.push('/d/scan'),
                  icon: const Icon(Icons.qr_code_scanner_outlined, size: 18),
                  label: Text(l10n.doctorScanInsteadButton),
                ),
              ),
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
