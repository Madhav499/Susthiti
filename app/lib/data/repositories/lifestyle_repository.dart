
import '../../core/services/api_client.dart';
import '../../core/utils/formatters.dart';
import '../models/tracking.dart';

abstract interface class LifestyleRepository {
  Future<LifestyleOverview> overview(String patientId);
  Future<void> addManual(String patientId, {required LifestyleMetricType metric, required double value, double? value2, required DateTime recordedAt});
}

class ApiLifestyleRepository implements LifestyleRepository {
  ApiLifestyleRepository(this._api);
  final ApiClient _api;

  @override
  Future<LifestyleOverview> overview(String patientId) async => LifestyleOverview.fromJson(await _api.get('/patients/$patientId/lifestyle/overview'));

  @override
  Future<void> addManual(String patientId, {required LifestyleMetricType metric, required double value, double? value2, required DateTime recordedAt}) => _api.post(
        '/patients/$patientId/lifestyle',
        body: {
          'metric_type': metric.apiValue, 'value': value, 'value2': value2,
          'recorded_at': recordedAt.toUtc().toIso8601String(),
          'local_date': Fmt.isoDate(DateTime(recordedAt.year, recordedAt.month, recordedAt.day)),
        },
      );
}

abstract interface class WearableRepository {
  Future<List<WearableProvider>> providers();
  Future<List<WearableConnection>> devices();
  Future<WearableConnection> connect(String providerId, {List<String>? grantedMetrics, String? platform});
  Future<SyncOutcome> sync(String connectionId, {List<Map<String, Object?>>? samples, List<String>? grantedMetrics});
  Future<void> disconnect(String connectionId);
}

class ApiWearableRepository implements WearableRepository {
  ApiWearableRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<WearableProvider>> providers() async {
    final r = await _api.get('/wearables/providers');
    return [for (final p in r['items'] as List) WearableProvider.fromJson(p as Json)];
  }

  @override
  Future<List<WearableConnection>> devices() async {
    final r = await _api.get('/wearables');
    return [for (final d in r['items'] as List) WearableConnection.fromJson(d as Json)];
  }

  @override
  Future<WearableConnection> connect(String providerId, {List<String>? grantedMetrics, String? platform}) async => WearableConnection.fromJson(await _api.post(
        '/wearables/connect',
        body: {'provider': providerId, 'granted_metrics': ?grantedMetrics, 'platform': ?platform},
      ));

  @override
  Future<SyncOutcome> sync(String connectionId, {List<Map<String, Object?>>? samples, List<String>? grantedMetrics}) async {
    final r = await _api.post(
      '/wearables/$connectionId/sync',
      body: {'samples': samples, 'granted_metrics': ?grantedMetrics},
      timeout: const Duration(seconds: 60),
    );
    return SyncOutcome.fromJson(r);
  }

  @override
  Future<void> disconnect(String connectionId) => _api.post('/wearables/$connectionId/disconnect');
}
