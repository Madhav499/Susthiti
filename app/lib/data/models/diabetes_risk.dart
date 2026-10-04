import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';


/// Wording rules for the future diabetes risk estimate (SUSTHITI Diabetes Risk API v4).
/// It is a model-estimated screening estimate trained on synthetic data: never a diagnosis,
/// never a statement that someone has, will get, or will not get diabetes.
abstract final class RiskWording {
  static const title = 'Future Diabetes Risk';
  static const estimateLabel = 'Model-estimated risk';
  static const safety =
      'This is a research and screening estimate from a machine-learning model trained on synthetic data. It is not clinically validated and is not a medical diagnosis. Talk to your doctor about your results.';
  static const noReportBasis = 'Based on available symptoms and risk factors. No medical report values were used.';

  static String reportBasis(String? fieldsLabel) =>
      fieldsLabel == null ? 'Includes values from your medical reports.' : 'Includes $fieldsLabel from your medical reports.';

  static StatusTone tone(String category) => switch (category) {
        'High' => StatusTone.critical,
        'Moderate' => StatusTone.attention,
        _ => StatusTone.positive,
      };

  static String categoryLabel(String category) => '$category risk';

  static String percent(double value) => '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}%';
}

class DataItem {
  const DataItem({required this.feature, required this.label, required this.value, this.source, this.detail, this.recordedAt, this.reportCode});
  final String feature;
  final String label;
  final String value;
  final String? source;
  final String? detail;
  final DateTime? recordedAt;
  final String? reportCode;

  factory DataItem.fromJson(Map<String, dynamic> j) => DataItem(
        feature: j['feature'] as String,
        label: j['label'] as String,
        value: j['value'] as String? ?? '',
        source: j['source'] as String?,
        detail: j['detail'] as String?,
        recordedAt: parseDate(j['recorded_at']),
        reportCode: j['report_code'] as String?,
      );
}

class DataGroup {
  const DataGroup({required this.key, required this.label, required this.items});
  final String key;
  final String label;
  final List<DataItem> items;

  factory DataGroup.fromJson(Map<String, dynamic> j) =>
      DataGroup(key: j['key'] as String, label: j['label'] as String, items: [for (final i in j['items'] as List) DataItem.fromJson(i as Map<String, dynamic>)]);
}

/// Where missing information can be added in SUSTHITI.
enum AddDataTarget {
  profile,
  healthProfile,
  reportValues,
  healthConnection,
  /// No standalone destination: only ever answered on the heart assessment form itself
  /// (symptoms, cardiac test results). See HeartAddDataTarget-equivalent handling in
  /// risk_widgets.dart's addDataRoute(), which returns no route for this case.
  heartAssessmentForm;

  static AddDataTarget parse(String? v) => switch (v) {
        'profile' => profile,
        'report_values' => reportValues,
        'health_connection' => healthConnection,
        'heart_assessment_form' => heartAssessmentForm,
        _ => healthProfile,
      };
}

class MissingItem {
  const MissingItem({required this.feature, required this.label, required this.reason, required this.group, required this.groupLabel, required this.target});
  final String feature;
  final String label;
  final String reason;
  final String group;
  final String groupLabel;
  final AddDataTarget target;

  factory MissingItem.fromJson(Map<String, dynamic> j) => MissingItem(
        feature: j['feature'] as String,
        label: j['label'] as String,
        reason: j['reason'] as String? ?? 'Not recorded',
        group: j['group'] as String? ?? 'profile',
        groupLabel: j['group_label'] as String? ?? '',
        target: AddDataTarget.parse(j['how_to_add'] as String?),
      );
}

/// Which health information an assessment used, grouped by where it came from, and what's missing.
class DataUsed {
  const DataUsed({required this.groups, required this.missing, required this.availableCount, required this.totalCount});
  final List<DataGroup> groups;
  final List<MissingItem> missing;
  final int availableCount;
  final int totalCount;

  static const empty = DataUsed(groups: [], missing: [], availableCount: 0, totalCount: 0);

  factory DataUsed.fromJson(Map<String, dynamic>? j) => j == null
      ? empty
      : DataUsed(
          groups: [for (final g in j['groups'] as List? ?? const []) DataGroup.fromJson(g as Map<String, dynamic>)],
          missing: [for (final m in j['missing'] as List? ?? const []) MissingItem.fromJson(m as Map<String, dynamic>)],
          availableCount: j['available_count'] as int? ?? 0,
          totalCount: j['total_count'] as int? ?? 0,
        );
}

/// One stored, immutable future diabetes risk estimate. Every number and label is the API's own.
class RiskAssessment {
  const RiskAssessment({
    required this.id,
    required this.createdAt,
    required this.riskPercent,
    required this.riskCategory,
    required this.prediction,
    required this.predictionLabel,
    required this.predictionBasis,
    required this.reportAvailable,
    required this.reportFieldsPresent,
    required this.modelVersion,
    this.code,
    this.patientId,
    this.riskThresholds = const {},
    this.predictionThreshold,
    this.bmi,
    this.warning,
    this.performedByRole,
    this.reportFieldsLabel,
    this.dataUsed = DataUsed.empty,
    this.inputFeatures = const {},
  });

