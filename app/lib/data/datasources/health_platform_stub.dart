import 'health_platform.dart';

/// Web build: browsers can't read a phone's health store or pair with watches.
HealthPlatform createHealthPlatform() => const UnsupportedHealthPlatform();
