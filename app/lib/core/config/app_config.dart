import 'package:flutter/foundation.dart';

/// Build-time configuration. No secrets live in the Flutter app: AI and ML keys stay on the
/// backend. Override with --dart-define=API_BASE_URL=https://api.example.org/api/v1
///
/// A physical phone cannot use 10.0.2.2 (emulator only) or its own localhost. Development options:
/// - USB cable (recommended): "SUSTHITI phone (USB cable)" builds with http://127.0.0.1:8000 and
///   start-susthiti.bat / phone-usb.bat forward that port through the cable (adb reverse), so it
///   keeps working when the PC changes Wi-Fi network.
/// - Wi-Fi: `start-susthiti.bat -Lan` writes the PC's current address to app/config/dev_phone.json,
///   which "SUSTHITI phone (Wi-Fi)" passes with --dart-define-from-file. Rebuild after a network change.
abstract final class AppConfig {
  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Without an override, the Android emulator reaches the host machine at 10.0.2.2
  /// (its own "localhost" is the emulator itself).
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
    return 'http://$host:8000/api/v1';
  }

  /// scheme://host:port of the backend, e.g. for its /health check.
  static String get serverOrigin {
    final uri = Uri.parse(apiBaseUrl);
    return uri.replace(path: '', query: null, fragment: null).toString().replaceFirst(RegExp(r'/$'), '');
  }

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 30);

  /// AI generation can take longer than an ordinary request.
  static const aiTimeout = Duration(seconds: 120);
  static const uploadTimeout = Duration(seconds: 120);
  static const maxUploadBytes = 20 * 1024 * 1024;
}
