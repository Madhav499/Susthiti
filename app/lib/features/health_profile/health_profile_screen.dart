import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/health_data.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../authentication/auth_controller.dart';
import '../diabetes/diabetes_providers.dart';
import '../patient/patient_sync.dart';
import 'body_card.dart';
import 'profile_field_editor.dart';

/// The patient's health profile, kept once in SUSTHITI and reused by every health feature
/// (including the future diabetes risk estimate). Answers are appended, never overwritten.
class HealthProfileScreen extends ConsumerWidget {
  const HealthProfileScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(healthProfileProvider(patientId));
    return AppPage(
      title: 'Health profile',
      body: AsyncBody(
        value: value,
        onRetry: () => ref.invalidate(healthProfileProvider(patientId)),
        // A fresh form for every loaded version of the profile.
        data: (profile) => _HealthProfileForm(key: ObjectKey(profile), patientId: patientId, profile: profile),
      ),
    );
  }
}

class _HealthProfileForm extends ConsumerStatefulWidget {
  const _HealthProfileForm({super.key, required this.patientId, required this.profile});
  final String patientId;
  final HealthProfile profile;

  @override
  ConsumerState<_HealthProfileForm> createState() => _HealthProfileFormState();
}

class _HealthProfileFormState extends ConsumerState<_HealthProfileForm> {
  late final ProfileAnswers _answers = ProfileAnswers(widget.profile);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _answers.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = _answers.changes();
    setState(() => _error = result.error);
    if (result.error != null || result.values.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(patientRepositoryProvider).updateHealthProfile(widget.patientId, result.values);
      healthDataChanged(ref, widget.patientId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Health profile saved.')));
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final role = ref.watch(currentUserProvider)?.role;
    final canEdit = role == UserRole.patient || role == UserRole.doctor;
    // A patient can edit their own answers but never a doctor-only field (e.g. doctor-documented
    // restrictions): the backend rejects that write outright, so the field is disabled here
    // instead of letting a patient type into it and hit a confusing whole-form save error.
    bool canEditField(HealthProfileField f) => canEdit && !(f.doctorOnly && role == UserRole.patient);
    return PageBody(maxWidth: 760, children: [
      Text(
        'SUSTHITI keeps these answers once and uses them wherever they are needed, including your future diabetes risk estimate. '
        'Answer what you know; "Not sure" is always fine and is never treated as "No".',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.lg),
      for (final group in profile.groups)
        if (profile.fieldsIn(group.value).isNotEmpty) ...[
          SectionHeader(group.label, subtitle: profileGroupIntro[group.value]),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (i, field) in profile.fieldsIn(group.value).indexed) ...[
                if (i > 0) const Divider(height: AppSpacing.xl),
                ProfileFieldEditor(field: field, answers: _answers, canEdit: canEditField(field), onChanged: (v) => setState(() => _answers.edits[field.key] = v)),
              ],
            ]),
          ),
          if (group.value == 'body') ...[
            const SizedBox(height: AppSpacing.md),
            BodyMeasurementsCard(body: profile.body, patientId: profile.patientId),
          ],
          const SizedBox(height: AppSpacing.section),
        ],
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
      if (canEdit)
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save health profile'),
        ),
      const Disclaimer(),
    ]);
  }
}
