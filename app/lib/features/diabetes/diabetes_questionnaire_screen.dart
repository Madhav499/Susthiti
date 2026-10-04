import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/diabetes_risk.dart';
import '../../data/models/health_data.dart';
import '../../data/providers.dart';
import '../health_profile/profile_field_editor.dart';
import '../patient/patient_sync.dart';
import 'diabetes_providers.dart';
import 'risk_widgets.dart';

/// Health-profile fields the diabetes model actually reads (services/diabetes_risk/features.py's
/// FEATURE_SOURCES, health-profile-backed ones; height/weight are asked separately in the BODY
/// group). The health profile is shared by every risk model (see profile_fields.py's docstring),
/// so this questionnaire must filter to its own fields -- otherwise a field added for a sibling
/// model (e.g. the heart risk screening's family/medical-history questions) would also show up
/// here, in a flow titled "Diabetes risk assessment".
const _diabetesProfileFields = {
  'family_history_diabetes', 'previous_prediabetes', 'previous_gestational_diabetes', 'physical_activity_level',
  'sedentary_hours_per_day', 'diet_quality', 'sugary_drink_frequency', 'smoking_status', 'alcohol_frequency',
  'hypertension', 'high_cholesterol', 'pcos', 'cardiovascular_disease', 'fatty_liver_disease', 'stress_level',
  'polyuria', 'polydipsia', 'unexplained_weight_loss', 'polyphagia', 'height_cm', 'weight_kg',
};

List<HealthProfileField> _fieldsIn(HealthProfile profile, String group) => [for (final f in profile.fieldsIn(group)) if (_diabetesProfileFields.contains(f.key)) f];

/// "Run new assessment": every question again, pre-filled with the current answers. Answers are
/// saved straight to the health profile (so the whole app uses them), then a new assessment is
/// made. Values from reports and the phone are shown for review; they come in automatically.
class DiabetesQuestionnaireScreen extends ConsumerWidget {
  const DiabetesQuestionnaireScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(healthProfileProvider(patientId));
    return AppPage(
      title: 'Diabetes risk assessment',
      body: AsyncBody(
        value: profile,
        onRetry: () => ref.invalidate(healthProfileProvider(patientId)),
        data: (p) => _Questionnaire(key: ObjectKey(p), patientId: patientId, profile: p),
      ),
    );
  }
}

class _Questionnaire extends ConsumerStatefulWidget {
  const _Questionnaire({super.key, required this.patientId, required this.profile});
  final String patientId;
  final HealthProfile profile;

  @override
  ConsumerState<_Questionnaire> createState() => _QuestionnaireState();
}

class _QuestionnaireState extends ConsumerState<_Questionnaire> {
  late final ProfileAnswers _answers = ProfileAnswers(widget.profile);
  late final List<Option> _steps = [
    for (final g in widget.profile.groups)
      if (_fieldsIn(widget.profile, g.value).isNotEmpty) g,
    const Option('review', 'Review'),
  ];
  int _step = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _answers.dispose();
    super.dispose();
  }

  bool get _isReview => _steps[_step].value == 'review';

  void _next() {
    final group = _steps[_step].value;
    if (group != 'review') {
      final check = _answers.changes(only: _fieldsIn(widget.profile, group).map((f) => f.key));
      if (check.error != null) {
        setState(() => _error = check.error);
        return;
      }
    }
    setState(() {
      _error = null;
      _step++;
    });
  }

  Future<void> _finish() async {
    final result = _answers.changes(all: true);
    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Every answer given here goes to the health profile, re-confirmed or changed.
      if (result.values.isNotEmpty) await ref.read(patientRepositoryProvider).updateHealthProfile(widget.patientId, result.values);
      final refresh = await refreshDiabetesRisk(ref, widget.patientId, force: true);
      if (!mounted) return;
      context.pushReplacement('/r/${widget.patientId}/diabetes-risk/${refresh.assessment.id}');
    } on Failure catch (e) {
      // Answers already saved stay saved; only the model call failed.
      healthDataChanged(ref, widget.patientId);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final step = _steps[_step];
    return PageBody(maxWidth: 720, children: [
      Text('Step ${_step + 1} of ${_steps.length}: ${step.label}', style: t.labelLarge?.copyWith(color: AppColors.primaryDeep)),
      const SizedBox(height: AppSpacing.sm),
      LinearProgressIndicator(value: (_step + 1) / _steps.length, minHeight: 6, borderRadius: BorderRadius.circular(3)),
      const SizedBox(height: AppSpacing.lg),
      if (!_isReview) ...[
        Text(profileGroupIntro[step.value] ?? '', style: t.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, field) in _fieldsIn(widget.profile, step.value).indexed) ...[
              if (i > 0) const Divider(height: AppSpacing.xl),
              ProfileFieldEditor(field: field, answers: _answers, canEdit: true, onChanged: (v) => setState(() => _answers.edits[field.key] = v)),
            ],
          ]),
        ),
      ] else
        _Review(patientId: widget.patientId),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.md), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
      const SizedBox(height: AppSpacing.lg),
      Row(children: [
        if (_step > 0) OutlinedButton(onPressed: _busy ? null : () => setState(() => _step--), child: const Text('Back')),
        const Spacer(),
        if (!_isReview)
          FilledButton(onPressed: _next, child: const Text('Next'))
        else
          FilledButton.icon(
            onPressed: _busy ? null : _finish,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.insights_outlined),
            label: const Text('See my result'),
          ),
      ]),
      const SizedBox(height: AppSpacing.md),
      Text('Your answers are saved to your health profile, so you won\'t be asked again elsewhere.', style: t.bodySmall),
      const RiskSafetyNote(),
    ]);
  }
}

/// What the assessment will also use, collected automatically.
class _Review extends ConsumerWidget {
  const _Review({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(riskStatusProvider(patientId));
    final t = Theme.of(context).textTheme;
    return AsyncBody(
      value: status,
      onRetry: () => ref.invalidate(riskStatusProvider(patientId)),
      data: (s) {
        final auto = DataUsed(
          groups: [for (final g in s.currentData.groups) if (g.key == 'report' || g.key == 'wearable') g],
          missing: const [],
          availableCount: 0,
          totalCount: 0,
        );
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Also used, collected automatically', style: t.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('Values read from your reports and data from your phone. To change a report value, open the report.', style: t.bodySmall),
          const SizedBox(height: AppSpacing.md),
          if (auto.groups.isEmpty)
            AppCard(child: Text('No report values or phone data yet. Upload a report with HbA1c or glucose results to include them.', style: t.bodyMedium))
          else
            DataUsedCard(data: auto),
        ]);
      },
    );
  }
}
