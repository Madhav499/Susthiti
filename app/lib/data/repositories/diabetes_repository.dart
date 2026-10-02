import '../../core/services/api_client.dart';
import '../models/diabetes.dart';
import '../models/diabetes_risk.dart';

/// Future diabetes risk (SUSTHITI Diabetes Risk API v4, through the SUSTHITI backend) and the
/// read-only history of the earlier symptom-questionnaire model. The app never calls the model
/// directly and never sends patient records to it: the backend builds the model's inputs from
/// the health data it already holds.
abstract interface class DiabetesRepository {
  Future<RiskStatus> riskStatus(String patientId);

  /// Assesses again with the patient's current data. Returns the existing assessment unchanged
  /// (created == false) when nothing relevant has changed.
  Future<RiskRefresh> refreshRisk(String patientId, {bool force = false});
  Future<({List<RiskAssessment> items, int total})> riskHistory(String patientId, {int offset = 0});
  Future<RiskAssessment> riskAssessment(String assessmentId);

  Future<({List<DiabetesAssessment> items, int total})> earlierHistory(String patientId, {int offset = 0});
  Future<DiabetesAssessment> earlierAssessment(String assessmentId);
}

class ApiDiabetesRepository implements DiabetesRepository {
  ApiDiabetesRepository(this._api);
  final ApiClient _api;

  @override
  Future<RiskStatus> riskStatus(String patientId) async => RiskStatus.fromJson(await _api.get('/patients/$patientId/diabetes-risk'));

  @override
  Future<RiskRefresh> refreshRisk(String patientId, {bool force = false}) async => RiskRefresh.fromJson(await _api.post(
        force ? '/patients/$patientId/diabetes-risk?force=true' : '/patients/$patientId/diabetes-risk',
        // The backend checks the model service and waits for it; a bounded but generous window.
        timeout: const Duration(seconds: 45),
      ));

  @override
  Future<({List<RiskAssessment> items, int total})> riskHistory(String patientId, {int offset = 0}) async {
    final r = await _api.get('/patients/$patientId/diabetes-risk/history', query: {'offset': offset, 'limit': 50});
    return (items: [for (final a in r['items'] as List) RiskAssessment.fromJson(a as Json)], total: r['total'] as int);
  }

  @override
  Future<RiskAssessment> riskAssessment(String assessmentId) async => RiskAssessment.fromJson(await _api.get('/diabetes-risk/$assessmentId'));

  @override
  Future<({List<DiabetesAssessment> items, int total})> earlierHistory(String patientId, {int offset = 0}) async {
    final r = await _api.get('/patients/$patientId/assessments', query: {'offset': offset, 'limit': 20});
    return (items: [for (final a in r['items'] as List) DiabetesAssessment.fromJson(a as Json)], total: r['total'] as int);
  }

  @override
  Future<DiabetesAssessment> earlierAssessment(String assessmentId) async => DiabetesAssessment.fromJson(await _api.get('/assessments/$assessmentId'));
}
