import '../models/health.dart';
import 'health_platform_stub.dart' if (dart.library.io) 'health_platform_mobile.dart' as impl;

enum HealthAvailability {
  available,

  /// Android: the Health Connect app must be installed or updated first.
  needsInstall,

  /// This platform can't read health data here (web, desktop). Synced data still shows.
  unsupported,
}

/// The phone's health platform, behind one interface so no screen depends on a specific SDK.
///
///   HealthPlatform
///     ├── HealthConnectPlatform  (Android, Health Connect)
///     ├── AppleHealthPlatform    (iOS, HealthKit)
///     └── UnsupportedHealthPlatform (web and desktop: they read synced data from the backend)
///
/// Only read access is ever requested, and only for [HealthMetric] types.
abstract interface class HealthPlatform {
  /// Backend provider id: 'health_connect', 'apple_health', or null when unsupported.
  String? get providerId;

  /// 'Health Connect', 'Apple Health', or a generic name.
  String get name;

  /// 'android' / 'ios', or null.
  String? get platform;

  Future<HealthAvailability> availability();

  /// Shows the platform's permission screen. Returns the metrics actually granted (on iOS,
  /// HealthKit never reveals read decisions, so it returns the requested set).
  Future<Set<HealthMetric>> requestPermissions(Set<HealthMetric> metrics);

  /// Metrics currently granted, without prompting.
  Future<Set<HealthMetric>> grantedPermissions(Set<HealthMetric> metrics);

  /// Android: installs/updates Health Connect. Elsewhere a no-op.
  Future<void> install();

  Future<List<StepReading>> getSteps(DateTime from, DateTime to);
  Future<List<HeartRateReading>> getHeartRate(DateTime from, DateTime to);
  Future<List<SleepReading>> getSleep(DateTime from, DateTime to);
  Future<List<BloodPressureReading>> getBloodPressure(DateTime from, DateTime to);
  Future<List<SpO2Reading>> getSpO2(DateTime from, DateTime to);
  Future<List<ActivityReading>> getActivity(DateTime from, DateTime to);
  Future<List<CaloriesReading>> getCalories(DateTime from, DateTime to);
}

/// The platform for this build and device. Nothing is initialised until it is first used.
HealthPlatform createHealthPlatform() => impl.createHealthPlatform();

/// Web and desktop: no direct device access. The UI shows data synced from the phone instead.
class UnsupportedHealthPlatform implements HealthPlatform {
  const UnsupportedHealthPlatform();

  @override
  String? get providerId => null;
  @override
  String get name => 'Health data';
  @override
  String? get platform => null;
  @override
  Future<HealthAvailability> availability() async => HealthAvailability.unsupported;
  @override
  Future<Set<HealthMetric>> requestPermissions(Set<HealthMetric> metrics) async => const {};
  @override
  Future<Set<HealthMetric>> grantedPermissions(Set<HealthMetric> metrics) async => const {};
  @override
  Future<void> install() async {}
  @override
  Future<List<StepReading>> getSteps(DateTime from, DateTime to) async => const [];
  @override
  Future<List<HeartRateReading>> getHeartRate(DateTime from, DateTime to) async => const [];
  @override
  Future<List<SleepReading>> getSleep(DateTime from, DateTime to) async => const [];
  @override
  Future<List<BloodPressureReading>> getBloodPressure(DateTime from, DateTime to) async => const [];
  @override
  Future<List<SpO2Reading>> getSpO2(DateTime from, DateTime to) async => const [];
  @override
  Future<List<ActivityReading>> getActivity(DateTime from, DateTime to) async => const [];
  @override
  Future<List<CaloriesReading>> getCalories(DateTime from, DateTime to) async => const [];
}
