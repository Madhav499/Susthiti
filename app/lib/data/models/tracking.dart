import '../../core/utils/formatters.dart';
import 'health.dart';

enum GlucoseReadingType {
  fasting('fasting', 'Fasting'),
  postMeal('post_meal', 'Post-meal'),
  random('random', 'Random');

  const GlucoseReadingType(this.apiValue, this.label);
  final String apiValue;
  final String label;
  static GlucoseReadingType parse(String v) => values.firstWhere((t) => t.apiValue == v);
}

class GlucoseReading {
  const GlucoseReading({required this.id, required this.value, required this.unit, required this.readingType, required this.measuredAt, required this.source, this.context, this.isDemo = false});

  final String id;
  final double value;
  final String unit;
  final GlucoseReadingType readingType;
  final DateTime measuredAt;
  final String source;
  final String? context;
  final bool isDemo;

  double get mgDl => unit == 'mg/dL' ? value : double.parse((value * 18.0182).toStringAsFixed(1));

  factory GlucoseReading.fromJson(Map<String, dynamic> j) => GlucoseReading(
        id: j['id'] as String,
        value: (j['value'] as num).toDouble(),
        unit: j['unit'] as String,
        readingType: GlucoseReadingType.parse(j['reading_type'] as String),
        measuredAt: parseDate(j['measured_at'])!,
        source: j['source'] as String,
        context: j['context'] as String?,
        isDemo: j['is_demo'] as bool? ?? false,
      );
}

class GlucoseOverview {
  const GlucoseOverview({this.todayCount = 0, this.latestValue, this.latestType, this.latestAt, this.average7d, this.readings7d = 0, this.trend});

  final int todayCount;
  final double? latestValue;
  final String? latestType;
  final DateTime? latestAt;
  final double? average7d;
  final int readings7d;

  /// 'higher' | 'lower' | 'stable' | null (not enough data to say).
  final String? trend;

  factory GlucoseOverview.fromJson(Map<String, dynamic> j) {
    final latest = j['latest'] as Map<String, dynamic>?;
    return GlucoseOverview(
      todayCount: j['today_count'] as int? ?? 0,
      latestValue: (latest?['value'] as num?)?.toDouble(),
      latestType: latest?['reading_type'] as String?,
      latestAt: parseDate(latest?['measured_at']),
      average7d: (j['recent_average_7d'] as num?)?.toDouble(),
      readings7d: j['readings_7d'] as int? ?? 0,
      trend: j['trend_vs_previous_weeks'] as String?,
    );
  }
}

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
  other;

  String get label => Fmt.titleCase(name);
}

class FoodEntry {
  const FoodEntry({required this.id, required this.foodName, required this.quantity, required this.mealType, required this.eatenAt, this.isEdited = false});

  final String id;
  final String foodName;
  final String quantity;
  final MealType mealType;
  final DateTime eatenAt;
  final bool isEdited;

  factory FoodEntry.fromJson(Map<String, dynamic> j) => FoodEntry(
        id: j['id'] as String,
        foodName: j['food_name'] as String,
        quantity: j['quantity'] as String,
        mealType: MealType.values.byName(j['meal_type'] as String),
        eatenAt: parseDate(j['eaten_at'])!,
        isEdited: j['is_edited'] as bool? ?? false,
      );
}

enum LifestyleMetricType {
  steps('steps', 'Steps', 'steps'),
  heartRate('heart_rate', 'Heart Rate', 'bpm'),
  sleep('sleep', 'Sleep', 'min'),
  activity('activity', 'Activity', 'min'),
  bloodPressure('blood_pressure', 'Blood Pressure', 'mmHg'),
  spo2('spo2', 'SpO₂', '%'),
  calories('calories', 'Calories', 'kcal');

  const LifestyleMetricType(this.apiValue, this.label, this.unit);
  final String apiValue;
  final String label;
  final String unit;

  static LifestyleMetricType parse(String v) => values.firstWhere((m) => m.apiValue == v);

  String format(double value, [double? value2]) => switch (this) {
        steps => Fmt.number(value.round()),
        sleep || activity => Fmt.duration(value),
        heartRate => '${value.round()} bpm',
        bloodPressure => '${value.round()}/${value2?.round() ?? '—'}',
        spo2 => '${value.round()}%',
        calories => '${Fmt.number(value.round())} kcal',
      };
}

class DailyValue {
  const DailyValue({required this.date, required this.value, this.value2, this.isDemo = false, this.sources = const [], this.lastSyncedAt});
  final DateTime date;
  final double value;
  final double? value2;
  final bool isDemo;

  /// Where this day's values came from (health_platform, device, manual, imported).
  final List<String> sources;

  /// When synced values for this day last arrived (not when they were measured).
  final DateTime? lastSyncedAt;

  /// "Health Platform", "Manual", or "Health Platform + Manual".
  String get sourceLabel => sources.isEmpty ? 'Manual' : sources.map((s) => DataSource.parse(s).label).join(' + ');

  factory DailyValue.fromJson(Map<String, dynamic> j) => DailyValue(
        date: parseDate(j['date'])!,
        value: (j['value'] as num).toDouble(),
        value2: (j['value2'] as num?)?.toDouble(),
        isDemo: j['is_demo'] as bool? ?? false,
        sources: [for (final s in (j['sources'] as List? ?? [j['source'] ?? 'manual'])) s as String],
        lastSyncedAt: parseDate(j['last_synced_at']),
      );
}

class MetricOverview {
  const MetricOverview({required this.metric, this.latest, this.recentAverage, this.changePercent, this.last7Days = const []});

  final LifestyleMetricType metric;
  final DailyValue? latest;

