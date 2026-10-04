import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_assets.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/models/user.dart';
import 'data/providers.dart';
import 'features/authentication/auth_controller.dart';

class SusthitiApp extends ConsumerStatefulWidget {
  const SusthitiApp({super.key});

  @override
  ConsumerState<SusthitiApp> createState() => _SusthitiAppState();
}

class _SusthitiAppState extends ConsumerState<SusthitiApp> {
  @override
  void initState() {
    super.initState();
    // Deferred a frame: the router must exist first, and this never needs to block first paint
    // -- system push staying unavailable for a moment is harmless, unlike delaying launch for it.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = ref.read(pushNotificationServiceProvider);
      service.onNavigate = (route) => ref.read(routerProvider).push(route);
      service.currentUser = () => ref.read(currentUserProvider);
      await service.initialize();
      if (ref.read(currentUserProvider) != null) await service.registerForCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Covers sign-in (fresh login, registration, or a session restored on a cold launch) and
    // sign-out, in one place, instead of every call site that changes auth state remembering to.
    ref.listen<AsyncValue<AppUser?>>(authControllerProvider, (previous, next) {
      final user = next.value;
      final service = ref.read(pushNotificationServiceProvider);
      if (user != null) {
        service.registerForCurrentUser();
        service.retryBufferedTap();
      } else if (previous?.value != null) {
        service.unregister();
      }
    });
    return MaterialApp.router(
      // The browser tab shows the name with the tagline; app switchers show just the name.
      title: kIsWeb ? AppAssets.webTitle : AppAssets.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
