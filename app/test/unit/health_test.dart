import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/data/datasources/health_platform.dart';
import 'package:susthiti/data/models/health.dart';
import 'package:susthiti/data/models/tracking.dart';
import 'package:susthiti/data/repositories/lifestyle_repository.dart';
import 'package:susthiti/data/services/wearable_service.dart';

class MockWearableRepository extends Mock implements WearableRepository {}

/// TEST double for a phone's health store.
class FakeHealthPlatform implements HealthPlatform {
  FakeHealthPlatform({this.grant = const {...HealthMetric.values}, this.status = HealthAvailability.available});
  Set<HealthMetric> grant;
  HealthAvailability status;
  final requested = <Set<HealthMetric>>[];
  final readCalls = <String>[];

  @override
  String? get providerId => 'health_connect';
  @override
  String get name => 'Health Connect';
  @override
  String? get platform => 'android';
  @override
  Future<HealthAvailability> availability() async => status;
  @override
  Future<Set<HealthMetric>> requestPermissions(Set<HealthMetric> metrics) async {
    requested.add(metrics);
    return grant.intersection(metrics);
  }

  @override
  Future<Set<HealthMetric>> grantedPermissions(Set<HealthMetric> metrics) async => grant.intersection(metrics);
  @override
  Future<void> install() async {}
  @override
  Future<List<StepReading>> getSteps(DateTime from, DateTime to) async {
    readCalls.add('steps');
    return [StepReading(steps: 7420, startTime: DateTime(2026, 9, 20), endTime: DateTime(2026, 9, 20, 21))];
  }

  @override
  Future<List<HeartRateReading>> getHeartRate(DateTime from, DateTime to) async {
    readCalls.add('heart_rate');
    return [HeartRateReading(bpm: 82, timestamp: DateTime(2026, 9, 20, 10, 32), externalId: 'hc-1')];
  }

  @override
  Future<List<SleepReading>> getSleep(DateTime from, DateTime to) async {
    readCalls.add('sleep');
    return const [];
  }

  @override
  Future<List<BloodPressureReading>> getBloodPressure(DateTime from, DateTime to) async {
    readCalls.add('blood_pressure');
    return const [];
  }

  @override
  Future<List<SpO2Reading>> getSpO2(DateTime from, DateTime to) async {
    readCalls.add('spo2');
    return const [];
  }

  @override
  Future<List<ActivityReading>> getActivity(DateTime from, DateTime to) async {
    readCalls.add('activity');
    return const [];
  }

  @override
  Future<List<CaloriesReading>> getCalories(DateTime from, DateTime to) async {
    readCalls.add('calories');
    return const [];
  }
}

WearableConnection connection({DateTime? lastSynced, String provider = 'health_connect', bool demo = false}) => WearableConnection(
      id: 'c1', provider: provider, deviceName: 'Android Health Connect', status: 'connected', lastSyncedAt: lastSynced,
      supportedMetrics: const ['steps', 'heart_rate'], grantedMetrics: const ['steps', 'heart_rate'], platform: 'android', isDemo: demo,
    );

