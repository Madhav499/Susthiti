import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/failures.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';

/// Holds the signed-in user (null when signed out). Restores a persisted session on launch.
class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final api = ref.read(apiClientProvider);
    api.onUnauthorized = _onUnauthorized;
    try {
      return await ref.read(authRepositoryProvider).restore();
    } on AuthenticationFailure {
      await api.tokenStorage.clear();
      return null;
    } on Failure {
      // Offline at launch: keep the token, show sign-in; the next request will retry.
      return null;
    }
  }

  void _onUnauthorized() {
    final current = state.value;
    if (current != null) {
      ref.read(apiClientProvider).tokenStorage.clear();
      state = const AsyncData(null);
    }
  }

  Future<void> login(String email, String password) async {
    final session = await ref.read(authRepositoryProvider).login(email, password);
    state = AsyncData(session.user);
  }

  Future<void> register({required String fullName, required String email, required String password, required DateTime dateOfBirth, required String gender, String? phone}) async {
    // Development trace only: never the email, password, token or health details.
    _trace('registration started, server ${AppConfig.serverOrigin}');
    try {
      final session = await ref.read(authRepositoryProvider).register(fullName: fullName, email: email, password: password, dateOfBirth: dateOfBirth, gender: gender, phone: phone);
      _trace('registration succeeded, role ${session.user.role.name}');
      state = AsyncData(session.user);
    } on Failure catch (f) {
      _trace('registration failed: ${f.runtimeType} (${f.code})');
      rethrow;
    }
  }

  static void _trace(String message) {
    if (kDebugMode) debugPrint('[auth] $message');
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } on Failure {
      // Token is cleared locally regardless; server session expires on its own.
    }
    state = const AsyncData(null);
  }

  void updateName(String name) {
    final user = state.value;
    if (user != null) state = AsyncData(user.copyWith(fullName: name));
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);

/// Convenience accessor for screens that are only reachable when signed in.
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider).value);
