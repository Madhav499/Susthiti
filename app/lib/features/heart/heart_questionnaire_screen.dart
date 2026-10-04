import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/health_data.dart';
import '../../data/models/heart_risk.dart';
import '../../data/providers.dart';
import '../diabetes/diabetes_providers.dart' show healthProfileProvider;
import '../health_profile/profile_field_editor.dart';
import '../patient/patient_sync.dart';
import 'heart_providers.dart';
import 'heart_widgets.dart';

/// Health-profile fields the heart model reads (services/heart_risk/features.py's
/// FEATURE_SOURCES, health-profile-backed ones). Rendered with the same generic
/// ProfileFieldEditor the diabetes questionnaire uses, so answers are two-way editable,
/// prefilled, and saved to the shared health profile -- not re-asked elsewhere.
const _heartProfileFields = {
  'family_history_heart_disease', 'previous_heart_disease', 'previous_heart_attack', 'hypertension',
  'high_cholesterol', 'kidney_disease', 'stroke_history', 'smoking_status', 'alcohol_frequency',
  'physical_activity_level', 'sedentary_hours_per_day', 'diet_quality', 'height_cm', 'weight_kg',
};

enum _Kind { yesNo, number, choice }

class _ManualField {
  const _ManualField(this.key, this.label, this.kind, {this.unit, this.min, this.max, this.options = const [], this.help});
  final String key;
  final String label;
  final _Kind kind;
  final String? unit;
  final double? min;
  final double? max;
  final List<(String, String)> options;
  final String? help;
}

/// Reusable (lab/vitals) fields: shown as "known or not" with an optional override for this
/// screening only. Leaving the override blank means "keep using what SUSTHITI already knows".
class _KnownField {
  const _KnownField(this.key, this.label, this.unit, this.min, this.max);
  final String key;
  final String label;
  final String unit;
  final double min;
  final double max;
}

const _symptomFields = [
  _ManualField('chest_pain', 'Chest pain', _Kind.yesNo),
  _ManualField('chest_pain_type', 'Chest pain type', _Kind.choice,
      options: [('typical_angina', 'Typical angina'), ('atypical_angina', 'Atypical angina'), ('non_anginal', 'Non-anginal')]),
  _ManualField('chest_pain_duration_min', 'Chest pain duration', _Kind.number, unit: 'min', min: 0, max: 600),
  _ManualField('shortness_of_breath', 'Shortness of breath', _Kind.yesNo),
  _ManualField('fatigue', 'Fatigue', _Kind.yesNo),
  _ManualField('dizziness', 'Dizziness', _Kind.yesNo),
  _ManualField('fainting', 'Fainting', _Kind.yesNo),
  _ManualField('sweating', 'Sweating', _Kind.yesNo),
  _ManualField('nausea', 'Nausea', _Kind.yesNo),
  _ManualField('palpitations', 'Palpitations', _Kind.yesNo),
  _ManualField('pain_left_arm', 'Left-arm pain', _Kind.yesNo),
  _ManualField('pain_jaw_neck', 'Jaw or neck pain', _Kind.yesNo),
  _ManualField('pain_back', 'Back pain', _Kind.yesNo),
];

const _cardiacTestFields = [
  _ManualField('resting_ecg', 'Resting ECG', _Kind.choice, options: [
    ('normal', 'Normal'), ('normal_variant', 'Normal variant'), ('st_t_abnormality', 'ST-T abnormality'),
    ('old_infarct_pattern', 'Old infarct pattern'), ('lvh', 'Left ventricular hypertrophy (LVH)'),
  ]),
  _ManualField('ecg_abnormality', 'ECG abnormality', _Kind.yesNo),
  _ManualField('st_depression', 'ST depression', _Kind.number, min: 0, max: 20),
  _ManualField('exercise_induced_angina', 'Exercise-induced angina', _Kind.yesNo),
  _ManualField('max_heart_rate', 'Maximum heart rate (exercise)', _Kind.number, unit: 'bpm', min: 30, max: 260),
  _ManualField('exercise_duration_min', 'Exercise duration', _Kind.number, unit: 'min', min: 0, max: 300),
  _ManualField('stress_test_result', 'Stress test result', _Kind.choice, options: [('negative', 'Negative'), ('borderline', 'Borderline'), ('positive', 'Positive')]),
  _ManualField('echocardiogram_result', 'Echocardiogram result', _Kind.choice,
      options: [('normal', 'Normal'), ('mild_abnormality', 'Mild abnormality'), ('significant_abnormality', 'Significant abnormality')]),
  _ManualField('ejection_fraction', 'Ejection fraction', _Kind.number, unit: '%', min: 5, max: 100),
  _ManualField('heart_wall_motion_abnormality', 'Heart wall motion abnormality', _Kind.yesNo),
  _ManualField('previous_cardiac_test_abnormal', 'Previous abnormal cardiac test', _Kind.yesNo),
];