void main() {
  setUpAll(() => registerFallbackValue(<String>[]));

  group('readings', () {
    test('daily totals and readings serialize with measurement time, local date and source', () {
      final steps = StepReading(steps: 7420, startTime: DateTime(2026, 9, 20), endTime: DateTime(2026, 9, 20, 21)).toSample();
      expect(steps['metric_type'], 'steps');
      expect(steps['value'], 7420);
      expect(steps['daily_total'], isTrue);
      expect(steps['local_date'], '2026-09-20');
      expect(steps['recorded_at'], DateTime(2026, 9, 20, 21).toUtc().toIso8601String());
      expect(steps['started_at'], DateTime(2026, 9, 20).toUtc().toIso8601String());

      final hr = HeartRateReading(bpm: 82, timestamp: DateTime(2026, 9, 20, 10, 32), externalId: 'hc-1').toSample();
      expect(hr.containsKey('daily_total'), isFalse);
      expect(hr['external_id'], 'hc-1');
      expect(hr['recorded_at'], endsWith('Z')); // always UTC on the wire

      final bp = BloodPressureReading(systolic: 124, diastolic: 81, timestamp: DateTime(2026, 9, 20, 9)).toSample();
      expect((bp['value'], bp['value2']), (124.0, 81.0));

      // A night belongs to the day you wake up.
      final sleep = SleepReading(startTime: DateTime(2026, 9, 19, 23), endTime: DateTime(2026, 9, 20, 6, 30), duration: const Duration(hours: 7)).toSample();
      expect((sleep['local_date'], sleep['value']), ('2026-09-20', 420.0));
    });

    test('data sources have readable labels', () {
      expect(DataSource.parse('health_platform').label, 'Health Platform');
      expect(DataSource.parse('unknown'), DataSource.manual);
      expect(DailyValue(date: _d, value: 1, sources: const ['health_platform', 'manual']).sourceLabel, 'Health Platform + Manual');
    });
  });

  group('WearableService', () {
    late MockWearableRepository repo;
    setUp(() {
      repo = MockWearableRepository();
      when(() => repo.connect(any(), grantedMetrics: any(named: 'grantedMetrics'), platform: any(named: 'platform'))).thenAnswer((_) async => connection());
      when(() => repo.sync(any(), samples: any(named: 'samples'), grantedMetrics: any(named: 'grantedMetrics')))
          .thenAnswer((_) async => SyncOutcome(device: connection(lastSynced: DateTime.now()), imported: 2));
    });

    test('connect asks for permission, registers what was granted, then syncs', () async {
      final platform = FakeHealthPlatform();
      final outcome = await WearableService(repo, platform).connect();
      expect(outcome.imported, 2);
      expect(platform.requested.single, {...HealthMetric.values});
      final granted = verify(() => repo.connect('health_connect', grantedMetrics: captureAny(named: 'grantedMetrics'), platform: 'android')).captured.single as List<String>;
      expect(granted.toSet(), {for (final m in HealthMetric.values) m.apiValue});
    });

    test('a refusal never reaches the backend', () async {
      final platform = FakeHealthPlatform(grant: {});
      await expectLater(WearableService(repo, platform).connect(), throwsA(isA<WearableAuthorizationDenied>()));
      verifyNever(() => repo.connect(any(), grantedMetrics: any(named: 'grantedMetrics'), platform: any(named: 'platform')));
    });

    test('Health Connect missing is reported before any permission prompt', () async {
      final platform = FakeHealthPlatform(status: HealthAvailability.needsInstall);
      await expectLater(WearableService(repo, platform).connect(), throwsA(isA<HealthNeedsInstall>()));
      expect(platform.requested, isEmpty);
    });

    test('sync only reads metrics the patient granted and uploads them with the grant list', () async {
      final platform = FakeHealthPlatform(grant: {HealthMetric.steps, HealthMetric.heartRate});
      await WearableService(repo, platform).sync(connection());
      expect(platform.readCalls.toSet(), {'steps', 'heart_rate'});
      final captured = verify(() => repo.sync('c1', samples: captureAny(named: 'samples'), grantedMetrics: captureAny(named: 'grantedMetrics'))).captured;
      final samples = captured[0] as List<Map<String, Object?>>;
      expect(samples.map((s) => s['metric_type']), containsAll(['steps', 'heart_rate']));
      expect((captured[1] as List<String>).toSet(), {'steps', 'heart_rate'});
    });

    test('web and desktop never sync a phone connection, and sync-if-due is throttled', () async {
      final web = WearableService(repo, const UnsupportedHealthPlatform());
      expect(web.canReadHealthData, isFalse);
      expect(web.canSync(connection()), isFalse);
      expect(await web.syncIfDue([connection()]), isNull);

      final phone = WearableService(repo, FakeHealthPlatform());
      expect(await phone.syncIfDue([connection(lastSynced: DateTime.now().subtract(const Duration(minutes: 3)))]), isNull);
      expect(await phone.syncIfDue([connection(lastSynced: DateTime.now().subtract(const Duration(hours: 2)))]), isNotNull);
      // A connection made on an iPhone isn't synced from this Android phone.
      expect(phone.canSync(connection(provider: 'apple_health')), isFalse);
    });
  });
}

final _d = DateTime(2026, 9, 20);
