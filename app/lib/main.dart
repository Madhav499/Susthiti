import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Failed requests surface as retryable error states; they are never retried silently.
  runApp(ProviderScope(retry: (_, _) => null, child: const SusthitiApp()));
}
