import '../../core/services/api_client.dart';
import '../../core/utils/formatters.dart';
import '../models/user.dart';

abstract interface class AuthRepository {
  Future<AuthSession> login(String email, String password);
  Future<AuthSession> register({required String fullName, required String email, required String password, required DateTime dateOfBirth, required String gender, String? phone});
  Future<AppUser?> restore();
  Future<void> logout();

  /// Returns a development-only reset token when the server exposes one (no email provider configured).
  Future<String?> forgotPassword(String email);
  Future<void> resetPassword(String token, String newPassword);
  Future<void> changePassword(String current, String next);
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);
  final ApiClient _api;

  Future<AuthSession> _session(Json j) async {
    final token = j['access_token'] as String;
    await _api.tokenStorage.write(token);
    return AuthSession(token: token, user: AppUser.fromJson(j['user'] as Json));
  }

  @override
  Future<AuthSession> login(String email, String password) async =>
      _session(await _api.post('/auth/login', body: {'email': email.trim(), 'password': password}));

  @override
  Future<AuthSession> register({required String fullName, required String email, required String password, required DateTime dateOfBirth, required String gender, String? phone}) async =>
      _session(await _api.post('/auth/register', body: {
        'full_name': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'date_of_birth': Fmt.isoDate(dateOfBirth),
        'gender': gender,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      }));

  @override
  Future<AppUser?> restore() async {
    if (await _api.tokenStorage.read() == null) return null;
    return AppUser.fromJson(await _api.get('/auth/me'));
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } finally {
      await _api.tokenStorage.clear();
    }
  }

  @override
  Future<String?> forgotPassword(String email) async {
    final r = await _api.post('/auth/forgot-password', body: {'email': email.trim()});
    return r['dev_reset_token'] as String?;
  }

  @override
  Future<void> resetPassword(String token, String newPassword) => _api.post('/auth/reset-password', body: {'token': token.trim(), 'new_password': newPassword});

  @override
  Future<void> changePassword(String current, String next) => _api.post('/auth/change-password', body: {'current_password': current, 'new_password': next});
}
