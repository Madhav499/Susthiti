import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/health_data.dart';
import '../../l10n/app_localizations.dart';

Map<String, String> profileGroupIntro(AppLocalizations l10n) => {
      'body': l10n.profileIntroBody,
      'medical_history': l10n.profileIntroMedicalHistory,
      'family_history': l10n.profileIntroFamilyHistory,
      'habits': l10n.profileIntroHabits,
      'symptoms': l10n.profileIntroSymptoms,
    };

/// Answers being edited on a screen: choices and yes/no answers, and the number fields' text.
/// [changes] turns them into what to save: field -> value (null = "not sure").
class ProfileAnswers {
  ProfileAnswers(this.profile);
  final HealthProfile profile;
  final Map<String, Object?> edits = {};
  final Map<String, TextEditingController> _numbers = {};
  final Map<String, TextEditingController> _lists = {};

  TextEditingController numberController(HealthProfileField f) => _numbers.putIfAbsent(f.key, () => TextEditingController(text: _numberText(f)));

  TextEditingController listController(HealthProfileField f) => _lists.putIfAbsent(f.key, () => TextEditingController(text: _listText(f)));

  /// Every answer shown, re-confirmed ([all]) or only the ones that changed. Returns an error
  /// message instead when a number is out of range.
  ({Map<String, Object?> values, String? error}) changes(AppLocalizations l10n, {bool all = false, Iterable<String>? only}) {
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
          return (values: const {}, error: l10n.numberBetweenError(f.label, f.min?.toStringAsFixed(0) ?? '', f.max?.toStringAsFixed(0) ?? '', f.unit ?? ''));
        }
        final saved = f.value is num ? (f.value as num).toDouble() : null;
        if (all || number != saved || f.needsUpdate) out[f.key] = number;
        continue;
      }
      if (f.kind == ProfileFieldKind.list) {
        final text = (_lists[f.key]?.text ?? _listText(f)).trim();
        if (text.isEmpty) {
          if (f.answered && f.value != null) out[f.key] = null;
          continue;
        }
        String? error;
        final parsed = _parseList(l10n, text, f.label, onError: (m) => error = m);
        if (error != null) return (values: const {}, error: error);
        final original = f.value is List ? List<String>.from(f.value as List) : const <String>[];
        final unchanged = parsed.length == original.length && !List.generate(parsed.length, (i) => parsed[i] != original[i]).contains(true);
        if (all || !unchanged || f.needsUpdate) out[f.key] = parsed;
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
    for (final c in _lists.values) {
      c.dispose();
    }
  }

  static String _numberText(HealthProfileField f) {
    final v = f.value;
    if (v is! num) return '';
    return v % 1 == 0 ? v.toInt().toString() : v.toString();
  }

  static String _listText(HealthProfileField f) {
    final v = f.value;
    if (v is! List) return '';
    return v.cast<String>().join(', ');
  }

  /// Splits on commas and newlines, trims each entry, drops empties and case-insensitive
  /// duplicates — mirrors the backend's own cleanup in `profile_fields.py`'s `ProfileField.validate`.
  static List<String> _parseList(AppLocalizations l10n, String text, String label, {required void Function(String) onError}) {
    final seen = <String>[];
    for (final raw in text.split(RegExp(r'[,\n]'))) {
      final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (cleaned.isEmpty) continue;
      if (cleaned.length > 200) {
        onError(l10n.listItemTooLongError(label));
        return const [];
      }
      if (!seen.any((s) => s.toLowerCase() == cleaned.toLowerCase())) seen.add(cleaned);
    }
    if (seen.length > 20) {
      onError(l10n.listTooManyItemsError(label));
      return const [];
    }
    return seen;
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
    final l10n = AppLocalizations.of(context);
    final edited = answers.edits.containsKey(field.key);
    final current = edited ? answers.edits[field.key] : field.value;
    final hasAnswer = edited || field.answered;
    final caption = field.answered
        ? l10n.answeredByLabel(Fmt.date(field.recordedAt), field.recordedByRole == 'doctor' ? l10n.yourDoctorLabel : l10n.commonYou)
        : l10n.notAnsweredYetLabel;
    Widget editor;
    switch (field.kind) {
      case ProfileFieldKind.yesNo:
        final selected = !hasAnswer ? <String>{} : {current == null ? _unsure : (current == true ? 'yes' : 'no')};
        editor = SegmentedButton<String>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: [ButtonSegment(value: 'yes', label: Text(l10n.commonYes)), ButtonSegment(value: 'no', label: Text(l10n.commonNo)), ButtonSegment(value: _unsure, label: Text(l10n.notSureOption))],
          selected: selected,
          onSelectionChanged: canEdit ? (s) => onChanged(s.isEmpty || s.first == _unsure ? null : s.first == 'yes') : null,
        );
      case ProfileFieldKind.choice:
        editor = Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          for (final o in [...field.options, Option(_unsure, l10n.notSureOption)])
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
            decoration: InputDecoration(suffixText: field.unit, hintText: l10n.commonNotRecorded, isDense: true),
          ),
        );
      case ProfileFieldKind.list:
        editor = TextField(
          key: ValueKey('list-${field.key}'),
          controller: answers.listController(field),
          enabled: canEdit,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: l10n.notRecordedListHint,
            isDense: true,
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
              field.needsUpdate ? l10n.confirmStillCorrectCaption(caption) : caption,
              style: t.bodySmall?.copyWith(color: field.needsUpdate ? AppColors.warningText : null),
            ),
          ),
          if (field.needsUpdate && canEdit && !edited && field.kind != ProfileFieldKind.number && field.kind != ProfileFieldKind.list)
            TextButton(onPressed: () => onChanged(field.value), child: Text(l10n.stillCorrectButton)),
        ]),
      ],
    ]);
  }
}
