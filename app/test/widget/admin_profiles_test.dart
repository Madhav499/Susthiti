import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/core/theme/app_theme.dart';
import 'package:susthiti/data/models/admin.dart';
import 'package:susthiti/data/models/patient.dart';
import 'package:susthiti/data/providers.dart';
import 'package:susthiti/data/repositories/patient_repository.dart';
import 'package:susthiti/features/admin/admin_doctor_profile_screen.dart';
import 'package:susthiti/features/admin/admin_screens.dart';
import 'package:susthiti/features/authentication/auth_controller.dart';

import '../helpers.dart';

class MockAdminRepository extends Mock implements AdminRepository {}

const doctorJson = {
  'id': 'doc1',
  'doctor_code': 'SUS-D-000001',
  'full_name': 'James Wilson',
  'email': 'james@example.org',
  'specialization': 'Endocrinology',
  'license_number': null,
  'phone': null,
  'is_active': true,
  'created_at': '2026-01-01T00:00:00Z',
  'active_patients': 1,
  'last_activity_at': '2026-09-25T10:32:00Z',
};

AdminDoctorDetail detail() => AdminDoctorDetail.fromJson({
      ...doctorJson,
      'last_login_at': '2026-09-25T09:00:00Z',
      'stats': {
        'active_patients': 1, 'total_patients': 2, 'pending_requests': 1, 'reports_uploaded': 3, 'reports_uploaded_this_month': 2,
        'prescriptions': 4, 'prescriptions_this_month': 1, 'visits': 0, 'visits_this_month': 0, 'upcoming_appointments': 0,
        'upcoming_follow_ups': 1, 'side_effects_pending': 1, 'side_effects_resolved': 0, 'side_effects_responded': 0,
      },
      'progress': {'patients': 1, 'elevated_risk_pattern': 1, 'needs_attention': 1},
    });

DoctorPatientLink link() => DoctorPatientLink.fromJson({
      'id': 'ar1',
      'status': 'approved',
      'requested_at': '2026-09-01T10:00:00Z',
      'doctor': {'id': 'doc1', 'name': 'James Wilson', 'doctor_code': 'SUS-D-000001', 'specialization': 'Endocrinology'},
      'patient': {
        'id': 'pat1', 'name': 'Sophia Lee', 'patient_code': 'SUS-P-0A1B2C', 'is_active': true,
        'latest_assessment': {'id': 'dr1', 'risk_percent': 72.5, 'risk_category': 'High', 'prediction': 1, 'prediction_label': 'Higher-risk pattern',
            'report_available': true, 'assessed_at': '2026-09-20T08:00:00Z', 'model_version': '4.0.0'},
        'latest_glucose': {'value': 104, 'measured_at': '2026-09-25T08:00:00Z'},
        'glucose_trend': 'stable', 'open_side_effects': 1,
        'attention': [{'reason': 'Moderate side effect reported', 'entity_type': 'side_effect', 'entity_id': 'se1'}],
      },
    });

void main() {
  late MockAdminRepository repo;
  setUp(() {
    repo = MockAdminRepository();
    when(() => repo.doctors(query: any(named: 'query'), status: any(named: 'status'))).thenAnswer((_) async => [DoctorProfile.fromJson(doctorJson)]);
    when(() => repo.doctor('doc1')).thenAnswer((_) async => detail());
    when(() => repo.doctorPatients('doc1')).thenAnswer((_) async => [link()]);
    when(() => repo.doctorActivity('doc1', scope: any(named: 'scope'))).thenAnswer((_) async => (
          items: [
            LinkedAuditEntry.fromJson({
              'id': 'a1', 'created_at': '2026-09-25T10:32:00Z', 'action': 'prescription_created', 'actor_name': 'James Wilson', 'actor_role': 'doctor',
              'entity_type': 'prescription', 'entity_id': 'rx1', 'entity_label': 'RX-000001',
              'patient': {'id': 'pat1', 'name': 'Sophia Lee', 'patient_code': 'SUS-P-0A1B2C'},
            }),
          ],
          total: 1,
        ));
  });

  Future<void> pumpRouter(WidgetTester tester, String initial) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: initial, routes: [
      GoRoute(path: '/a/doctors', builder: (_, _) => const AdminDoctorsScreen()),
      GoRoute(path: '/a/doctors/:id', builder: (_, s) => AdminDoctorProfileScreen(doctorId: s.pathParameters['id']!, initialTab: s.uri.queryParameters['tab'])),
      GoRoute(path: '/a/doctors/:id/edit', builder: (_, _) => const Scaffold(body: Text('EDIT FORM'))),
      GoRoute(path: '/a/patients/:pid', builder: (_, s) => Scaffold(body: Text('PATIENT ${s.pathParameters['pid']}'))),
      GoRoute(path: '/r/:pid/prescriptions/:id', builder: (_, s) => Scaffold(body: Text('PRESCRIPTION ${s.pathParameters['id']}'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [currentUserProvider.overrideWithValue(testAdmin), adminRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('selecting a doctor opens the profile, not the edit form', (tester) async {
    await pumpRouter(tester, '/a/doctors');
    await tester.tap(find.text('View Profile'));
    await tester.pumpAndSettle();
    expect(find.text('EDIT FORM'), findsNothing);
    expect(find.text('Dr. James Wilson'), findsWidgets);
    expect(find.text('Doctor ID: SUS-D-000001'), findsOneWidget);
    // Real numbers from the repository, not placeholders.
    expect(find.text('Active patients'), findsOneWidget);
    expect(find.text('2 total · 1 pending'), findsOneWidget);
    expect(find.text('Sophia Lee'), findsWidgets);
    expect(find.text('High risk'), findsWidgets); // the model's risk band, never a diagnosis
    expect(find.text('Prescription created'), findsOneWidget);
  });

  testWidgets('Edit Doctor is a separate action and patients drill down to their profile', (tester) async {
    await pumpRouter(tester, '/a/doctors/doc1');
    await tester.tap(find.text('Edit Doctor').first);
    await tester.pumpAndSettle();
    expect(find.text('EDIT FORM'), findsOneWidget);

    await pumpRouter(tester, '/a/doctors/doc1');
    await tester.tap(find.text('Sophia Lee').first);
    await tester.pumpAndSettle();
    expect(find.text('PATIENT pat1'), findsOneWidget);

    await pumpRouter(tester, '/a/doctors/doc1');
    await tester.tap(find.text('Prescription created'));
    await tester.pumpAndSettle();
    expect(find.text('PRESCRIPTION rx1'), findsOneWidget);
  });

  testWidgets('a failing section keeps the rest of the profile usable', (tester) async {
    when(() => repo.doctorActivity('doc1', scope: any(named: 'scope'))).thenThrow(Exception('boom'));
    await pumpRouter(tester, '/a/doctors/doc1');
    expect(find.text('Unable to load Recent Activity.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Sophia Lee'), findsWidgets);
  });
}
