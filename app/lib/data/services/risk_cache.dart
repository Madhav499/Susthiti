import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the signed-in patient's own latest diabetes risk status on the device, so it can be
/// shown (clearly labelled as last updated) without a connection. Stored in secure storage and
/// only for the patient themself: never other patients' data viewed by a doctor.
abstract interface class RiskCache {
  Future<Map<String, dynamic>?> load(String patientId);
  Future<void> save(String patientId, Map<String, dynamic> status);
}

class SecureRiskCache implements RiskCache {
  SecureRiskCache([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  static String _key(String patientId) => 'susthiti_risk_status_$patientId';

  @override
  Future<Map<String, dynamic>?> load(String patientId) async {
    try {
      final raw = await _storage.read(key: _key(patientId));
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String patientId, Map<String, dynamic> status) async {
    try {
      await _storage.write(key: _key(patientId), value: jsonEncode(status));
    } catch (_) {
      // A cache: failing to write it never affects the app.
    }
  }
}

class MemoryRiskCache implements RiskCache {
  final Map<String, Map<String, dynamic>> _items = {};

  @override
  Future<Map<String, dynamic>?> load(String patientId) async => _items[patientId];

  @override
  Future<void> save(String patientId, Map<String, dynamic> status) async => _items[patientId] = status;
}
