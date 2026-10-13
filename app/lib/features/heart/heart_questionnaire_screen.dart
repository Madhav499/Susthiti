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
import '../../l10n/app_localizations.dart';
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

List<_ManualField> _symptomFields(AppLocalizations l10n) => [
      _ManualField('chest_pain', l10n.heartFieldChestPain, _Kind.yesNo),
      _ManualField('chest_pain_type', l10n.heartFieldChestPainType, _Kind.choice,
          options: [('typical_angina', l10n.heartOptionTypicalAngina), ('atypical_angina', l10n.heartOptionAtypicalAngina), ('non_anginal', l10n.heartOptionNonAnginal)]),
      _ManualField('chest_pain_duration_min', l10n.heartFieldChestPainDuration, _Kind.number, unit: 'min', min: 0, max: 600),
      _ManualField('shortness_of_breath', l10n.heartFieldShortnessOfBreath, _Kind.yesNo),
      _ManualField('fatigue', l10n.heartFieldFatigue, _Kind.yesNo),
      _ManualField('dizziness', l10n.heartFieldDizziness, _Kind.yesNo),
      _ManualField('fainting', l10n.heartFieldFainting, _Kind.yesNo),
      _ManualField('sweating', l10n.heartFieldSweating, _Kind.yesNo),
      _ManualField('nausea', l10n.heartFieldNausea, _Kind.yesNo),
      _ManualField('palpitations', l10n.heartFieldPalpitations, _Kind.yesNo),
      _ManualField('pain_left_arm', l10n.heartFieldLeftArmPain, _Kind.yesNo),
      _ManualField('pain_jaw_neck', l10n.heartFieldJawNeckPain, _Kind.yesNo),
      _ManualField('pain_back', l10n.heartFieldBackPain, _Kind.yesNo),
    ];

List<_ManualField> _cardiacTestFields(AppLocalizations l10n) => [
      _ManualField('resting_ecg', l10n.heartFieldRestingEcg, _Kind.choice, options: [
        ('normal', l10n.heartOptionNormal), ('normal_variant', l10n.heartOptionNormalVariant), ('st_t_abnormality', l10n.heartOptionStTAbnormality),
        ('old_infarct_pattern', l10n.heartOptionOldInfarctPattern), ('lvh', l10n.heartOptionLvh),
      ]),
      _ManualField('ecg_abnormality', l10n.heartFieldEcgAbnormality, _Kind.yesNo),
      _ManualField('st_depression', l10n.heartFieldStDepression, _Kind.number, min: 0, max: 20),
      _ManualField('exercise_induced_angina', l10n.heartFieldExerciseAngina, _Kind.yesNo),
      _ManualField('max_heart_rate', l10n.heartFieldMaxHeartRate, _Kind.number, unit: 'bpm', min: 30, max: 260),
      _ManualField('exercise_duration_min', l10n.heartFieldExerciseDuration, _Kind.number, unit: 'min', min: 0, max: 300),
      _ManualField('stress_test_result', l10n.heartFieldStressTestResult, _Kind.choice, options: [('negative', l10n.heartOptionNegative), ('borderline', l10n.heartOptionBorderline), ('positive', l10n.heartOptionPositive)]),
      _ManualField('echocardiogram_result', l10n.heartFieldEchoResult, _Kind.choice,
          options: [('normal', l10n.heartOptionNormal), ('mild_abnormality', l10n.heartOptionMildAbnormality), ('significant_abnormality', l10n.heartOptionSignificantAbnormality)]),
      _ManualField('ejection_fraction', l10n.heartFieldEjectionFraction, _Kind.number, unit: '%', min: 5, max: 100),
      _ManualField('heart_wall_motion_abnormality', l10n.heartFieldWallMotionAbnormality, _Kind.yesNo),
      _ManualField('previous_cardiac_test_abnormal', l10n.heartFieldPreviousAbnormalTest, _Kind.yesNo),
    ];

List<_ManualField> _medicalHistoryManualFields(AppLocalizations l10n) => [
      _ManualField('diabetes', l10n.navDiabetes, _Kind.yesNo, help: l10n.heartHelpDiabetes),
    ];

List<_ManualField> _vitalsManualFields(AppLocalizations l10n) => [
      _ManualField('respiratory_rate', l10n.heartFieldRespiratoryRate, _Kind.number, unit: 'breaths/min', min: 5, max: 60),
    ];

List<_ManualField> _lifestyleManualFields(AppLocalizations l10n) => [
      _ManualField('stress_level', l10n.heartFieldStressLevel, _Kind.number, min: 0, max: 10),
    ];

List<_KnownField> _vitalsKnownFields(AppLocalizations l10n) => [
      _KnownField('resting_heart_rate', l10n.heartFieldRestingHeartRate, 'bpm', 25, 250),
      _KnownField('systolic_bp', l10n.heartFieldSystolicBp, 'mmHg', 50, 300),
      _KnownField('diastolic_bp', l10n.heartFieldDiastolicBp, 'mmHg', 30, 200),
      _KnownField('oxygen_saturation', l10n.heartFieldOxygenSaturation, '%', 50, 100),
    ];

