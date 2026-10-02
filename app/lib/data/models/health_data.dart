import '../../core/utils/formatters.dart';
import 'patient.dart';


class Option {
  const Option(this.value, this.label);
  final String value;
  final String label;

  factory Option.fromJson(Map<String, dynamic> j) => Option(j['value'] as String, j['label'] as String);
}

enum ProfileFieldKind {
  number,
  yesNo,
  choice;

  static ProfileFieldKind parse(String? v) => switch (v) {
        'yes_no' => yesNo,
        'choice' => choice,
        _ => number,
      };
}

/// One question in the health profile, with the current answer and who gave it.
/// A null [value] with [answered] true is an explicit "not sure".
class HealthProfileField {
  const HealthProfileField({
    required this.key,
    required this.group,
    required this.label,
    required this.kind,
    this.options = const [],
    this.unit,
    this.min,
    this.max,
    this.appliesTo,
    this.help,
    this.answered = false,
    this.value,
    this.recordedAt,
    this.recordedByRole,
    this.needsUpdate = false,
  });

  final String key;
  final String group;
  final String label;
  final ProfileFieldKind kind;
  final List<Option> options;
  final String? unit;
  final double? min;
  final double? max;
  final String? appliesTo;
  final String? help;
  final bool answered;
  final Object? value;
  final DateTime? recordedAt;
  final String? recordedByRole;

  /// Answered long enough ago that it is no longer used until confirmed again.
  final bool needsUpdate;

  bool appliesToSex(String? sex) => appliesTo == null || sex == null || sex == appliesTo;

  String get answerLabel {
    if (!answered) return 'Not answered';
    final v = value;
    if (v == null) return 'Not sure';
    return switch (kind) {
      ProfileFieldKind.yesNo => v == true ? 'Yes' : 'No',
      ProfileFieldKind.choice => options.where((o) => o.value == v).map((o) => o.label).firstOrNull ?? '$v',
      ProfileFieldKind.number => '${(v as num).toDouble() % 1 == 0 ? (v).toInt() : v} ${unit ?? ''}'.trim(),
    };
  }

  factory HealthProfileField.fromJson(Map<String, dynamic> j) => HealthProfileField(
        key: j['key'] as String,
        group: j['group'] as String,
        label: j['label'] as String,
        kind: ProfileFieldKind.parse(j['kind'] as String?),
        options: [for (final o in j['options'] as List? ?? const []) Option.fromJson(o as Map<String, dynamic>)],
        unit: j['unit'] as String?,
        min: (j['min'] as num?)?.toDouble(),
        max: (j['max'] as num?)?.toDouble(),
        appliesTo: j['applies_to'] as String?,
        help: j['help'] as String?,
        answered: j['answered'] as bool? ?? false,
        value: j['value'],
        recordedAt: parseDate(j['recorded_at']),
        recordedByRole: j['recorded_by_role'] as String?,
        needsUpdate: j['needs_update'] as bool? ?? false,
      );
}

class HealthProfile {
  const HealthProfile({required this.patientId, required this.groups, required this.fields, this.sex, this.body = BodyMeasurements.empty});
  final String patientId;
  final String? sex;
  final BodyMeasurements body;
  final List<Option> groups;
  final List<HealthProfileField> fields;

  List<HealthProfileField> fieldsIn(String group) => [for (final f in fields) if (f.group == group && f.appliesToSex(sex)) f];

  factory HealthProfile.fromJson(Map<String, dynamic> j) => HealthProfile(
        patientId: j['patient_id'] as String,
        sex: j['sex'] as String?,
        body: BodyMeasurements.fromJson(j['body'] as Map<String, dynamic>?),
        groups: [for (final g in j['groups'] as List) Option(g['key'] as String, g['label'] as String)],
        fields: [for (final f in j['fields'] as List) HealthProfileField.fromJson(f as Map<String, dynamic>)],
      );
}

/// A measure SUSTHITI can take from a report (HbA1c, glucose values, the report's conclusion).
class AnalyteSpec {
  const AnalyteSpec({required this.key, required this.label, required this.kind, this.unit, this.units = const [], this.options = const []});
  final String key;
  final String label;
  final String kind; // number | classification
  final String? unit;
  final List<String> units;
  final List<Option> options;

  bool get isClassification => kind == 'classification';

