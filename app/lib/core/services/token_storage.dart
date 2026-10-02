import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the session token securely (Keychain / Keystore / encrypted web storage).
abstract interface class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'susthiti_session_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      // Corrupted secure storage: treat as signed out rather than crashing on launch.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Nothing more we can do; the server session is revoked on logout anyway.
    }
  }
}

class MemoryTokenStorage implements TokenStorage {
  String? _token;
  @override
  Future<String?> read() async => _token;
  @override
  Future<void> write(String token) async => _token = token;
  @override
  Future<void> clear() async => _token = null;
}