List<_KnownField> _labKnownFields(AppLocalizations l10n) => [
      _KnownField('fasting_glucose', l10n.heartFieldFastingGlucose, 'mg/dL', 20, 800),
      _KnownField('random_glucose', l10n.heartFieldRandomGlucose, 'mg/dL', 20, 1000),
      _KnownField('hba1c', 'HbA1c', '%', 2, 25),
      _KnownField('total_cholesterol', l10n.heartFieldTotalCholesterol, 'mg/dL', 50, 1000),
      _KnownField('ldl', l10n.heartFieldLdl, 'mg/dL', 10, 600),
      _KnownField('hdl', l10n.heartFieldHdl, 'mg/dL', 5, 250),
      _KnownField('triglycerides', l10n.heartFieldTriglycerides, 'mg/dL', 20, 2000),
      _KnownField('troponin', l10n.heartFieldTroponin, 'ng/mL', 0, 100),
      _KnownField('hemoglobin', l10n.heartFieldHemoglobin, 'g/dL', 3, 25),
      _KnownField('creatinine', l10n.heartFieldCreatinine, 'mg/dL', 0.1, 20),
    ];

List<_KnownField> _lifestyleKnownFields(AppLocalizations l10n) => [
      _KnownField('sleep_hours', l10n.heartFieldSleep, l10n.heartUnitHoursANight, 0, 24),
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
      title: AppLocalizations.of(context).heartRiskScreeningTitle,
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

  List<_ManualField> _allManualFields(AppLocalizations l10n) =>
      [..._medicalHistoryManualFields(l10n), ..._symptomFields(l10n), ..._vitalsManualFields(l10n), ..._cardiacTestFields(l10n), ..._lifestyleManualFields(l10n)];
  List<_KnownField> _allKnownFields(AppLocalizations l10n) => [..._vitalsKnownFields(l10n), ..._labKnownFields(l10n), ..._lifestyleKnownFields(l10n)];

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

  Future<void> _submit(AppLocalizations l10n) async {
    final manualFields = <String, Object?>{};
    for (final f in _allManualFields(l10n)) {
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
            setState(() => _error = l10n.numberBetweenError(f.label, f.min?.toStringAsFixed(0) ?? '', f.max?.toStringAsFixed(0) ?? '', f.unit ?? ''));
            return;
          }
          manualFields[f.key] = value;
      }
    }
    for (final f in _allKnownFields(l10n)) {
      final text = _overrides[f.key]?.text.trim().replaceAll(',', '.') ?? '';
      if (text.isEmpty) continue; // blank: keep using what SUSTHITI already knows
      final value = double.tryParse(text);
      if (value == null || value < f.min || value > f.max) {
        setState(() => _error = l10n.numberBetweenError(f.label, f.min.toStringAsFixed(0), f.max.toStringAsFixed(0), f.unit));
        return;
      }
      manualFields[f.key] = value;
    }
    final profileChanges = _profileAnswers.changes(l10n, all: true, only: _heartProfileFields);
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
    final l10n = AppLocalizations.of(context);
    return PageBody(maxWidth: 720, children: [
      Text(
        l10n.heartQuestionnaireIntro,
        style: t.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.lg),
      _sectionHeader(t, l10n.heartSectionBasicInfo),
      _profileSection(['height_cm', 'weight_kg'], l10n),
      _sectionHeader(t, l10n.heartSectionMedicalHistory),
      _profileSection(['family_history_heart_disease', 'previous_heart_disease', 'previous_heart_attack', 'hypertension', 'high_cholesterol', 'kidney_disease', 'stroke_history'], l10n),
      _manualSection(_medicalHistoryManualFields(l10n)),
      _sectionHeader(t, l10n.heartSectionSymptoms),
      _manualSection(_symptomFields(l10n)),
      _sectionHeader(t, l10n.heartSectionVitals),
      _knownSection(_vitalsKnownFields(l10n), l10n),
      _manualSection(_vitalsManualFields(l10n)),
      _sectionHeader(t, l10n.heartSectionLabValues),
      _knownSection(_labKnownFields(l10n), l10n),
      _sectionHeader(t, l10n.heartSectionCardiacTests),
      _manualSection(_cardiacTestFields(l10n)),
      _sectionHeader(t, l10n.heartSectionLifestyle),
      _profileSection(['smoking_status', 'alcohol_frequency', 'physical_activity_level', 'sedentary_hours_per_day', 'diet_quality'], l10n),
      _knownSection(_lifestyleKnownFields(l10n), l10n),
      _manualSection(_lifestyleManualFields(l10n)),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.md), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
      const SizedBox(height: AppSpacing.lg),
      BusyButton(label: l10n.seeMyResultButton, icon: Icons.favorite_border, onPressed: _busy ? null : () => _submit(l10n), expand: true),
      const SizedBox(height: AppSpacing.md),
      Text(l10n.heartAnswersSavedNote, style: t.bodySmall),
      const HeartSafetyNote(),
    ]);
  }

  Widget _sectionHeader(TextTheme t, String title) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.section, bottom: AppSpacing.md),
        child: Text(title, style: t.titleMedium),
      );

  Widget _profileSection(List<String> keys, AppLocalizations l10n) {
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
    final l10n = AppLocalizations.of(context);
    Widget editor;
    switch (f.kind) {
      case _Kind.yesNo:
        editor = SegmentedButton<bool>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: [ButtonSegment(value: true, label: Text(l10n.commonYes)), ButtonSegment(value: false, label: Text(l10n.commonNo))],
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
            decoration: InputDecoration(suffixText: f.unit, hintText: l10n.notAnsweredHint, isDense: true),
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

  Widget _knownSection(List<_KnownField> fields, AppLocalizations l10n) {
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
                  Expanded(child: Text(known != null ? l10n.fromYourRecordsLabel(known.value, known.detail != null ? ' — ${known.detail}' : '') : l10n.notCurrentlyKnownLabel, style: t.bodySmall)),
                ]),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _overrideController(fields[i].key),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(suffixText: fields[i].unit, hintText: known != null ? l10n.leaveBlankToKeepHint : l10n.commonNotRecorded, isDense: true),
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