  /// Only present when enough history exists for a fair comparison.
  final double? recentAverage;
  final int? changePercent;
  final List<DailyValue> last7Days;

  bool get isToday {
    final l = latest;
    if (l == null) return false;
    final now = DateTime.now(); // synced values are dated by the patient's own day
    return l.date.year == now.year && l.date.month == now.month && l.date.day == now.day;
  }

  factory MetricOverview.fromJson(Map<String, dynamic> j) {
    final cmp = j['comparison'] as Map<String, dynamic>?;
    return MetricOverview(
      metric: LifestyleMetricType.parse(j['metric'] as String),
      latest: j['latest'] == null ? null : DailyValue.fromJson(j['latest'] as Map<String, dynamic>),
      recentAverage: (cmp?['recent_average'] as num?)?.toDouble(),
      changePercent: cmp?['change_percent'] as int?,
      last7Days: [for (final p in (j['last_7_days'] as List? ?? const [])) DailyValue.fromJson(p as Map<String, dynamic>)],
    );
  }
}

class WearableProvider {
  const WearableProvider({required this.id, required this.name, required this.description, required this.onDevice, required this.supportedMetrics, this.isDemo = false});
  final String id;
  final String name;
  final String description;
  final bool onDevice;
  final List<String> supportedMetrics;
  final bool isDemo;

  factory WearableProvider.fromJson(Map<String, dynamic> j) => WearableProvider(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        onDevice: j['on_device'] as bool,
        supportedMetrics: [for (final m in j['supported_metrics'] as List) m as String],
        isDemo: j['is_demo'] as bool? ?? false,
      );
}

class WearableConnection {
  const WearableConnection({
    required this.id,
    required this.provider,
    required this.deviceName,
    required this.status,
    this.lastSyncedAt,
    this.lastError,
    this.supportedMetrics = const [],
    this.grantedMetrics,
    this.platform,
    this.connectedAt,
    this.isDemo = false,
  });

  final String id;
  final String provider;
  final String deviceName;

  /// connected | sync_failed | disconnected
  final String status;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final List<String> supportedMetrics;

  /// Metrics the patient granted on the phone (null when not reported).
  final List<String>? grantedMetrics;

  /// 'android' / 'ios': the phone this connection syncs from.
  final String? platform;
  final DateTime? connectedAt;
  final bool isDemo;

  bool get syncFailed => status == 'sync_failed';

  bool isGranted(String metric) => grantedMetrics?.contains(metric) ?? true;

  factory WearableConnection.fromJson(Map<String, dynamic> j) => WearableConnection(
        id: j['id'] as String,
        provider: j['provider'] as String,
        deviceName: j['device_name'] as String,
        status: j['status'] as String,
        lastSyncedAt: parseDate(j['last_synced_at']),
        lastError: j['last_error'] as String?,
        supportedMetrics: [for (final m in (j['supported_metrics'] as List? ?? const [])) m as String],
        grantedMetrics: j['granted_metrics'] == null ? null : [for (final m in j['granted_metrics'] as List) m as String],
        platform: j['platform'] as String?,
        connectedAt: parseDate(j['connected_at']),
        isDemo: j['is_demo'] as bool? ?? false,
      );
}

/// Result of one sync: what was stored, refreshed or already there.
class SyncOutcome {
  const SyncOutcome({required this.device, this.imported = 0, this.updated = 0, this.duplicates = 0, this.upToDate = false});
  final WearableConnection device;
  final int imported;
  final int updated;
  final int duplicates;
  final bool upToDate;

  factory SyncOutcome.fromJson(Map<String, dynamic> j) => SyncOutcome(
        device: WearableConnection.fromJson(j['device'] as Map<String, dynamic>),
        imported: j['imported'] as int? ?? 0,
        updated: j['updated'] as int? ?? 0,
        duplicates: j['duplicates'] as int? ?? 0,
        upToDate: j['up_to_date'] as bool? ?? false,
      );
}

class LifestyleOverview {
  const LifestyleOverview({required this.metrics, required this.glucose, required this.foodEntriesToday, required this.devices});
  final Map<LifestyleMetricType, MetricOverview> metrics;
  final GlucoseOverview glucose;
  final int foodEntriesToday;
  final List<WearableConnection> devices;

  factory LifestyleOverview.fromJson(Map<String, dynamic> j) => LifestyleOverview(
        metrics: {
          for (final e in (j['metrics'] as Map<String, dynamic>).entries) LifestyleMetricType.parse(e.key): MetricOverview.fromJson(e.value as Map<String, dynamic>),
        },
        glucose: GlucoseOverview.fromJson(j['glucose'] as Map<String, dynamic>),
        foodEntriesToday: (j['food'] as Map<String, dynamic>?)?['entries_count'] as int? ?? 0,
        devices: [for (final d in (j['devices'] as List? ?? const [])) WearableConnection.fromJson(d as Map<String, dynamic>)],
      );
}

class TrendSeries {
  const TrendSeries({required this.metric, required this.unit, required this.points, this.start, this.end});
  final String metric;
  final String unit;
  final List<DailyValue> points;

  /// The resolved query range (not necessarily what was requested for 'today'/'week'/'month').
  /// When [start] and [end] are the same day, [points] are raw, unaggregated readings rather
  /// than one point per day -- see trend_card.dart's "readings" vs "days" caption.
  final DateTime? start;
  final DateTime? end;

  factory TrendSeries.fromJson(Map<String, dynamic> j) => TrendSeries(
        metric: j['metric'] as String,
        unit: j['unit'] as String,
        points: [for (final p in j['points'] as List) DailyValue.fromJson(p as Map<String, dynamic>)],
        start: parseDate(j['start']),
        end: parseDate(j['end']),
      );
}
