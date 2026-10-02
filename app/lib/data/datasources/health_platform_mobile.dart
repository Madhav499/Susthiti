import 'dart:io' show Platform;

import 'package:health/health.dart';

import '../models/health.dart';
import 'health_platform.dart';

/// Android / iOS build: picks the platform's own health store.
HealthPlatform createHealthPlatform() {
  if (Platform.isAndroid) return HealthConnectPlatform();
  if (Platform.isIOS) return AppleHealthPlatform();
  return const UnsupportedHealthPlatform();
}

/// Shared reading logic over the `health` plugin. Each platform supplies its own data types:
/// Health Connect and HealthKit model sleep and exercise differently.
abstract class _PluginHealthPlatform implements HealthPlatform {
  final Health _health = Health();
  Future<void>? _configured;

  /// Types read for each metric on this platform.
  Map<HealthMetric, List<HealthDataType>> get types;

  /// Readings kept per metric per sync, so a busy watch can't flood the upload.
  static const _maxReadings = 400;

  Future<void> _ready() => _configured ??= _health.configure();

  List<HealthDataType> _typesFor(Iterable<HealthMetric> metrics) => [for (final m in metrics) ...?types[m]];

  @override
  Future<Set<HealthMetric>> requestPermissions(Set<HealthMetric> metrics) async {
    await _ready();
    final list = _typesFor(metrics);
    if (list.isEmpty) return const {};
    await _health.requestAuthorization(list, permissions: List.filled(list.length, HealthDataAccess.READ));
    return grantedPermissions(metrics);
  }

  @override
  Future<Set<HealthMetric>> grantedPermissions(Set<HealthMetric> metrics) async {
    await _ready();
    final granted = <HealthMetric>{};
    for (final m in metrics) {
      final list = types[m];
      if (list == null) continue;
      final ok = await _health.hasPermissions(list, permissions: List.filled(list.length, HealthDataAccess.READ));
      // HealthKit keeps read decisions private and answers null: treat as requested.
      if (ok ?? true) granted.add(m);
    }
    return granted;
  }

  Future<List<HealthDataPoint>> _points(HealthMetric metric, DateTime from, DateTime to) async {
    final list = types[metric];
    if (list == null || !from.isBefore(to)) return const [];
    await _ready();
    final points = await _health.getHealthDataFromTypes(types: list, startTime: from, endTime: to);
    return points..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
  }

  static double? _number(HealthDataPoint p) {
    final v = p.value;
    return v is NumericHealthValue ? v.numericValue.toDouble() : null;
  }

  /// Local calendar days overlapping [from, to], each clipped to the range and to now.
  static Iterable<(DateTime, DateTime)> _days(DateTime from, DateTime to) sync* {
    final now = DateTime.now();
    var day = DateTime(from.year, from.month, from.day);
    while (day.isBefore(to) && day.isBefore(now)) {
      final next = DateTime(day.year, day.month, day.day + 1);
      final start = day.isBefore(from) ? from : day;
      final end = [next, to, now].reduce((a, b) => a.isBefore(b) ? a : b);
      yield (start, end);
      day = next;
    }
  }

