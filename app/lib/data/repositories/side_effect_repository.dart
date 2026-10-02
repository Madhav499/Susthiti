
import '../../core/services/api_client.dart';
import '../models/care.dart';

abstract interface class SideEffectRepository {
  Future<List<SideEffect>> list(String patientId);
  Future<SideEffect> get(String sideEffectId);
  Future<SideEffect> report(String patientId, {required String description, required Severity severity, String? relatedMedication, required DateTime occurredAt, String? notes});
  Future<SideEffect> respond(String sideEffectId, {required DoctorResponse response, String? message, String? appointmentReason, DateTime? appointmentFor});
  Future<SideEffect> setStatus(String sideEffectId, SideEffectStatus status, {String? message});
}

class ApiSideEffectRepository implements SideEffectRepository {
  ApiSideEffectRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<SideEffect>> list(String patientId) async {
    final r = await _api.get('/patients/$patientId/side-effects');
    return [for (final s in r['items'] as List) SideEffect.fromJson(s as Json)];
  }

  @override
  Future<SideEffect> get(String sideEffectId) async => SideEffect.fromJson(await _api.get('/side-effects/$sideEffectId'));

  @override
  Future<SideEffect> report(String patientId, {required String description, required Severity severity, String? relatedMedication, required DateTime occurredAt, String? notes}) async =>
      SideEffect.fromJson(await _api.post('/patients/$patientId/side-effects', body: {
        'description': description.trim(),
        'severity': severity.name,
        'related_medication': (relatedMedication?.trim().isEmpty ?? true) ? null : relatedMedication!.trim(),
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'notes': (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
      }));

  @override
  Future<SideEffect> respond(String sideEffectId, {required DoctorResponse response, String? message, String? appointmentReason, DateTime? appointmentFor}) async =>
      SideEffect.fromJson(await _api.post('/side-effects/$sideEffectId/responses', body: {
        'response_type': response.apiValue,
        'message': message,
        'appointment_reason': appointmentReason,
        'appointment_for': appointmentFor?.toUtc().toIso8601String(),
      }));

  @override
  Future<SideEffect> setStatus(String sideEffectId, SideEffectStatus status, {String? message}) async =>
      SideEffect.fromJson(await _api.post('/side-effects/$sideEffectId/status', body: {'status': status.apiValue, 'message': message}));
}
