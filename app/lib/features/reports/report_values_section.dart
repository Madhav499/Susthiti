import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/health_data.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../authentication/auth_controller.dart';
import '../diabetes/diabetes_providers.dart';
import '../patient/patient_sync.dart';

/// Values from this report that SUSTHITI uses as health data (e.g. HbA1c for the diabetes risk
/// estimate). Confirmed once, on the report they came from; never asked for again. The AI
/// summary can only *suggest* values, which count only after someone confirms them.
class ReportValuesSection extends ConsumerStatefulWidget {
  const ReportValuesSection({super.key, required this.reportId, required this.patientId});
  final String reportId;
  final String patientId;

  @override
  ConsumerState<ReportValuesSection> createState() => _ReportValuesSectionState();
}

class _ReportValuesSectionState extends ConsumerState<ReportValuesSection> {
  bool _saving = false;

  Future<void> _save(Map<String, Object?> values) async {
    if (values.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(reportRepositoryProvider).saveValues(widget.reportId, values);
      ref.invalidate(reportValuesProvider(widget.reportId));
      healthDataChanged(ref, widget.patientId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report values saved.')));
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Reads the report file again (e.g. reports uploaded before automatic reading existed).
  Future<void> _readAgain() async {
    setState(() => _saving = true);
    try {
      final result = await ref.read(reportRepositoryProvider).readValues(widget.reportId);
      ref.invalidate(reportValuesProvider(widget.reportId));
      healthDataChanged(ref, widget.patientId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.values.isEmpty ? (result.extractionNote ?? 'No values could be read from this report.') : 'Values read from the report. Please check them.'),
        ));
      }
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(reportValuesProvider(widget.reportId));
    final role = ref.watch(currentUserProvider)?.role;
    final canEdit = role == UserRole.patient || role == UserRole.doctor;
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: AsyncBody(
        value: value,
        loading: const SkeletonList(count: 1, itemHeight: 48),
        onRetry: () => ref.invalidate(reportValuesProvider(widget.reportId)),
        data: (v) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Values from this report', style: t.titleMedium),
          Text('SUSTHITI reads HbA1c and glucose results from the report automatically and uses them in your health features, including your future diabetes risk estimate.', style: t.bodySmall),
          if (v.extractionNote != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(v.extractionNote!, style: t.bodySmall?.copyWith(color: AppColors.primaryDeep)),
          ],
          const SizedBox(height: AppSpacing.md),
          if (v.values.isEmpty)
            Text('No values recorded from this report yet.', style: t.bodyMedium)
          else
            for (final item in v.values)
              KeyValueRow(
                item.label,
                item.display,
                trailing: item.needsCheck
                    ? (canEdit
                        ? TextButton(
                            onPressed: _saving ? null : () => _save({item.analyte: {'origin': 'confirm'}}),
                            child: const Text('Looks right'),
                          )
                        : Text('Read automatically', style: t.bodySmall))
                    : Text(item.confirmedByRole == 'doctor' ? 'Checked by doctor' : (item.readAutomatically ? 'Checked by you' : 'You'), style: t.bodySmall),
              ),
          if (v.values.any((i) => i.needsCheck))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('Read automatically: please check these against the report. Correct them with "Add or correct values" if needed.', style: t.bodySmall),
            ),
          if (v.suggestions.isNotEmpty && canEdit) ...[
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.cardBorder),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Found in the AI summary. Please check them against the report before confirming:', style: t.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  for (final s in v.suggestions) Text('• ${s.label}: ${_num(s.enteredValue)} ${s.enteredUnit}', style: t.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.tonal(
                    onPressed: _saving
                        ? null
                        : () => _save({for (final s in v.suggestions) s.analyte: {'value': s.enteredValue, 'unit': s.enteredUnit, 'origin': 'ai_suggestion'}}),
                    child: const Text('These match the report'),
                  ),
                ]),
              ),
            ),
          ],
          if (canEdit) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              if (v.values.isEmpty)
                FilledButton.tonalIcon(
                  onPressed: _saving ? null : _readAgain,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Read values from this report'),
                ),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        final changes = await showModalBottomSheet<Map<String, Object?>>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => ReportValuesForm(values: v),
                        );
                        if (changes != null) await _save(changes);
                      },
                icon: const Icon(Icons.edit_note),
                label: Text(v.values.isEmpty ? 'Add values yourself' : 'Add or correct values'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Entry form: one row per measure SUSTHITI understands. Returns only what changed:
/// analyte -> {value, unit} / {text_value} / null (the report doesn't contain it).
class ReportValuesForm extends StatefulWidget {
  const ReportValuesForm({super.key, required this.values});
  final ReportValues values;

  @override
  State<ReportValuesForm> createState() => _ReportValuesFormState();
}

class _ReportValuesFormState extends State<ReportValuesForm> {
  late final Map<String, TextEditingController> _text = {
    for (final a in widget.values.analytes)
      if (!a.isClassification) a.key: TextEditingController(text: _initialText(a)),
  };
  late final Map<String, String> _units = {
    for (final a in widget.values.analytes)
      if (!a.isClassification) a.key: widget.values.valueOf(a.key)?.enteredUnit ?? (a.units.isEmpty ? (a.unit ?? '') : a.units.first),
  };
  late String? _classification = widget.values.values.where((v) => v.analyte == 'diabetes_classification').firstOrNull?.textValue;
  String? _error;

  String _initialText(AnalyteSpec a) => _num(widget.values.valueOf(a.key)?.enteredValue);

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final changes = <String, Object?>{};
    for (final a in widget.values.analytes) {
      final existing = widget.values.valueOf(a.key);
      if (a.isClassification) {
        if (_classification != existing?.textValue) changes[a.key] = _classification == null ? null : {'text_value': _classification};
        continue;
      }
      final text = _text[a.key]!.text.trim().replaceAll(',', '.');
      if (text.isEmpty) {
        if (existing != null) changes[a.key] = null;
        continue;
      }
      final number = double.tryParse(text);
      if (number == null) {
        setState(() => _error = 'Enter ${a.label} as a number, exactly as in the report.');
        return;
      }
      if (existing == null || existing.enteredValue != number || existing.enteredUnit != _units[a.key]) {
        changes[a.key] = {'value': number, 'unit': _units[a.key]};
      }
    }
    Navigator.of(context).pop(changes);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text('Values from this report', style: t.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text('Report date ${Fmt.date(widget.values.reportDate)}. Leave a value empty if the report doesn\'t show it.', style: t.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            for (final a in widget.values.analytes)
              if (!a.isClassification)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey('value-${a.key}'),
                        controller: _text[a.key],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: a.label, isDense: true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    if (a.units.length > 1)
                      DropdownButton<String>(
                        value: _units[a.key],
                        items: [for (final u in a.units) DropdownMenuItem(value: u, child: Text(u))],
                        onChanged: (u) => setState(() => _units[a.key] = u!),
                      )
                    else
                      Text(a.unit ?? '', style: t.bodyMedium),
                  ]),
                )
              else ...[
                Text(a.label, style: t.titleSmall),
                Text('Only if the report itself states it. SUSTHITI never works this out from the numbers.', style: t.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                  for (final o in a.options) ChoiceChip(label: Text(o.label), selected: _classification == o.value, onSelected: (_) => setState(() => _classification = o.value)),
                  ChoiceChip(label: const Text('Not stated'), selected: _classification == null, onSelected: (_) => setState(() => _classification = null)),
                ]),
                const SizedBox(height: AppSpacing.md),
              ],
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
            FilledButton(onPressed: _submit, child: const Text('Save values')),
          ]),
        ),
      ),
    );
  }
}

String _num(double? v) => v == null ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());