  static DateTime _dayOf(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  @override
  Future<List<StepReading>> getSteps(DateTime from, DateTime to) async {
    if (types[HealthMetric.steps] == null) return const [];
    await _ready();
    final out = <StepReading>[];
    for (final (start, end) in _days(from, to)) {
      // Total for the day with phone + watch overlaps removed by the platform.
      final total = await _health.getTotalStepsInInterval(start, end);
      if (total != null && total > 0) out.add(StepReading(steps: total, startTime: start, endTime: end));
    }
    return out;
  }

  @override
  Future<List<HeartRateReading>> getHeartRate(DateTime from, DateTime to) async {
    // Watches record many samples an hour: keep the last real sample of each hour.
    final byHour = <DateTime, HealthDataPoint>{};
    for (final p in await _points(HealthMetric.heartRate, from, to)) {
      final t = p.dateFrom.toLocal();
      byHour[DateTime(t.year, t.month, t.day, t.hour)] = p;
    }
    return [
      for (final p in byHour.values.toList().reversed.take(_maxReadings).toList().reversed)
        if (_number(p) case final bpm?) HeartRateReading(bpm: bpm, timestamp: p.dateFrom, externalId: p.uuid),
    ];
  }

  @override
  Future<List<SleepReading>> getSleep(DateTime from, DateTime to) async {
    // One total per night, grouped by the day the sleep ended.
    final nights = <DateTime, List<HealthDataPoint>>{};
    for (final p in await _points(HealthMetric.sleep, from, to)) {
      nights.putIfAbsent(_dayOf(p.dateTo), () => []).add(p);
    }
    return [
      for (final segments in nights.values)
        SleepReading(
          startTime: segments.map((s) => s.dateFrom).reduce((a, b) => a.isBefore(b) ? a : b),
          endTime: segments.map((s) => s.dateTo).reduce((a, b) => a.isAfter(b) ? a : b),
          duration: segments.fold(Duration.zero, (sum, s) => sum + s.dateTo.difference(s.dateFrom)),
        ),
    ];
  }

  @override
  Future<List<BloodPressureReading>> getBloodPressure(DateTime from, DateTime to) async {
    final points = await _points(HealthMetric.bloodPressure, from, to);
    final diastolic = {for (final p in points.where((p) => p.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC)) p.dateFrom: p};
    return [
      for (final s in points.where((p) => p.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC).take(_maxReadings))
        if ((_number(s), diastolic[s.dateFrom] == null ? null : _number(diastolic[s.dateFrom]!)) case (final sys?, final dia?))
          BloodPressureReading(systolic: sys, diastolic: dia, timestamp: s.dateFrom, externalId: s.uuid),
    ];
  }

  @override
  Future<List<SpO2Reading>> getSpO2(DateTime from, DateTime to) async => [
        for (final p in (await _points(HealthMetric.spo2, from, to)).take(_maxReadings))
          if (_number(p) case final v?)
            // HealthKit reports a fraction (0.97); Health Connect a percentage (97).
            SpO2Reading(percent: v <= 1 ? v * 100 : v, timestamp: p.dateFrom, externalId: p.uuid),
      ];

  @override
  Future<List<ActivityReading>> getActivity(DateTime from, DateTime to) async {
    final byDay = <DateTime, List<HealthDataPoint>>{};
    for (final p in await _points(HealthMetric.activity, from, to)) {
      byDay.putIfAbsent(_dayOf(p.dateFrom), () => []).add(p);
    }
    return [
      for (final entry in byDay.entries)
        ActivityReading(
          minutes: entry.value.fold(0.0, (sum, p) => sum + _activityMinutes(p)),
          startTime: entry.key,
          endTime: entry.value.map((p) => p.dateTo).reduce((a, b) => a.isAfter(b) ? a : b),
        ),
    ].where((a) => a.minutes > 0).toList();
  }

  /// Minutes of one activity record: a workout's length, or HealthKit's exercise minutes.
  double _activityMinutes(HealthDataPoint p) =>
      p.type == HealthDataType.WORKOUT ? p.dateTo.difference(p.dateFrom).inSeconds / 60 : (_number(p) ?? 0);

  @override
  Future<List<CaloriesReading>> getCalories(DateTime from, DateTime to) async {
    final byDay = <DateTime, List<HealthDataPoint>>{};
    for (final p in await _points(HealthMetric.calories, from, to)) {
      byDay.putIfAbsent(_dayOf(p.dateFrom), () => []).add(p);
    }
    return [
      for (final entry in byDay.entries)
        CaloriesReading(
          kilocalories: entry.value.fold(0.0, (sum, p) => sum + (_number(p) ?? 0)),
          startTime: entry.key,
          endTime: entry.value.map((p) => p.dateTo).reduce((a, b) => a.isAfter(b) ? a : b),
        ),
    ].where((c) => c.kilocalories > 0).toList();
  }
}

/// Android: Health Connect (built in on Android 14+, an app on earlier versions).
class HealthConnectPlatform extends _PluginHealthPlatform {
  @override
  String get providerId => 'health_connect';
  @override
  String get name => 'Health Connect';
  @override
  String get platform => 'android';

  @override
  Map<HealthMetric, List<HealthDataType>> get types => const {
        HealthMetric.steps: [HealthDataType.STEPS],
        HealthMetric.heartRate: [HealthDataType.HEART_RATE],
        HealthMetric.sleep: [HealthDataType.SLEEP_SESSION],
        HealthMetric.activity: [HealthDataType.WORKOUT],
        HealthMetric.bloodPressure: [HealthDataType.BLOOD_PRESSURE_SYSTOLIC, HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
        HealthMetric.spo2: [HealthDataType.BLOOD_OXYGEN],
        HealthMetric.calories: [HealthDataType.ACTIVE_ENERGY_BURNED],
      };

  @override
  Future<HealthAvailability> availability() async {
    await _ready();
    final status = await _health.getHealthConnectSdkStatus();
    return status == HealthConnectSdkStatus.sdkAvailable ? HealthAvailability.available : HealthAvailability.needsInstall;
  }

  @override
  Future<void> install() => _health.installHealthConnect();
}

/// iOS: Apple Health (HealthKit).
class AppleHealthPlatform extends _PluginHealthPlatform {
  @override
  String get providerId => 'apple_health';
  @override
  String get name => 'Apple Health';
  @override
  String get platform => 'ios';

  @override
  Map<HealthMetric, List<HealthDataType>> get types => const {
        HealthMetric.steps: [HealthDataType.STEPS],
        HealthMetric.heartRate: [HealthDataType.HEART_RATE],
        HealthMetric.sleep: [HealthDataType.SLEEP_ASLEEP],
        HealthMetric.activity: [HealthDataType.EXERCISE_TIME],
        HealthMetric.bloodPressure: [HealthDataType.BLOOD_PRESSURE_SYSTOLIC, HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
        HealthMetric.spo2: [HealthDataType.BLOOD_OXYGEN],
        HealthMetric.calories: [HealthDataType.ACTIVE_ENERGY_BURNED],
      };

  @override
  Future<HealthAvailability> availability() async => HealthAvailability.available;

  @override
  Future<void> install() async {}
}