  final String id;
  final String? code;
  final String? patientId;
  final DateTime createdAt;
  final double riskPercent;
  final String riskCategory;
  final Map<String, String> riskThresholds;
  final int prediction;
  final String predictionLabel;
  final String? predictionThreshold;
  final String predictionBasis;
  final bool reportAvailable;
  final List<String> reportFieldsPresent;
  final double? bmi;
  final String modelVersion;
  final String? warning;
  final String? performedByRole;
  final String? reportFieldsLabel;
  final DataUsed dataUsed;

  /// Exactly what was sent to the model (only on the detail endpoint).
  final Map<String, Object?> inputFeatures;

  String get percentLabel => RiskWording.percent(riskPercent);
  String get basisText => reportAvailable ? RiskWording.reportBasis(reportFieldsLabel) : RiskWording.noReportBasis;

  factory RiskAssessment.fromJson(Map<String, dynamic> j) {
    final risk = j['risk_percent'];
    final category = j['risk_category'];
    if (risk is! num || category is! String) throw const FormatException('Incomplete risk assessment');
    return RiskAssessment(
      id: j['id'] as String,
      code: j['code'] as String?,
      patientId: j['patient_id'] as String?,
      createdAt: parseDate(j['created_at'])!,
      riskPercent: risk.toDouble(),
      riskCategory: category,
      riskThresholds: {for (final e in (j['risk_thresholds'] as Map<String, dynamic>? ?? const {}).entries) e.key: '${e.value}'},
      prediction: j['prediction'] as int? ?? 0,
      predictionLabel: j['prediction_label'] as String? ?? '',
      predictionThreshold: j['prediction_threshold'] as String?,
      predictionBasis: j['prediction_basis'] as String? ?? '',
      reportAvailable: j['report_available'] as bool? ?? false,
      reportFieldsPresent: [for (final f in j['report_fields_present'] as List? ?? const []) f as String],
      bmi: (j['bmi'] as num?)?.toDouble(),
      modelVersion: j['model_version'] as String? ?? '',
      warning: j['warning'] as String?,
      performedByRole: j['performed_by_role'] as String?,
      reportFieldsLabel: j['report_fields_label'] as String?,
      dataUsed: DataUsed.fromJson(j['data_used'] as Map<String, dynamic>?),
      inputFeatures: Map<String, Object?>.from(j['input_features'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

/// The latest assessment, whether the patient's data has changed since, and what a refresh would use.
class RiskStatus {
  const RiskStatus({
    this.latest,
    this.stale = false,
    this.staleReasons = const [],
    this.currentData = DataUsed.empty,
    this.historyTotal = 0,
    this.earlierModelTotal = 0,
    this.offline = false,
    this.raw = const {},
  });

  final RiskAssessment? latest;
  final bool stale;
  final List<String> staleReasons;
  final DataUsed currentData;
  final int historyTotal;
  final int earlierModelTotal;

  /// Shown from this device's cache because SUSTHITI couldn't be reached.
  final bool offline;

  /// The server response, kept for the offline cache.
  final Map<String, dynamic> raw;

  factory RiskStatus.fromJson(Map<String, dynamic> j, {bool offline = false}) => RiskStatus(
        latest: j['latest'] == null ? null : RiskAssessment.fromJson(j['latest'] as Map<String, dynamic>),
        stale: j['stale'] as bool? ?? false,
        staleReasons: [for (final r in j['stale_reasons'] as List? ?? const []) r as String],
        currentData: DataUsed.fromJson(j['current_data'] as Map<String, dynamic>?),
        historyTotal: j['history_total'] as int? ?? 0,
        earlierModelTotal: j['earlier_model_total'] as int? ?? 0,
        offline: offline,
        raw: j,
      );
}

class RiskRefresh {
  const RiskRefresh({required this.created, required this.assessment});
  final bool created;
  final RiskAssessment assessment;

  factory RiskRefresh.fromJson(Map<String, dynamic> j) => RiskRefresh(created: j['created'] as bool? ?? true, assessment: RiskAssessment.fromJson(j['assessment'] as Map<String, dynamic>));
}

/// Short form used by dashboards, lists and admin views.
class RiskBrief {
  const RiskBrief({required this.id, required this.riskPercent, required this.riskCategory, required this.assessedAt, this.predictionLabel, this.reportAvailable = false, this.modelVersion});
  final String id;
  final double riskPercent;
  final String riskCategory;
  final DateTime assessedAt;
  final String? predictionLabel;
  final bool reportAvailable;
  final String? modelVersion;

  String get percentLabel => RiskWording.percent(riskPercent);

  static RiskBrief? maybe(Object? j) {
    if (j is! Map<String, dynamic> || j['risk_percent'] is! num || j['risk_category'] is! String) return null;
    return RiskBrief(
      id: j['id'] as String,
      riskPercent: (j['risk_percent'] as num).toDouble(),
      riskCategory: j['risk_category'] as String,
      assessedAt: parseDate(j['assessed_at'] ?? j['created_at'])!,
      predictionLabel: j['prediction_label'] as String?,
      reportAvailable: j['report_available'] as bool? ?? false,
      modelVersion: j['model_version'] as String?,
    );
  }
}
