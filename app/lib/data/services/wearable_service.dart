import '../datasources/health_platform.dart';
import '../models/health.dart';
import '../models/tracking.dart';
import '../repositories/lifestyle_repository.dart';

/// Coordinates health data between the phone's health platform and the SUSTHITI backend:
/// explain -> consent -> platform permission -> connect -> first sync -> connected.
///
/// The backend is the single source of truth: the phone uploads, and every device (web,
/// tablet, a doctor's screen) reads the same synced values from the backend.
class WearableService {
  WearableService(this._repository, this._platform);
  final WearableRepository _repository;
  final HealthPlatform _platform;

  HealthPlatform get platform => _platform;

  /// Every metric SUSTHITI can show. Nothing beyond these is ever requested.
  static const allMetrics = {...HealthMetric.values};

  /// First sync reads this far back (Health Connect allows about 30 days by default).
  static const initialHistory = Duration(days: 30);

  /// Automatic syncs are skipped if the last one was more recent than this.
  static const autoSyncInterval = Duration(minutes: 15);

  /// Whether this device can read from a health platform at all (false on web and desktop).
  bool get canReadHealthData => _platform.providerId != null;

  /// Whether this device can sync [connection] (a phone can only sync its own platform).
  bool canSync(WearableConnection connection) => connection.isDemo || connection.provider == _platform.providerId;

  Future<HealthAvailability> availability() => _platform.availability();

  /// Asks for permission (only after the patient has read the explanation and tapped Continue),
  /// registers the connection and runs the first sync.
  Future<SyncOutcome> connect() async {
    final availability = await _platform.availability();
    if (availability == HealthAvailability.unsupported) throw const HealthUnavailable();
    if (availability == HealthAvailability.needsInstall) throw const HealthNeedsInstall();
    final granted = await _platform.requestPermissions(allMetrics);
    if (granted.isEmpty) throw const WearableAuthorizationDenied();
    final connection = await _repository.connect(_platform.providerId!, grantedMetrics: granted.map((m) => m.apiValue).toList(), platform: _platform.platform);
    return sync(connection);
  }

  /// Development only: the backend's clearly labelled DEMO provider.
  Future<SyncOutcome> connectDemo() async => sync(await _repository.connect('demo'));

  /// Reads new data from the platform and uploads it. Re-reading overlapping days is safe:
  /// the backend recognises measurements it already has and only refreshes a day's total.
  Future<SyncOutcome> sync(WearableConnection connection) async {
    if (connection.isDemo) return _repository.sync(connection.id);
    if (!canSync(connection)) throw const HealthUnavailable();
    final granted = await _platform.grantedPermissions(allMetrics);
    final now = DateTime.now();
    final last = connection.lastSyncedAt?.toLocal();
    // Totals: re-read from two days before the last sync so late-arriving watch data is caught.
    final totalsFrom = last == null ? now.subtract(initialHistory) : _earlier(last.subtract(const Duration(days: 2)), now.subtract(initialHistory));
    final readingsFrom = last == null ? now.subtract(initialHistory) : _earlier(last.subtract(const Duration(hours: 2)), now.subtract(initialHistory));
    final readings = <HealthReading>[
      if (granted.contains(HealthMetric.steps)) ...await _platform.getSteps(_dayStart(totalsFrom), now),
      if (granted.contains(HealthMetric.sleep)) ...await _platform.getSleep(_dayStart(totalsFrom), now),
      if (granted.contains(HealthMetric.activity)) ...await _platform.getActivity(_dayStart(totalsFrom), now),
      if (granted.contains(HealthMetric.calories)) ...await _platform.getCalories(_dayStart(totalsFrom), now),
      if (granted.contains(HealthMetric.heartRate)) ...await _platform.getHeartRate(readingsFrom, now),
      if (granted.contains(HealthMetric.bloodPressure)) ...await _platform.getBloodPressure(readingsFrom, now),
      if (granted.contains(HealthMetric.spo2)) ...await _platform.getSpO2(readingsFrom, now),
    ];
    return _repository.sync(
      connection.id,
      samples: [for (final r in readings) r.toSample()],
      grantedMetrics: granted.map((m) => m.apiValue).toList(),
    );
  }

  /// Syncs this device's connection when the last sync is older than [autoSyncInterval].
  /// Used on launch and when the lifestyle dashboard opens (background sync is not relied on).
  Future<SyncOutcome?> syncIfDue(List<WearableConnection> connections) async {
    if (!canReadHealthData) return null;
    for (final c in connections) {
      if (c.isDemo || !canSync(c) || c.status == 'disconnected') continue;
      final last = c.lastSyncedAt;
      if (last != null && DateTime.now().difference(last) < autoSyncInterval) return null;
      return sync(c);
    }
    return null;
  }

  /// Stops future syncs. Previously synced records stay in the patient's history.
  Future<void> disconnect(WearableConnection connection) => _repository.disconnect(connection.id);

  static DateTime _dayStart(DateTime t) => DateTime(t.year, t.month, t.day);
  static DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? b : a;
}

class WearableAuthorizationDenied implements Exception {
  const WearableAuthorizationDenied();
  String get message => "Health data access wasn't enabled.";
}

class HealthNeedsInstall implements Exception {
  const HealthNeedsInstall();
}

class HealthUnavailable implements Exception {
  const HealthUnavailable();
}
