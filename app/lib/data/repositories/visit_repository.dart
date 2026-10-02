
import '../../core/services/api_client.dart';
import '../models/care.dart';

abstract interface class VisitRepository {
  Future<List<Visit>> list(String patientId);
  Future<Visit> get(String visitId);
  Future<Visit> create(String patientId, Map<String, dynamic> fields);
}

class ApiVisitRepository implements VisitRepository {
  ApiVisitRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<Visit>> list(String patientId) async {
    final r = await _api.get('/patients/$patientId/visits');
    return [for (final v in r['items'] as List) Visit.fromJson(v as Json)];
  }

  @override
  Future<Visit> get(String visitId) async => Visit.fromJson(await _api.get('/visits/$visitId'));

  @override
  Future<Visit> create(String patientId, Map<String, dynamic> fields) async => Visit.fromJson(await _api.post('/patients/$patientId/visits', body: fields));
}
