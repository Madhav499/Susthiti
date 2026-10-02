import '../../core/utils/formatters.dart';

/// Health data SUSTHITI reads from a health platform. Only these are ever requested.
enum HealthMetric {
  steps('steps', 'Steps'),
  heartRate('heart_rate', 'Heart rate'),
  sleep('sleep', 'Sleep'),
  activity('activity', 'Activity'),
  bloodPressure('blood_pressure', 'Blood pressure'),
  spo2('spo2', 'SpO₂'),
  calories('calories', 'Active calories');

  const HealthMetric(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static HealthMetric? tryParse(String v) {
    for (final m in values) {
      if (m.apiValue == v) return m;
    }
    return null;
  }
}

/// Where a measurement came from. Shown next to values so patients and doctors can tell a
/// synced reading from a typed-in one.
enum DataSource {
  healthPlatform('health_platform', 'Health Platform'),
  device('device', 'Device'),
  manual('manual', 'Manual'),
  imported('imported', 'Imported');

  const DataSource(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static DataSource parse(String? v) => values.firstWhere((s) => s.apiValue == v, orElse: () => DataSource.manual);
}

/// One measurement from a health platform, ready to upload. [measuredAt] is when it was
/// measured (the end of the window for totals), never the time it was synced.
sealed class HealthReading {
  const HealthReading({required this.measuredAt, this.startedAt, this.externalId, this.source = DataSource.healthPlatform});

  final DateTime measuredAt;
  final DateTime? startedAt;

  /// The platform's own record id, when it has one (used to avoid duplicates).
  final String? externalId;
  final DataSource source;

  HealthMetric get metric;
  double get value;
  double? get value2 => null;

  /// Running totals for a day (the day's total so far): the server keeps one per day.
  bool get isDailyTotal => false;

  /// The patient's own calendar day for this value.
  DateTime get localDate {
    final l = (startedAt ?? measuredAt).toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  Map<String, Object?> toSample() => {
        'metric_type': metric.apiValue,
        'value': value,
        'value2': ?value2,
        'recorded_at': measuredAt.toUtc().toIso8601String(),
        if (startedAt != null) 'started_at': startedAt!.toUtc().toIso8601String(),
        'local_date': Fmt.isoDate(localDate),
        if (externalId != null) 'external_id': externalId,
        if (isDailyTotal) 'daily_total': true,
      };
}

class StepReading extends HealthReading {
  const StepReading({required this.steps, required this.startTime, required this.endTime, super.source}) : super(measuredAt: endTime, startedAt: startTime);
  final int steps;
  final DateTime startTime;
  final DateTime endTime;

  @override
  HealthMetric get metric => HealthMetric.steps;
  @override
  double get value => steps.toDouble();
  @override
  bool get isDailyTotal => true;
}

class HeartRateReading extends HealthReading {
  const HeartRateReading({required this.bpm, required this.timestamp, super.externalId, super.source}) : super(measuredAt: timestamp);
  final double bpm;
  final DateTime timestamp;

  @override
  HealthMetric get metric => HealthMetric.heartRate;
  @override
  double get value => bpm;
}

/// Total sleep for one night (sessions that ended on the same day).
class SleepReading extends HealthReading {
  const SleepReading({required this.startTime, required this.endTime, required this.duration, super.source}) : super(measuredAt: endTime, startedAt: startTime);
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;

  @override
  HealthMetric get metric => HealthMetric.sleep;
  @override
  double get value => duration.inMinutes.toDouble();
  @override
  bool get isDailyTotal => true;

  @override
  DateTime get localDate {
    final l = endTime.toLocal(); // a night belongs to the day you wake up
    return DateTime(l.year, l.month, l.day);
  }
}

class BloodPressureReading extends HealthReading {
  const BloodPressureReading({required this.systolic, required this.diastolic, required this.timestamp, super.externalId, super.source}) : super(measuredAt: timestamp);
  final double systolic;
  final double diastolic;
  final DateTime timestamp;

  @override
  HealthMetric get metric => HealthMetric.bloodPressure;
  @override
  double get value => systolic;
  @override
  double get value2 => diastolic;
}

class SpO2Reading extends HealthReading {
  const SpO2Reading({required this.percent, required this.timestamp, super.externalId, super.source}) : super(measuredAt: timestamp);
  final double percent;
  final DateTime timestamp;

  @override
  HealthMetric get metric => HealthMetric.spo2;
  @override
  double get value => percent;
}

/// Minutes of recorded exercise in one day.
class ActivityReading extends HealthReading {
  const ActivityReading({required this.minutes, required this.startTime, required this.endTime, super.source}) : super(measuredAt: endTime, startedAt: startTime);
  final double minutes;
  final DateTime startTime;
  final DateTime endTime;

  @override
  HealthMetric get metric => HealthMetric.activity;
  @override
  double get value => minutes;
  @override
  bool get isDailyTotal => true;
}

/// Active energy burned in one day.
class CaloriesReading extends HealthReading {
  const CaloriesReading({required this.kilocalories, required this.startTime, required this.endTime, super.source}) : super(measuredAt: endTime, startedAt: startTime);
  final double kilocalories;
  final DateTime startTime;
  final DateTime endTime;

  @override
  HealthMetric get metric => HealthMetric.calories;
  @override
  double get value => kilocalories;
  @override
  bool get isDailyTotal => true;
}
