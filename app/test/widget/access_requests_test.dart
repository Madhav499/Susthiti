import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/data/models/patient.dart';
import 'package:susthiti/data/providers.dart';
import 'package:susthiti/data/repositories/patient_repository.dart';
import 'package:susthiti/features/access/access_screens.dart';

import '../helpers.dart';

class MockPatientRepository extends Mock implements PatientRepository {}

AccessRequest request(String status) => AccessRequest.fromJson({
      'id': 'ar1',
      'status': status,
      'requested_at': '2026-09-20T10:00:00Z',
      'message': 'I am your endocrinologist.',
      'doctor': {'id': 'd1', 'name': 'Rao Demo', 'doctor_code': 'SUS-D-000001', 'specialization': 'Endocrinology'},
      'patient': {'id': 'pat1', 'name': 'Asha Demo', 'patient_code': 'SUS-P-0A1B2C'},
    });

void main() {
  late MockPatientRepository repo;
  setUp(() => repo = MockPatientRepository());

  testWidgets('patient approves a pending request', (tester) async {
    var status = 'pending';
    when(() => repo.accessRequests()).thenAnswer((_) async => [request(status)]);
    when(() => repo.respondToAccess('ar1', approve: true)).thenAnswer((_) async {
      status = 'approved';
      return request('approved');
    });

    await pumpScreen(tester, const AccessRequestsScreen(), user: testPatient, overrides: [patientRepositoryProvider.overrideWithValue(repo)]);
    expect(find.text('Dr. Rao Demo'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    verify(() => repo.respondToAccess('ar1', approve: true)).called(1);
    expect(find.text('Revoke access'), findsOneWidget);
  });

  testWidgets('revoking asks for confirmation first', (tester) async {
    when(() => repo.accessRequests()).thenAnswer((_) async => [request('approved')]);
    when(() => repo.revokeAccess('ar1')).thenAnswer((_) async => request('revoked'));

    await pumpScreen(tester, const AccessRequestsScreen(), user: testPatient, overrides: [patientRepositoryProvider.overrideWithValue(repo)]);
    await tester.tap(find.text('Revoke access'));
    await tester.pumpAndSettle();
    expect(find.text('Revoke access?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => repo.revokeAccess(any()));
  });

  testWidgets('empty state explains how doctors request access', (tester) async {
    when(() => repo.accessRequests()).thenAnswer((_) async => []);
    await pumpScreen(tester, const AccessRequestsScreen(), user: testPatient, overrides: [patientRepositoryProvider.overrideWithValue(repo)]);
    expect(find.text('No access requests.'), findsOneWidget);
  });
}
