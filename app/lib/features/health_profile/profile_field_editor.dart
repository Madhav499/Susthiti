import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/health_data.dart';

const profileGroupIntro = {
  'body': 'Used to calculate BMI and for health risk estimates.',
  'medical_history': 'Conditions a doctor has diagnosed. Choose "Not sure" if you don\'t know.',
  'family_history': 'Your parents, brothers and sisters.',
  'habits': 'Your usual habits. Physical activity is taken from your phone\'s step count when enough is recorded.',
  'symptoms': 'In the last few weeks, have you noticed any of these? Answers are used for 90 days.',
};

/// Answers being edited on a screen: choices and yes/no answers, and the number fields' text.
/// [changes] turns them into what to save: field -> value (null = "not sure").
class ProfileAnswers {
  ProfileAnswers(this.profile);
  final HealthProfile profile;
  final Map<String, Object?> edits = {};
  final Map<String, TextEditingController> _numbers = {};

  TextEditingController numberController(HealthProfileField f) => _numbers.putIfAbsent(f.key, () => TextEditingController(text: _numberText(f)));

  /// Every answer shown, re-confirmed ([all]) or only the ones that changed. Returns an error
  /// message instead when a number is out of range.
  ({Map<String, Object?> values, String? error}) changes({bool all = false, Iterable<String>? only}) {
    final keys = only?.toSet();
    final out = <String, Object?>{};
    for (final f in profile.fields) {
      if (keys != null && !keys.contains(f.key)) continue;
      if (!f.appliesToSex(profile.sex)) continue;
      if (f.kind == ProfileFieldKind.number) {
        final text = (_numbers[f.key]?.text ?? _numberText(f)).trim().replaceAll(',', '.');
        if (text.isEmpty) {
          if (f.answered && f.value != null) out[f.key] = null;
          continue;
        }
        final number = double.tryParse(text);
        if (number == null || (f.min != null && number < f.min!) || (f.max != null && number > f.max!)) {
          return (values: const {}, error: '${f.label} must be a number between ${f.min?.toStringAsFixed(0)} and ${f.max?.toStringAsFixed(0)} ${f.unit ?? ''}.');
        }
        final saved = f.value is num ? (f.value as num).toDouble() : null;
        if (all || number != saved || f.needsUpdate) out[f.key] = number;
        continue;
      }
      if (edits.containsKey(f.key)) {
        out[f.key] = edits[f.key];
      } else if (all && f.answered) {
        out[f.key] = f.value; // re-confirmed as it was
      }
    }
    return (values: out, error: null);
  }

  void dispose() {
    for (final c in _numbers.values) {
      c.dispose();
    }
  }

  static String _numberText(HealthProfileField f) {
    final v = f.value;
    if (v is! num) return '';
    return v % 1 == 0 ? v.toInt().toString() : v.toString();
  }
}

/// One health profile question: Yes / No / Not sure, a choice (plus Not sure), or a number.
class ProfileFieldEditor extends StatelessWidget {
  const ProfileFieldEditor({super.key, required this.field, required this.answers, required this.canEdit, required this.onChanged, this.showCaption = true});
  final HealthProfileField field;
  final ProfileAnswers answers;
  final bool canEdit;
  final ValueChanged<Object?> onChanged;
  final bool showCaption;

  static const _unsure = '__not_sure__';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final edited = answers.edits.containsKey(field.key);
    final current = edited ? answers.edits[field.key] : field.value;
    final hasAnswer = edited || field.answered;
    final caption = field.answered
        ? 'Answered ${Fmt.date(field.recordedAt)} by ${field.recordedByRole == 'doctor' ? 'your doctor' : 'you'}'
        : 'Not answered yet';
    Widget editor;
    switch (field.kind) {
      case ProfileFieldKind.yesNo:
        final selected = !hasAnswer ? <String>{} : {current == null ? _unsure : (current == true ? 'yes' : 'no')};
        editor = SegmentedButton<String>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: 'yes', label: Text('Yes')), ButtonSegment(value: 'no', label: Text('No')), ButtonSegment(value: _unsure, label: Text('Not sure'))],
          selected: selected,
          onSelectionChanged: canEdit ? (s) => onChanged(s.isEmpty || s.first == _unsure ? null : s.first == 'yes') : null,
        );
      case ProfileFieldKind.choice:
        editor = Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          for (final o in [...field.options, const Option(_unsure, 'Not sure')])
            ChoiceChip(
              label: Text(o.label),
              selected: hasAnswer && (o.value == _unsure ? current == null : current == o.value),
              onSelected: canEdit ? (_) => onChanged(o.value == _unsure ? null : o.value) : null,
            ),
        ]);
      case ProfileFieldKind.number:
        editor = SizedBox(
          width: 200,
          child: TextField(
            key: ValueKey('number-${field.key}'),
            controller: answers.numberController(field),
            enabled: canEdit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(suffixText: field.unit, hintText: 'Not recorded', isDense: true),
          ),
        );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(field.label, style: t.titleSmall),
      if (field.help != null) Text(field.help!, style: t.bodySmall),
      const SizedBox(height: AppSpacing.sm),
      editor,
      if (showCaption) ...[
        const SizedBox(height: AppSpacing.xs),
        Row(children: [
          Expanded(
            child: Text(
              field.needsUpdate ? '$caption. Please confirm it is still correct.' : caption,
              style: t.bodySmall?.copyWith(color: field.needsUpdate ? AppColors.warningText : null),
            ),
          ),
          if (field.needsUpdate && canEdit && !edited && field.kind != ProfileFieldKind.number)
            TextButton(onPressed: () => onChanged(field.value), child: const Text('Still correct')),
        ]),
      ],
    ]);
  }
}
