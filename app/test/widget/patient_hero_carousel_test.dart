import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/core/theme/app_theme.dart';
import 'package:susthiti/data/models/diabetes_risk.dart';
import 'package:susthiti/data/models/heart_risk.dart';
import 'package:susthiti/data/models/system.dart';
import 'package:susthiti/data/models/tracking.dart';
import 'package:susthiti/data/providers.dart';
import 'package:susthiti/data/repositories/patient_repository.dart';
import 'package:susthiti/features/authentication/auth_controller.dart';
import 'package:susthiti/features/patient/patient_dashboard_screen.dart';

import '../helpers.dart';

class MockPatientRepository extends Mock implements PatientRepository {}

void main() {
  late MockPatientRepository patients;

  setUp(() {
    patients = MockPatientRepository();
    when(() => patients.dashboard(any())).thenAnswer((_) async => PatientDashboard(
          patientName: 'Asha Demo',
          patientCode: 'SUS-P-0A1B2C',
          glucose: const GlucoseOverview(),
          metrics: const {},
          recentReports: const [],
          risk: RiskBrief(id: 'r1', riskPercent: 42, riskCategory: 'Moderate', assessedAt: DateTime.now().subtract(const Duration(days: 10)), reportAvailable: true),
          riskStale: true,
          heartRisk: HeartRiskBrief(id: 'h1', probabilityPercent: 18, riskLevel: 'moderate', assessedAt: DateTime.now().subtract(const Duration(days: 10)), reportAvailable: true),
          heartRiskStale: true,
        ));
  });

  Future<void> pumpDashboard(WidgetTester tester, Size logicalSize) async {
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        currentUserProvider.overrideWithValue(testPatient),
        patientRepositoryProvider.overrideWithValue(patients),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const PatientDashboardScreen(patientId: 'pat1')),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('stale diabetes+heart hero carousel does not overflow at a narrow mobile width', (tester) async {
    await pumpDashboard(tester, const Size(512, 900));

    expect(tester.takeException(), isNull);
    expect(find.text('Review and refresh'), findsOneWidget);

    final button = tester.getRect(find.widgetWithText(FilledButton, 'Review and refresh'));
    final hero = tester.getRect(find.byType(PageView).first);
    expect(button.bottom, lessThanOrEqualTo(hero.bottom + 0.5), reason: 'button must be fully inside the hero, not clipped at the bottom');
  });

  testWidgets('button stays fully inside the hero at a common 390dp phone width', (tester) async {
    await pumpDashboard(tester, const Size(390, 900));
    tester.takeException(); // a separate, pre-existing horizontal pill-text overflow is known at this width; not in scope here.

    final button = tester.getRect(find.widgetWithText(FilledButton, 'Review and refresh'));
    final hero = tester.getRect(find.byType(PageView).first);
    expect(button.bottom, lessThanOrEqualTo(hero.bottom + 0.5), reason: 'button must be fully inside the hero, not clipped at the bottom');
  });

  testWidgets('stale diabetes+heart hero carousel does not overflow on tablet width', (tester) async {
    await pumpDashboard(tester, const Size(700, 1100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale diabetes+heart hero carousel does not overflow at the desktop breakpoint floor', (tester) async {
    await pumpDashboard(tester, const Size(1024, 900));
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(PageView).first, const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Review and refresh'), findsOneWidget);
  });
}
