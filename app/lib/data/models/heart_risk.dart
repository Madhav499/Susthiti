import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'diabetes_risk.dart' show DataUsed;

export 'diabetes_risk.dart' show DataUsed, DataGroup, DataItem, MissingItem, AddDataTarget;

/// Wording rules for the heart disease risk SCREENING (supplied model susthiti-heart-v3).
/// It is a screening signal from a machine-learning model trained on a 20,000-row SYNTHETIC
/// dataset: never a diagnosis, never a statement that someone has, will get, or will not get
/// heart disease. Mirrors diabetes_risk.dart's RiskWording for the sibling feature.
abstract final class HeartWording {
  static const title = 'Heart Disease Risk Screening';
  static const estimateLabel = 'Model screening result';
  static const safety =
      'This is a research and screening estimate from a machine-learning model trained on synthetic data. It is not clinically validated and is not a medical diagnosis. Talk to your doctor about your results.';
  static const noReportBasis = 'Based on available symptoms and risk factors. No medical report values were used.';

  static String reportBasis(String? fieldsLabel) =>
      fieldsLabel == null ? 'Includes values from your medical reports.' : 'Includes $fieldsLabel from your medical reports.';

  static StatusTone tone(String riskLevel) => switch (riskLevel) {
        'high' => StatusTone.critical,
        'moderate' => StatusTone.attention,
        _ => StatusTone.positive,
      };

  /// e.g. "Elevated risk signal" / "No elevated risk signal" -- never "you have heart disease".
  static String signalLabel(String riskLevel) => switch (riskLevel) {
        'high' => 'Elevated risk signal',
        'moderate' => 'Moderate risk signal',
        _ => 'Low risk signal',
      };

  static String percent(double value) => '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}%';
}

/// One stored, immutable heart disease risk screening result. Every number and label is the
/// API's own; the app never computes or adjusts a score.
class HeartRiskAssessment {
  const HeartRiskAssessment({
    required this.id,
    required this.createdAt,
    required this.probabilityPercent,
    required this.riskLevel,
    required this.prediction,
    required this.predictionLabel,
    required this.reportAvailable,
    required this.reportFieldsPresent,
    required this.modelVersion,
    this.code,
    this.patientId,
    this.decisionThreshold,
    this.bmi,
    this.warnings = const [],
    this.performedByRole,
    this.reportFieldsLabel,
    this.dataUsed = DataUsed.empty,
    this.inputFeatures = const {},
  });

  final String id;
  final String? code;
  final String? patientId;
  final DateTime createdAt;
  final double probabilityPercent;
  final String riskLevel; // low | moderate | high
  final int prediction;
  final String predictionLabel;
  final double? decisionThreshold;
  final bool reportAvailable;
  final List<String> reportFieldsPresent;
  final double? bmi;
  final List<String> warnings;
  final String modelVersion;
  final String? performedByRole;
  final String? reportFieldsLabel;
  final DataUsed dataUsed;

  /// Exactly what was sent to the model (only on the detail endpoint).
  final Map<String, Object?> inputFeatures;

  String get percentLabel => HeartWording.percent(probabilityPercent);
  String get basisText => reportAvailable ? HeartWording.reportBasis(reportFieldsLabel) : HeartWording.noReportBasis;
  String get signalLabel => HeartWording.signalLabel(riskLevel);

  factory HeartRiskAssessment.fromJson(Map<String, dynamic> j) {
    final probability = j['probability_percent'];
    final level = j['risk_level'];
    if (probability is! num || level is! String) throw const FormatException('Incomplete heart risk assessment');
    return HeartRiskAssessment(
      id: j['id'] as String,
      code: j['code'] as String?,
      patientId: j['patient_id'] as String?,
      createdAt: parseDate(j['created_at'])!,
      probabilityPercent: probability.toDouble(),
      riskLevel: level,
      prediction: j['prediction'] as int? ?? 0,
      predictionLabel: j['prediction_label'] as String? ?? '',
      decisionThreshold: (j['decision_threshold'] as num?)?.toDouble(),
      reportAvailable: j['report_available'] as bool? ?? false,
      reportFieldsPresent: [for (final f in j['report_fields_present'] as List? ?? const []) f as String],
      bmi: (j['bmi'] as num?)?.toDouble(),
      warnings: [for (final w in j['warnings'] as List? ?? const []) w as String],
      modelVersion: j['model_version'] as String? ?? '',
      performedByRole: j['performed_by_role'] as String?,
      reportFieldsLabel: j['report_fields_label'] as String?,
      dataUsed: DataUsed.fromJson(j['data_used'] as Map<String, dynamic>?),
      inputFeatures: Map<String, Object?>.from(j['input_features'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

/// The latest screening, whether the patient's health data has changed since, and what a bare
/// refresh would use.
class HeartRiskStatus {
  const HeartRiskStatus({
    this.latest,
    this.stale = false,
    this.staleReasons = const [],
    this.currentData = DataUsed.empty,
    this.historyTotal = 0,
    this.offline = false,
    this.raw = const {},
  });

  final HeartRiskAssessment? latest;
  final bool stale;
  final List<String> staleReasons;
  final DataUsed currentData;
  final int historyTotal;

  /// Shown from this device's cache because SUSTHITI couldn't be reached.
  final bool offline;

  /// The server response, kept for the offline cache.
  final Map<String, dynamic> raw;

  factory HeartRiskStatus.fromJson(Map<String, dynamic> j, {bool offline = false}) => HeartRiskStatus(
        latest: j['latest'] == null ? null : HeartRiskAssessment.fromJson(j['latest'] as Map<String, dynamic>),
        stale: j['stale'] as bool? ?? false,
        staleReasons: [for (final r in j['stale_reasons'] as List? ?? const []) r as String],
        currentData: DataUsed.fromJson(j['current_data'] as Map<String, dynamic>?),
        historyTotal: j['history_total'] as int? ?? 0,
        offline: offline,
        raw: j,
      );
}

class HeartRiskRefresh {
  const HeartRiskRefresh({required this.created, required this.assessment});
  final bool created;
  final HeartRiskAssessment assessment;

  factory HeartRiskRefresh.fromJson(Map<String, dynamic> j) =>
      HeartRiskRefresh(created: j['created'] as bool? ?? true, assessment: HeartRiskAssessment.fromJson(j['assessment'] as Map<String, dynamic>));
}

/// Short form used by dashboards, lists and admin views.
class HeartRiskBrief {
  const HeartRiskBrief({required this.id, required this.probabilityPercent, required this.riskLevel, required this.assessedAt, this.predictionLabel, this.reportAvailable = false, this.modelVersion});
  final String id;
  final double probabilityPercent;
  final String riskLevel;
  final DateTime assessedAt;
  final String? predictionLabel;
  final bool reportAvailable;
  final String? modelVersion;

  String get percentLabel => HeartWording.percent(probabilityPercent);

  static HeartRiskBrief? maybe(Object? j) {
    if (j is! Map<String, dynamic> || j['probability_percent'] is! num || j['risk_level'] is! String) return null;
    return HeartRiskBrief(
      id: j['id'] as String,
      probabilityPercent: (j['probability_percent'] as num).toDouble(),
      riskLevel: j['risk_level'] as String,
      assessedAt: parseDate(j['assessed_at'] ?? j['created_at'])!,
      predictionLabel: j['prediction_label'] as String?,
      reportAvailable: j['report_available'] as bool? ?? false,
      modelVersion: j['model_version'] as String?,
    );
  }
}
