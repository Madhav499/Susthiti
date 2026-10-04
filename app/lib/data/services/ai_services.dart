import '../../core/config/app_config.dart';
import '../../core/services/api_client.dart';
import '../models/ai_summary.dart';

AISummary? _summaryOrNull(Json r) => r['summary'] == null ? null : AISummary.fromJson(r['summary'] as Json);

/// Report AI (#1): individual report summaries and the all-reports summary.
/// These are different questions and stay separate features.
class ReportAIService {
  ReportAIService(this._api);
  final ApiClient _api;

  /// "What does this particular report say?"
  Future<AISummary?> individualSummary(String reportId) async => _summaryOrNull(await _api.get('/reports/$reportId/summary'));

  Future<AISummary> generateIndividual(String reportId) async => _summaryOrNull(await _api.post('/reports/$reportId/summary', timeout: AppConfig.aiTimeout))!;

  /// "What does the patient's collection of reports show over time?"
  Future<({AISummary? summary, int reportCount})> allReportsSummary(String patientId) async {
    final r = await _api.get('/patients/$patientId/reports-summary');
    return (summary: _summaryOrNull(r), reportCount: r['report_count'] as int? ?? 0);
  }

  Future<AISummary> generateAllReports(String patientId, {List<String>? reportIds}) async =>
      _summaryOrNull(await _api.post('/patients/$patientId/reports-summary', body: {'report_ids': reportIds}, timeout: AppConfig.aiTimeout))!;
}

/// Patient AI: longitudinal summary of the authorized record.
class PatientAIService {
  PatientAIService(this._api);
  final ApiClient _api;

  Future<AISummary?> latest(String patientId) async => _summaryOrNull(await _api.get('/patients/$patientId/patient-summary'));

  Future<AISummary> generate(String patientId) async => _summaryOrNull(await _api.post('/patients/$patientId/patient-summary', timeout: AppConfig.aiTimeout))!;

  /// "Your Health Summary": a separate, plain-language generation for the patient themselves.
  Future<AISummary?> latestFriendly(String patientId) async => _summaryOrNull(await _api.get('/patients/$patientId/friendly-summary'));

  Future<AISummary> generateFriendly(String patientId) async => _summaryOrNull(await _api.post('/patients/$patientId/friendly-summary', timeout: AppConfig.aiTimeout))!;
}

/// Lifestyle AI: lifestyle suggestions and the forward-looking interpretation of an assessment
/// (an AI interpretation, never a new ML prediction).
class LifestyleAIService {
  LifestyleAIService(this._api);
  final ApiClient _api;

  Future<AISummary?> latestInsight(String patientId) async => _summaryOrNull(await _api.get('/patients/$patientId/lifestyle-insight'));

  Future<AISummary> generateInsight(String patientId) async => _summaryOrNull(await _api.post('/patients/$patientId/lifestyle-insight', timeout: AppConfig.aiTimeout))!;

  Future<AISummary> interpretAssessment(String assessmentId) async => _summaryOrNull(await _api.post('/assessments/$assessmentId/interpretation', timeout: AppConfig.aiTimeout))!;

  /// Same interpretation pattern, for a heart risk screening assessment (a separate,
  /// synthetic-data model -- never a diagnosis). Parallel endpoint, not a generalization of
  /// [interpretAssessment], so diabetes interpretation is untouched.
  Future<AISummary> interpretHeartAssessment(String assessmentId) async =>
      _summaryOrNull(await _api.post('/heart-risk/$assessmentId/interpretation', timeout: AppConfig.aiTimeout))!;
}

/// AIRepository groups the separate AI services for injection. It deliberately has no
/// "do everything" method.
class AIRepository {
  AIRepository(ApiClient api)
      : reports = ReportAIService(api),
        patient = PatientAIService(api),
        lifestyle = LifestyleAIService(api);

  final ReportAIService reports;
  final PatientAIService patient;
  final LifestyleAIService lifestyle;
}