  factory AnalyteSpec.fromJson(Map<String, dynamic> j) => AnalyteSpec(
        key: j['key'] as String,
        label: j['label'] as String,
        kind: j['kind'] as String,
        unit: j['unit'] as String?,
        units: [for (final u in j['units'] as List? ?? const []) u as String],
        options: [for (final o in j['options'] as List? ?? const []) Option.fromJson(o as Map<String, dynamic>)],
      );
}

/// A value confirmed from a report by the patient or a doctor.
class ConfirmedReportValue {
  const ConfirmedReportValue({required this.analyte, required this.label, this.value, this.textValue, this.unit, this.enteredValue, this.enteredUnit, this.origin, this.confirmedByRole, this.confirmedAt, this.needsCheck = false});
  final String analyte;
  final String label;
  final double? value;
  final String? textValue;
  final String? unit;
  final double? enteredValue;
  final String? enteredUnit;
  final String? origin;
  final String? confirmedByRole;
  final DateTime? confirmedAt;

  /// Read automatically from the report; nobody has checked it against the report yet.
  final bool needsCheck;
  bool get readAutomatically => origin == 'auto_extracted' || origin == 'ai_extracted';

  String get display {
    if (textValue != null) return textValue![0].toUpperCase() + textValue!.substring(1);
    final shown = '${_num(value)} $unit'.trim();
    if (enteredUnit != null && enteredUnit != unit && enteredValue != null) return '$shown (${_num(enteredValue)} $enteredUnit in the report)';
    return shown;
  }

  factory ConfirmedReportValue.fromJson(Map<String, dynamic> j) => ConfirmedReportValue(
        analyte: j['analyte'] as String,
        label: j['label'] as String,
        value: (j['value'] as num?)?.toDouble(),
        textValue: j['text_value'] as String?,
        unit: j['unit'] as String?,
        enteredValue: (j['entered_value'] as num?)?.toDouble(),
        enteredUnit: j['entered_unit'] as String?,
        origin: j['origin'] as String?,
        confirmedByRole: j['confirmed_by_role'] as String?,
        confirmedAt: parseDate(j['confirmed_at']),
        needsCheck: j['needs_check'] as bool? ?? false,
      );
}

/// A value the AI report summary found that maps exactly to a known measure (needs confirming).
class ReportValueSuggestion {
  const ReportValueSuggestion({required this.analyte, required this.label, required this.value, required this.unit, required this.enteredValue, required this.enteredUnit, this.sourceName});
  final String analyte;
  final String label;
  final double value;
  final String unit;
  final double enteredValue;
  final String enteredUnit;
  final String? sourceName;

  factory ReportValueSuggestion.fromJson(Map<String, dynamic> j) => ReportValueSuggestion(
        analyte: j['analyte'] as String,
        label: j['label'] as String,
        value: (j['value'] as num).toDouble(),
        unit: j['unit'] as String,
        enteredValue: (j['entered_value'] as num).toDouble(),
        enteredUnit: j['entered_unit'] as String,
        sourceName: j['source_name'] as String?,
      );
}

class ReportValues {
  const ReportValues({required this.reportId, required this.values, required this.suggestions, required this.analytes, this.reportCode, this.reportDate, this.extractionNote, this.extractedAt});
  final String reportId;
  final String? reportCode;
  final DateTime? reportDate;
  final List<ConfirmedReportValue> values;
  final List<ReportValueSuggestion> suggestions;
  final List<AnalyteSpec> analytes;

  /// What automatic reading found (or why it couldn't), and when it ran.
  final String? extractionNote;
  final DateTime? extractedAt;

  ConfirmedReportValue? valueOf(String analyte) => values.where((v) => v.analyte == analyte).firstOrNull;

  factory ReportValues.fromJson(Map<String, dynamic> j) => ReportValues(
        reportId: j['report_id'] as String,
        reportCode: j['report_code'] as String?,
        reportDate: parseDate(j['report_date']),
        values: [for (final v in j['values'] as List) ConfirmedReportValue.fromJson(v as Map<String, dynamic>)],
        suggestions: [for (final s in j['suggestions'] as List) ReportValueSuggestion.fromJson(s as Map<String, dynamic>)],
        analytes: [for (final a in j['analytes'] as List) AnalyteSpec.fromJson(a as Map<String, dynamic>)],
        extractionNote: (j['extraction'] as Map<String, dynamic>?)?['note'] as String?,
        extractedAt: parseDate((j['extraction'] as Map<String, dynamic>?)?['at']),
      );
}

String _num(double? v) => v == null ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());