const _medicalHistoryManualFields = [
  _ManualField('diabetes', 'Diabetes', _Kind.yesNo, help: 'A doctor has diagnosed you with diabetes.'),
];

const _vitalsManualFields = [
  _ManualField('respiratory_rate', 'Respiratory rate', _Kind.number, unit: 'breaths/min', min: 5, max: 60),
];

const _lifestyleManualFields = [
  _ManualField('stress_level', 'Stress level (0 = none, 10 = severe)', _Kind.number, min: 0, max: 10),
];

const _vitalsKnownFields = [
  _KnownField('resting_heart_rate', 'Resting heart rate', 'bpm', 25, 250),
  _KnownField('systolic_bp', 'Systolic blood pressure', 'mmHg', 50, 300),
  _KnownField('diastolic_bp', 'Diastolic blood pressure', 'mmHg', 30, 200),
  _KnownField('oxygen_saturation', 'Oxygen saturation', '%', 50, 100),
];

const _labKnownFields = [
  _KnownField('fasting_glucose', 'Fasting glucose', 'mg/dL', 20, 800),
  _KnownField('random_glucose', 'Random glucose', 'mg/dL', 20, 1000),
  _KnownField('hba1c', 'HbA1c', '%', 2, 25),
  _KnownField('total_cholesterol', 'Total cholesterol', 'mg/dL', 50, 1000),
  _KnownField('ldl', 'LDL cholesterol', 'mg/dL', 10, 600),
  _KnownField('hdl', 'HDL cholesterol', 'mg/dL', 5, 250),
  _KnownField('triglycerides', 'Triglycerides', 'mg/dL', 20, 2000),
  _KnownField('troponin', 'Troponin', 'ng/mL', 0, 100),
  _KnownField('hemoglobin', 'Hemoglobin', 'g/dL', 3, 25),
  _KnownField('creatinine', 'Creatinine', 'mg/dL', 0.1, 20),
];

const _lifestyleKnownFields = [
  _KnownField('sleep_hours', 'Sleep', 'h a night', 0, 24),
];

/// "Start screening" / "Run new screening": the full assessment form, organized into the
/// product's own sections (A-G). Known/reusable fields are shown as a one-page review (what
/// SUSTHITI already has, left untouched unless overridden); point-in-time fields (symptoms,
/// cardiac tests) always start blank. Mirrors diabetes_questionnaire_screen.dart's shape.
class HeartQuestionnaireScreen extends ConsumerWidget {
  const HeartQuestionnaireScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(healthProfileProvider(patientId));
    final status = ref.watch(heartRiskStatusProvider(patientId));
    return AppPage(
      title: 'Heart risk screening',
      body: AsyncBody(
        value: profile,
        onRetry: () => ref.invalidate(healthProfileProvider(patientId)),
        data: (p) => AsyncBody(
          value: status,
          onRetry: () => ref.invalidate(heartRiskStatusProvider(patientId)),
          data: (s) => _Questionnaire(key: ObjectKey(p), patientId: patientId, profile: p, status: s),
        ),
      ),
    );
  }
}

class _Questionnaire extends ConsumerStatefulWidget {
  const _Questionnaire({super.key, required this.patientId, required this.profile, required this.status});
  final String patientId;
  final HealthProfile profile;
  final HeartRiskStatus status;

