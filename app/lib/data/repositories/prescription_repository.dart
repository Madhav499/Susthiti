
import '../../core/services/api_client.dart';
import '../../core/utils/formatters.dart';
import '../models/care.dart';

abstract interface class PrescriptionRepository {
  Future<List<Prescription>> list(String patientId, {String query = ''});
  Future<Prescription> get(String prescriptionId);

  /// Always creates a new prescription; existing ones are never modified.
  Future<Prescription> create(String patientId, {required DateTime prescribedOn, required List<Medicine> medicines, String? instructions, String? notes, DateTime? followUpDate});
}

class ApiPrescriptionRepository implements PrescriptionRepository {
  ApiPrescriptionRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<Prescription>> list(String patientId, {String query = ''}) async {
    final r = await _api.get('/patients/$patientId/prescriptions', query: {'q': query.trim()});
    return [for (final p in r['items'] as List) Prescription.fromJson(p as Json)];
  }

  @override
  Future<Prescription> get(String prescriptionId) async => Prescription.fromJson(await _api.get('/prescriptions/$prescriptionId'));

  @override
  Future<Prescription> create(String patientId, {required DateTime prescribedOn, required List<Medicine> medicines, String? instructions, String? notes, DateTime? followUpDate}) async =>
      Prescription.fromJson(await _api.post('/patients/$patientId/prescriptions', body: {
        'prescribed_on': Fmt.isoDate(prescribedOn),
        'medicines': [for (final m in medicines) m.toJson()],
        'instructions': instructions,
        'notes': notes,
        'follow_up_date': followUpDate == null ? null : Fmt.isoDate(followUpDate),
      }));
}
