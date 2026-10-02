import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_assets.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class SusthitiApp extends ConsumerWidget {
  const SusthitiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      // The browser tab shows the name with the tagline; app switchers show just the name.
      title: kIsWeb ? AppAssets.webTitle : AppAssets.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
