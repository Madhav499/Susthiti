import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:susthiti/core/theme/app_theme.dart';
import 'package:susthiti/data/models/user.dart';
import 'package:susthiti/features/authentication/auth_controller.dart';

const testPatient = AppUser(id: 'u1', email: 'demo.patient@susthiti.test', role: UserRole.patient, fullName: 'Asha Demo', patientId: 'pat1', patientCode: 'SUS-P-0A1B2C', isDemo: true);
const testAdmin = AppUser(id: 'u3', email: 'demo.admin@susthiti.test', role: UserRole.admin, fullName: 'Admin Demo', isDemo: true);
const testDoctor = AppUser(id: 'u2', email: 'demo.doctor@susthiti.test', role: UserRole.doctor, fullName: 'Rao Demo', doctorId: 'doc1', doctorCode: 'SUS-D-000001', isDemo: true);

/// Pumps [child] inside the app theme with provider overrides. Retries are disabled so
/// failures surface immediately, as in the app.
Future<void> pumpScreen(WidgetTester tester, Widget child, {List<Override> overrides = const [], AppUser? user}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      if (user != null) currentUserProvider.overrideWithValue(user),
      ...overrides,
    ],
    child: MaterialApp(theme: AppTheme.light(), home: child),
  ));
  await tester.pumpAndSettle();
}
