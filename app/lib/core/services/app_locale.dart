import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user.dart';
import '../../features/authentication/auth_controller.dart';

/// The interface language to render right now, derived only from the signed-in user's own
/// saved preference -- never cached locally across accounts, so logging out (or switching
/// accounts) can never leak the previous user's language into the next session. While
/// signed out, or before the restored session resolves, this is English.
final appLocaleProvider = Provider<Locale>((ref) {
  final user = ref.watch(currentUserProvider);
  return Locale(normalizeLocale(user?.preferredLocale));
});
