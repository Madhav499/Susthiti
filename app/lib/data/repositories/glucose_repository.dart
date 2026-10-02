
import '../../core/services/api_client.dart';
import '../../core/utils/formatters.dart';
import '../models/tracking.dart';

abstract interface class GlucoseRepository {
  Future<GlucoseReading> add(String patientId, {required double value, required String unit, required GlucoseReadingType type, required DateTime measuredAt, String? context});
  Future<List<GlucoseReading>> list(String patientId, {DateTime? start, DateTime? end, int limit = 100});
  Future<GlucoseOverview> overview(String patientId);
}

class ApiGlucoseRepository implements GlucoseRepository {
  ApiGlucoseRepository(this._api);
  final ApiClient _api;

  @override
  Future<GlucoseReading> add(String patientId, {required double value, required String unit, required GlucoseReadingType type, required DateTime measuredAt, String? context}) async =>
      GlucoseReading.fromJson(await _api.post('/patients/$patientId/glucose', body: {
        'value': value,
        'unit': unit,
        'reading_type': type.apiValue,
        'measured_at': measuredAt.toUtc().toIso8601String(),
        'source': 'manual',
        'context': (context?.trim().isEmpty ?? true) ? null : context!.trim(),
      }));

  @override
  Future<List<GlucoseReading>> list(String patientId, {DateTime? start, DateTime? end, int limit = 100}) async {
    final r = await _api.get('/patients/$patientId/glucose', query: {
      'start': start == null ? null : Fmt.isoDate(start),
      'end': end == null ? null : Fmt.isoDate(end),
      'limit': limit,
    });
    return [for (final g in r['items'] as List) GlucoseReading.fromJson(g as Json)];
  }

  @override
  Future<GlucoseOverview> overview(String patientId) async => GlucoseOverview.fromJson(await _api.get('/patients/$patientId/glucose/overview'));
}
