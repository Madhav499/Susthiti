import '../../core/services/api_client.dart';
import '../models/heart_risk.dart';

/// Heart disease risk screening (supplied model susthiti-heart-v3), through the SUSTHITI
/// backend. The app never calls the model directly: the backend builds the model's inputs from
/// the health data it already holds, plus whatever the assessment form submits. Sibling to
/// DiabetesRepository -- independent, not an extension of it.
abstract interface class HeartRepository {
  Future<HeartRiskStatus> heartRiskStatus(String patientId);

  /// Bare refresh using only what SUSTHITI already knows (no manual form fields). Returns the
  /// existing assessment unchanged (created == false) when nothing relevant has changed.
  Future<HeartRiskRefresh> refreshHeartRisk(String patientId, {bool force = false});

  /// Assessment-form submission: `fields` is the complete, patient-reviewed set of answers
  /// (prefilled-and-confirmed or freshly typed). Always creates a new assessment.
  Future<HeartRiskRefresh> submitHeartAssessment(String patientId, Map<String, Object?> fields);

  Future<({List<HeartRiskAssessment> items, int total})> heartRiskHistory(String patientId, {int offset = 0});
  Future<HeartRiskAssessment> heartRiskAssessment(String assessmentId);
}

class ApiHeartRepository implements HeartRepository {
  ApiHeartRepository(this._api);
  final ApiClient _api;

  @override
  Future<HeartRiskStatus> heartRiskStatus(String patientId) async => HeartRiskStatus.fromJson(await _api.get('/patients/$patientId/heart-risk'));

  @override
  Future<HeartRiskRefresh> refreshHeartRisk(String patientId, {bool force = false}) async => HeartRiskRefresh.fromJson(await _api.post(
        force ? '/patients/$patientId/heart-risk?force=true' : '/patients/$patientId/heart-risk',
        // The backend checks the model service and waits for it; a bounded but generous window.
        timeout: const Duration(seconds: 45),
      ));

  @override
  Future<HeartRiskRefresh> submitHeartAssessment(String patientId, Map<String, Object?> fields) async =>
      HeartRiskRefresh.fromJson(await _api.post('/patients/$patientId/heart-risk', body: {'fields': fields}, timeout: const Duration(seconds: 45)));

  @override
  Future<({List<HeartRiskAssessment> items, int total})> heartRiskHistory(String patientId, {int offset = 0}) async {
    final r = await _api.get('/patients/$patientId/heart-risk/history', query: {'offset': offset, 'limit': 50});
    return (items: [for (final a in r['items'] as List) HeartRiskAssessment.fromJson(a as Json)], total: r['total'] as int);
  }

  @override
  Future<HeartRiskAssessment> heartRiskAssessment(String assessmentId) async => HeartRiskAssessment.fromJson(await _api.get('/heart-risk/$assessmentId'));
}
