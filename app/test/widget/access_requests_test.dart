import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/data/models/patient.dart';
import 'package:susthiti/data/providers.dart';
import 'package:susthiti/data/repositories/patient_repository.dart';
import 'package:susthiti/features/access/access_screens.dart';
import 'package:susthiti/features/authentication/auth_controller.dart';
import 'package:susthiti/l10n/app_localizations.dart';

import '../helpers.dart';

class MockPatientRepository extends Mock implements PatientRepository {}
class MockDoctorRepository extends Mock implements DoctorRepository {}
class MockAdminRepository extends Mock implements AdminRepository {}

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
    expect(find.text('Doctor: Rao Demo'), findsOneWidget);
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

  final locales = <({String code, String pending, String approved, String rejected, String revoked, String doctor, String patient, String id, String approve, String reject, String revoke, String empty})>[
    (code: 'en', pending: 'Pending', approved: 'Approved', rejected: 'Rejected', revoked: 'Revoked', doctor: 'Doctor: Rao Demo', patient: 'Patient: Asha Demo · SUS-P-0A1B2C', id: 'Patient ID: SUS-P-0A1B2C', approve: 'Approve', reject: 'Reject', revoke: 'Revoke access', empty: 'No access requests.'),
    (code: 'hi', pending: 'लंबित', approved: 'स्वीकृत', rejected: 'अस्वीकृत', revoked: 'रद्द', doctor: 'डॉक्टर: Rao Demo', patient: 'मरीज़: Asha Demo · SUS-P-0A1B2C', id: 'मरीज़ ID: SUS-P-0A1B2C', approve: 'मंज़ूर करें', reject: 'अस्वीकार करें', revoke: 'एक्सेस हटाएं', empty: 'कोई एक्सेस रिक्वेस्ट नहीं है।'),
    (code: 'gu', pending: 'બાકી', approved: 'મંજૂર', rejected: 'નામંજૂર', revoked: 'રદ કરેલ', doctor: 'ડૉક્ટર: Rao Demo', patient: 'દર્દી: Asha Demo · SUS-P-0A1B2C', id: 'દર્દી ID: SUS-P-0A1B2C', approve: 'મંજૂર કરો', reject: 'નકારો', revoke: 'ઍક્સેસ દૂર કરો', empty: 'કોઈ ઍક્સેસ રિક્વેસ્ટ નથી.'),
  ];

  for (final l in locales) {
    testWidgets('admin access requests use ${l.code} labels and preserve names', (tester) async {
      final admin = MockAdminRepository();
      when(() => admin.accessRequests()).thenAnswer((_) async => [request('pending'), request('approved'), request('rejected'), request('revoked')]);
      await pumpScreen(tester, const AccessRequestsScreen(), user: testAdmin, locale: Locale(l.code), overrides: [adminRepositoryProvider.overrideWithValue(admin)]);

      for (final label in [l.pending, l.approved, l.rejected, l.revoked]) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.text(l.doctor), findsWidgets);
      expect(find.text(l.patient), findsWidgets);
      expect(find.textContaining('SUS-P-0A1B2C'), findsWidgets);
      expect(find.textContaining('Rao Demo'), findsWidgets);
      expect(find.textContaining('Asha Demo'), findsWidgets);
      expect(find.text(l.revoke), findsWidgets);
      expect(find.text('Doctor'), findsNothing);
      verify(() => admin.accessRequests()).called(1);
    });

    testWidgets('doctor access requests use ${l.code} labels and empty state', (tester) async {
      final doctor = MockDoctorRepository();
      when(() => doctor.accessRequests()).thenAnswer((_) async => []);
      await pumpScreen(tester, const AccessRequestsScreen(), user: testDoctor, locale: Locale(l.code), overrides: [doctorRepositoryProvider.overrideWithValue(doctor)]);
      expect(find.text(l.pending), findsOneWidget);
      expect(find.text(l.approved), findsOneWidget);
      expect(find.text(l.rejected), findsOneWidget);
      expect(find.text(l.revoked), findsOneWidget);
      expect(find.text(l.empty), findsOneWidget);
      verify(() => doctor.accessRequests()).called(1);
    });

    testWidgets('patient approval and rejection actions use ${l.code} labels', (tester) async {
      when(() => repo.accessRequests()).thenAnswer((_) async => [request('pending')]);
      when(() => repo.respondToAccess('ar1', approve: true)).thenAnswer((_) async => request('approved'));
      await pumpScreen(tester, const AccessRequestsScreen(), user: testPatient, locale: Locale(l.code), overrides: [patientRepositoryProvider.overrideWithValue(repo)]);
      expect(find.text(l.approve), findsOneWidget);
      expect(find.text(l.reject), findsOneWidget);
      await tester.tap(find.text(l.approve));
      await tester.pumpAndSettle();
      verify(() => repo.respondToAccess('ar1', approve: true)).called(1);
    });
  }

  testWidgets('doctor request card localizes field labels and keeps patient identity unchanged', (tester) async {
    final doctor = MockDoctorRepository();
    when(() => doctor.accessRequests()).thenAnswer((_) async => [request('pending')]);
    await pumpScreen(tester, const AccessRequestsScreen(), user: testDoctor, locale: const Locale('hi'), overrides: [doctorRepositoryProvider.overrideWithValue(doctor)]);
    expect(find.text('मरीज़: Asha Demo'), findsOneWidget);
    expect(find.text('मरीज़ ID: SUS-P-0A1B2C'), findsOneWidget);
    expect(find.textContaining('Asha Demo'), findsOneWidget);
    expect(find.textContaining('Rao Demo'), findsNothing);
    expect(find.text('मंज़ूर करें'), findsNothing);
  });

  testWidgets('changing the screen locale updates access status labels immediately', (tester) async {
    final doctor = MockDoctorRepository();
    when(() => doctor.accessRequests()).thenAnswer((_) async => [request('pending')]);
    var locale = const Locale('en');
    await tester.pumpWidget(ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(testDoctor), doctorRepositoryProvider.overrideWithValue(doctor)],
      child: StatefulBuilder(builder: (context, setState) => MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        home: Column(children: [TextButton(onPressed: () => setState(() => locale = const Locale('gu')), child: const Text('switch')), const Expanded(child: AccessRequestsScreen())]),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Pending'), findsWidgets);
    await tester.tap(find.text('switch'));
    await tester.pumpAndSettle();
    expect(find.text('બાકી'), findsWidgets);
    expect(find.text('Pending'), findsNothing);
  });

  testWidgets('admin revocation confirmation is localized and preserves revoke behavior', (tester) async {
    final admin = MockAdminRepository();
    when(() => admin.accessRequests()).thenAnswer((_) async => [request('approved')]);
    when(() => admin.revokeAccess('ar1')).thenAnswer((_) async => request('revoked'));
    await pumpScreen(tester, const AccessRequestsScreen(), user: testAdmin, locale: const Locale('hi'), overrides: [adminRepositoryProvider.overrideWithValue(admin)]);
    await tester.tap(find.text('एक्सेस हटाएं'));
    await tester.pumpAndSettle();
    expect(find.text('एक्सेस हटाएं?'), findsOneWidget);
    expect(find.textContaining('Rao Demo'), findsWidgets);
    expect(find.textContaining('Asha Demo'), findsWidgets);
    expect(find.text('रद्द करें'), findsOneWidget);
    await tester.tap(find.text('हटाएं'));
    await tester.pumpAndSettle();
    verify(() => admin.revokeAccess('ar1')).called(1);
  });
}