  @override
  ConsumerState<_Questionnaire> createState() => _QuestionnaireState();
}

class _QuestionnaireState extends ConsumerState<_Questionnaire> {
  late final ProfileAnswers _profileAnswers = ProfileAnswers(widget.profile);
  final Map<String, bool?> _manualYesNo = {};
  final Map<String, String?> _manualChoice = {};
  final Map<String, TextEditingController> _manualNumbers = {};
  final Map<String, TextEditingController> _overrides = {};
  bool _busy = false;
  String? _error;

  List<_ManualField> get _allManualFields => [..._medicalHistoryManualFields, ..._symptomFields, ..._vitalsManualFields, ..._cardiacTestFields, ..._lifestyleManualFields];
  List<_KnownField> get _allKnownFields => [..._vitalsKnownFields, ..._labKnownFields, ..._lifestyleKnownFields];

  TextEditingController _numberController(String key) => _manualNumbers.putIfAbsent(key, () => TextEditingController());
  TextEditingController _overrideController(String key) => _overrides.putIfAbsent(key, () => TextEditingController());

  @override
  void dispose() {
    _profileAnswers.dispose();
    for (final c in _manualNumbers.values) {
      c.dispose();
    }
    for (final c in _overrides.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Known-value caption for a reusable field, read from the current screening status (what a
  /// screening would use right now) -- so the patient sees exactly what SUSTHITI already has.
  DataItem? _known(String key) {
    for (final g in widget.status.currentData.groups) {
      for (final item in g.items) {
        if (item.feature == key) return item;
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final manualFields = <String, Object?>{};
    for (final f in _allManualFields) {
      switch (f.kind) {
        case _Kind.yesNo:
          if (_manualYesNo[f.key] != null) manualFields[f.key] = _manualYesNo[f.key];
        case _Kind.choice:
          if (_manualChoice[f.key] != null) manualFields[f.key] = _manualChoice[f.key];
        case _Kind.number:
          final text = _manualNumbers[f.key]?.text.trim().replaceAll(',', '.') ?? '';
          if (text.isEmpty) continue;
          final value = double.tryParse(text);
          if (value == null || (f.min != null && value < f.min!) || (f.max != null && value > f.max!)) {
            setState(() => _error = '${f.label} must be a number between ${f.min?.toStringAsFixed(0)} and ${f.max?.toStringAsFixed(0)} ${f.unit ?? ''}.');
            return;
          }
          manualFields[f.key] = value;
      }
    }
    for (final f in _allKnownFields) {
      final text = _overrides[f.key]?.text.trim().replaceAll(',', '.') ?? '';
      if (text.isEmpty) continue; // blank: keep using what SUSTHITI already knows
      final value = double.tryParse(text);
      if (value == null || value < f.min || value > f.max) {
        setState(() => _error = '${f.label} must be a number between ${f.min.toStringAsFixed(0)} and ${f.max.toStringAsFixed(0)} ${f.unit}.');
        return;
      }
      manualFields[f.key] = value;
    }
    final profileChanges = _profileAnswers.changes(all: true, only: _heartProfileFields);
    if (profileChanges.error != null) {
      setState(() => _error = profileChanges.error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (profileChanges.values.isNotEmpty) await ref.read(patientRepositoryProvider).updateHealthProfile(widget.patientId, profileChanges.values);
      final refresh = await submitHeartAssessment(ref, widget.patientId, manualFields);
      if (!mounted) return;
      context.pushReplacement('/r/${widget.patientId}/heart-risk/${refresh.assessment.id}');
    } on Failure catch (e) {
      healthDataChanged(ref, widget.patientId);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PageBody(maxWidth: 720, children: [
      Text(
        'A few questions, already filled in with what SUSTHITI knows where possible; symptoms and test results are always answered fresh.',
        style: t.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.lg),
      _sectionHeader(t, 'A. Basic information'),
      _profileSection(['height_cm', 'weight_kg']),
      _sectionHeader(t, 'B. Medical history'),
      _profileSection(['family_history_heart_disease', 'previous_heart_disease', 'previous_heart_attack', 'hypertension', 'high_cholesterol', 'kidney_disease', 'stroke_history']),
      _manualSection(_medicalHistoryManualFields),
      _sectionHeader(t, 'C. Symptoms'),
      _manualSection(_symptomFields),
      _sectionHeader(t, 'D. Vitals'),
      _knownSection(_vitalsKnownFields),
      _manualSection(_vitalsManualFields),
      _sectionHeader(t, 'E. Laboratory values'),
      _knownSection(_labKnownFields),
      _sectionHeader(t, 'F. Cardiac tests'),
      _manualSection(_cardiacTestFields),
      _sectionHeader(t, 'G. Lifestyle'),
      _profileSection(['smoking_status', 'alcohol_frequency', 'physical_activity_level', 'sedentary_hours_per_day', 'diet_quality']),
      _knownSection(_lifestyleKnownFields),
      _manualSection(_lifestyleManualFields),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.md), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
      const SizedBox(height: AppSpacing.lg),
      BusyButton(label: 'See my result', icon: Icons.favorite_border, onPressed: _busy ? null : _submit, expand: true),
      const SizedBox(height: AppSpacing.md),
      Text('Answers to medical history and lifestyle questions are saved to your health profile. Symptoms and test results are kept only with this screening.', style: t.bodySmall),
      const HeartSafetyNote(),
    ]);
  }

  Widget _sectionHeader(TextTheme t, String title) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.section, bottom: AppSpacing.md),
        child: Text(title, style: t.titleMedium),
      );

  Widget _profileSection(List<String> keys) {
    final fields = [for (final f in widget.profile.fields) if (keys.contains(f.key) && f.appliesToSex(widget.profile.sex)) f];
    if (fields.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const Divider(height: AppSpacing.xl),
          ProfileFieldEditor(field: fields[i], answers: _profileAnswers, canEdit: true, onChanged: (v) => setState(() => _profileAnswers.edits[fields[i].key] = v)),
        ],
      ]),
    );
  }

  Widget _manualSection(List<_ManualField> fields) {
    if (fields.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const Divider(height: AppSpacing.xl),
            _manualFieldEditor(fields[i]),
          ],
        ]),
      ),
    );
  }

  Widget _manualFieldEditor(_ManualField f) {
    final t = Theme.of(context).textTheme;
    Widget editor;
    switch (f.kind) {
      case _Kind.yesNo:
        editor = SegmentedButton<bool>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: true, label: Text('Yes')), ButtonSegment(value: false, label: Text('No'))],
          selected: _manualYesNo[f.key] == null ? const {} : {_manualYesNo[f.key]!},
          onSelectionChanged: (s) => setState(() => _manualYesNo[f.key] = s.isEmpty ? null : s.first),
        );
      case _Kind.choice:
        editor = Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          for (final (value, label) in f.options) ChoiceChip(label: Text(label), selected: _manualChoice[f.key] == value, onSelected: (_) => setState(() => _manualChoice[f.key] = value)),
        ]);
      case _Kind.number:
        editor = SizedBox(
          width: 200,
          child: TextField(
            controller: _numberController(f.key),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(suffixText: f.unit, hintText: 'Not answered', isDense: true),
          ),
        );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(f.label, style: t.titleSmall),
      if (f.help != null) Text(f.help!, style: t.bodySmall),
      const SizedBox(height: AppSpacing.sm),
      editor,
    ]);
  }

  Widget _knownSection(List<_KnownField> fields) {
    if (fields.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const Divider(height: AppSpacing.xl),
            Builder(builder: (context) {
              final known = _known(fields[i].key);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fields[i].label, style: t.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Row(children: [
                  Icon(known != null ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: known != null ? AppColors.success : AppColors.inactive),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(known != null ? 'From your records: ${known.value}${known.detail != null ? ' — ${known.detail}' : ''}' : 'Not currently known', style: t.bodySmall)),
                ]),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _overrideController(fields[i].key),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(suffixText: fields[i].unit, hintText: known != null ? 'Leave blank to keep this' : 'Not recorded', isDense: true),
                  ),
                ),
              ]);
            }),
          ],
        ]),
      ),
    );
  }
}
