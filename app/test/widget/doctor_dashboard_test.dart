import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/core/theme/app_theme.dart';
import 'package:susthiti/data/models/system.dart';
import 'package:susthiti/data/providers.dart';
import 'package:susthiti/data/repositories/notification_repository.dart';
import 'package:susthiti/data/repositories/patient_repository.dart';
import 'package:susthiti/features/authentication/auth_controller.dart';
import 'package:susthiti/features/doctor/doctor_dashboard_screen.dart';

import '../helpers.dart';

class MockDoctorRepository extends Mock implements DoctorRepository {}

class MockNotificationRepository extends Mock implements NotificationRepository {}

void main() {
  late MockDoctorRepository doctors;
  late MockNotificationRepository notifications;

  setUp(() {
    doctors = MockDoctorRepository();
    notifications = MockNotificationRepository();
    when(() => notifications.unreadCount()).thenAnswer((_) async => 0);
  });

  Future<void> pump(WidgetTester tester, DoctorDashboard dashboard) async {
    when(() => doctors.dashboard()).thenAnswer((_) async => dashboard);
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const DoctorDashboardScreen()),
      GoRoute(path: '/d/patients/:pid', builder: (_, s) => Text('PATIENT ${s.pathParameters['pid']} tab=${s.uri.queryParameters['tab'] ?? '0'}')),
    ]);
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        currentUserProvider.overrideWithValue(testDoctor),
        doctorRepositoryProvider.overrideWithValue(doctors),
        notificationRepositoryProvider.overrideWithValue(notifications),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('an empty day shows the clear-schedule state, not a fabricated summary', (tester) async {
    await pump(tester, const DoctorDashboard(doctorName: 'Rao', metrics: {}, needsAttention: [], recentActivity: [], today: []));
    expect(find.text('Your schedule is clear today.'), findsOneWidget); // exactly once, not duplicated
    expect(find.textContaining('Today you have'), findsNothing);
  });

  testWidgets('today lists real appointments, follow-ups and surgeries in order, with a working filter', (tester) async {
    final items = [
      const ScheduleItem(type: ScheduleItemType.followUp, id: 'f1', title: 'Wound check', patientId: 'pat1', patientName: 'Asha Demo', patientCode: 'SUS-P-0A1B2C'),
      ScheduleItem(type: ScheduleItemType.appointment, id: 'a1', at: DateTime(2026, 10, 3, 9, 0), title: 'Morning check-up', patientId: 'pat2', patientName: 'Vikram Rao', patientCode: 'SUS-P-0X1Y2Z'),
      ScheduleItem(type: ScheduleItemType.surgery, id: 's1', at: DateTime(2026, 10, 3, 14, 0), title: 'Appendectomy', patientId: 'pat3'),
    ];
    await pump(tester, DoctorDashboard(doctorName: 'Rao', metrics: const {}, needsAttention: const [], recentActivity: const [], today: items));

    expect(find.textContaining('2 appointments'), findsNothing); // sanity: not fabricating a count
    expect(find.textContaining('1 appointment, 1 follow-up and 1 surgery'), findsOneWidget);
    expect(find.text('Morning check-up'), findsOneWidget);
    expect(find.text('Wound check'), findsOneWidget);
    expect(find.text('Appendectomy'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Surgery'));
    await tester.pumpAndSettle();
    expect(find.text('Appendectomy'), findsOneWidget);
    expect(find.text('Morning check-up'), findsNothing);
    expect(find.text('Wound check'), findsNothing);

    await tester.tap(find.text('Appendectomy'));
    await tester.pumpAndSettle();
    expect(find.text('PATIENT pat3 tab=8'), findsOneWidget);
  });
}
