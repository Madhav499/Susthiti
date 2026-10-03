import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/core/errors/failures.dart';
import 'package:susthiti/data/models/diabetes_risk.dart';
import 'package:susthiti/data/models/health_data.dart';
import 'package:susthiti/data/models/tracking.dart';
import 'package:susthiti/data/providers.dart';
import 'package:susthiti/data/repositories/diabetes_repository.dart';
import 'package:susthiti/data/repositories/patient_repository.dart';
import 'package:susthiti/data/repositories/report_repository.dart';
import 'package:susthiti/data/services/risk_cache.dart';
import 'package:susthiti/features/diabetes/diabetes_screen.dart';
import 'package:susthiti/features/health_profile/health_profile_screen.dart';
import 'package:susthiti/features/reports/report_values_section.dart';

import '../helpers.dart';
import '../risk_fixtures.dart';

class MockDiabetesRepository extends Mock implements DiabetesRepository {}

class MockPatientRepository extends Mock implements PatientRepository {}

class MockReportRepository extends Mock implements ReportRepository {}

void main() {
  late MockDiabetesRepository repo;
  late MemoryRiskCache cache;
  late MockPatientRepository patients;

  setUpAll(() => registerFallbackValue(<String, Object?>{}));

  setUp(() {
    repo = MockDiabetesRepository();
    cache = MemoryRiskCache();
    patients = MockPatientRepository();
    when(() => repo.riskHistory(any())).thenAnswer((_) async => (items: [RiskAssessment.fromJson(assessmentJson())], total: 1));
    // DiabetesView's HbA1c trend card reads this; tests below only exercise the risk estimate
    // itself, so an empty series (its own honest "nothing recorded" state) keeps them focused.
    when(() => patients.trend(any(), any(), any(), start: any(named: 'start'), end: any(named: 'end')))
        .thenAnswer((_) async => const TrendSeries(metric: 'hba1c', unit: '%', points: []));
  });

  Future<void> pumpView(WidgetTester tester, Map<String, dynamic> status, {user = testPatient, bool canAssess = true}) async {
    when(() => repo.riskStatus('pat1')).thenAnswer((_) async => RiskStatus.fromJson(status));
    await pumpScreen(tester, Scaffold(body: DiabetesView(patientId: 'pat1', canAssess: canAssess)), user: user, overrides: [
      diabetesRepositoryProvider.overrideWithValue(repo),
      riskCacheProvider.overrideWithValue(cache),
      patientRepositoryProvider.overrideWithValue(patients),
    ]);
  }

  testWidgets('first time: explains there is no questionnaire and offers an estimate', (tester) async {
    when(() => repo.refreshRisk('pat1')).thenAnswer((_) async => RiskRefresh.fromJson({'created': true, 'assessment': assessmentJson()}));
    await pumpView(tester, statusJson());
    expect(find.textContaining('There is no questionnaire'), findsOneWidget);
    expect(find.textContaining('4 of 29 health details'), findsOneWidget);
    await tester.tap(find.text('Get my risk estimate'));
    await tester.pumpAndSettle();
    verify(() => repo.refreshRisk('pat1')).called(1);
    expect(find.text('Your future diabetes risk estimate has been updated.'), findsOneWidget);
  });

  testWidgets('with report values: model estimate, band, exactly which report values were used', (tester) async {
    await pumpView(tester, statusJson(latest: assessmentJson(), history: 1));
    expect(find.text('43.2%'), findsWidgets);
    expect(find.text('Model-estimated risk'), findsOneWidget);
    expect(find.text('Moderate risk'), findsWidgets);
    expect(find.text('Includes HbA1c and fasting glucose from your medical reports.'), findsOneWidget);
    expect(find.text('This is a machine-learning future-risk estimate, not a medical diagnosis.'), findsOneWidget);
    // Data used, by source.
    expect(find.text('Medical reports'), findsOneWidget);
    expect(find.text('Smartwatch and health apps'), findsOneWidget);
    expect(find.text('HbA1c: 6.1 %'), findsOneWidget);
    // Never diagnostic wording.
    expect(find.textContaining('You have diabetes'), findsNothing);
    expect(find.textContaining('will develop'), findsNothing);
  });

  testWidgets('without report values: says so and shows the API warning, never "normal"', (tester) async {  // TEST 2, PART 46
    await pumpView(tester, statusJson(latest: assessmentJson(report: false)));
    expect(find.text(RiskWording.noReportBasis), findsOneWidget);
    expect(find.textContaining('not fully trusted'), findsOneWidget);
    expect(find.textContaining('normal', findRichText: true), findsNothing);
    expect(find.text('Add values from a report'), findsOneWidget);
  });

  testWidgets('new health data: marked out of date with the reasons; refresh with no changes says so', (tester) async {  // TEST 14
    when(() => repo.refreshRisk('pat1')).thenAnswer((_) async => RiskRefresh.fromJson({'created': false, 'assessment': assessmentJson()}));
    await pumpView(tester, statusJson(latest: assessmentJson(), stale: true, reasons: ['New or changed values from your medical reports']));
    expect(find.text('Updated health information is available.'), findsOneWidget);
    expect(find.text('• New or changed values from your medical reports'), findsOneWidget);
    await tester.ensureVisible(find.text('Refresh assessment').first);
    await tester.tap(find.text('Refresh assessment').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing relevant has changed'), findsOneWidget);
  });

  testWidgets('refresh failure keeps the last assessment and explains calmly', (tester) async {  // TEST 16
    when(() => repo.refreshRisk('pat1')).thenThrow(const ModelServiceFailure('The diabetes assessment service is unavailable right now. Please try again later.', 'model_service_unavailable'));
    await pumpView(tester, statusJson(latest: assessmentJson(), stale: true, reasons: ['Your medical history changed']));
    await tester.tap(find.text('Refresh assessment').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('unavailable right now'), findsOneWidget);
    expect(find.text('43.2%'), findsWidgets);
  });

  testWidgets('offline: the last assessment with its date, and no refresh', (tester) async {  // TEST 15, PART 63
    await cache.save('pat1', statusJson(latest: assessmentJson(), stale: true, reasons: ['Your medical history changed']));
    when(() => repo.riskStatus('pat1')).thenThrow(const NetworkFailure());
    await pumpScreen(tester, const Scaffold(body: DiabetesView(patientId: 'pat1', canAssess: true)), user: testPatient, overrides: [
      diabetesRepositoryProvider.overrideWithValue(repo),
      riskCacheProvider.overrideWithValue(cache),
      patientRepositoryProvider.overrideWithValue(patients),
    ]);
    expect(find.textContaining('You\'re offline. Showing your last assessment'), findsOneWidget);
    expect(find.textContaining('Connect to the internet to update your assessment'), findsOneWidget);
    expect(find.text('43.2%'), findsWidgets);
    expect(find.text('Refresh assessment'), findsNothing);
  });

  testWidgets('admin: read-only, no refresh and no add-data links', (tester) async {
    await pumpView(tester, statusJson(latest: assessmentJson(report: false)), user: testAdmin, canAssess: false);
    expect(find.text('Refresh assessment'), findsNothing);
    expect(find.text('Add values from a report'), findsNothing);
    expect(find.text('Open health profile'), findsNothing);
  });

  testWidgets('health profile: "Not sure" is saved as unknown, never as No', (tester) async {
    final patients = MockPatientRepository();
    final profile = HealthProfile.fromJson({
      'patient_id': 'pat1', 'sex': 'Male',
      'groups': [{'key': 'medical_history', 'label': 'Medical history'}, {'key': 'family_history', 'label': 'Family history'}],
      'fields': [
        {'key': 'hypertension', 'group': 'medical_history', 'label': 'High blood pressure diagnosed by a doctor', 'kind': 'yes_no', 'options': [], 'answered': false},
        {'key': 'pcos', 'group': 'medical_history', 'label': 'Polycystic ovary syndrome (PCOS)', 'kind': 'yes_no', 'options': [], 'applies_to': 'Female', 'answered': false},
        {'key': 'family_history_diabetes', 'group': 'family_history', 'label': 'A parent, brother or sister has diabetes', 'kind': 'yes_no', 'options': [], 'answered': false},
      ],
    });
    when(() => patients.healthProfile('pat1')).thenAnswer((_) async => profile);
    when(() => patients.updateHealthProfile('pat1', any())).thenAnswer((_) async => profile);
    when(() => repo.riskStatus('pat1')).thenAnswer((_) async => RiskStatus.fromJson(statusJson()));
    await pumpScreen(tester, const HealthProfileScreen(patientId: 'pat1'), user: testPatient, overrides: [
      patientRepositoryProvider.overrideWithValue(patients),
      diabetesRepositoryProvider.overrideWithValue(repo),
    ]);
    expect(find.text('Polycystic ovary syndrome (PCOS)'), findsNothing); // not asked for this patient
    await tester.tap(find.text('Not sure').first);
    await tester.tap(find.text('Yes').last);
    await tester.pump();
    await tester.ensureVisible(find.text('Save health profile'));
    await tester.tap(find.text('Save health profile'));
    await tester.pumpAndSettle();
    final saved = verify(() => patients.updateHealthProfile('pat1', captureAny())).captured.single as Map<String, Object?>;
    expect(saved, {'hypertension': null, 'family_history_diabetes': true});
  });

  testWidgets('report values: confirmed once on the report, converted units kept as entered', (tester) async {
    final reports = MockReportRepository();
    final values = ReportValues.fromJson({
      'report_id': 'r1', 'report_code': 'RP-000012', 'report_date': '2026-09-12', 'values': [],
      'suggestions': [{'analyte': 'hba1c', 'label': 'HbA1c', 'value': 6.1, 'unit': '%', 'entered_value': 6.1, 'entered_unit': '%', 'source_name': 'HbA1c'}],
      'analytes': [
        {'key': 'hba1c', 'label': 'HbA1c', 'kind': 'number', 'unit': '%', 'units': ['%'], 'options': []},
        {'key': 'fasting_glucose', 'label': 'Fasting glucose', 'kind': 'number', 'unit': 'mg/dL', 'units': ['mg/dL', 'mmol/L'], 'options': []},
        {'key': 'diabetes_classification', 'label': 'Report conclusion (diabetes)', 'kind': 'classification', 'units': [],
         'options': [{'value': 'normal', 'label': 'Normal'}, {'value': 'prediabetes', 'label': 'Prediabetes'}, {'value': 'diabetes', 'label': 'Diabetes'}]},
      ],
    });
    when(() => reports.values('r1')).thenAnswer((_) async => values);
    when(() => reports.saveValues('r1', any())).thenAnswer((_) async => values);
    when(() => repo.riskStatus('pat1')).thenAnswer((_) async => RiskStatus.fromJson(statusJson()));
    await pumpScreen(tester, const Scaffold(body: SingleChildScrollView(child: ReportValuesSection(reportId: 'r1', patientId: 'pat1'))), user: testPatient, overrides: [
      reportRepositoryProvider.overrideWithValue(reports),
      diabetesRepositoryProvider.overrideWithValue(repo),
    ]);
    // AI suggestions are shown for checking, and only count once confirmed.
    expect(find.textContaining('Found in the AI summary'), findsOneWidget);
    await tester.tap(find.text('These match the report'));
    await tester.pumpAndSettle();
    expect(verify(() => reports.saveValues('r1', captureAny())).captured.single, {'hba1c': {'value': 6.1, 'unit': '%', 'origin': 'ai_suggestion'}});

    await tester.tap(find.text('Add values from this report'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('value-fasting_glucose')), '6.2');
    await tester.tap(find.text('mg/dL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('mmol/L').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prediabetes'));
    await tester.tap(find.text('Save values'));
    await tester.pumpAndSettle();
    expect(verify(() => reports.saveValues('r1', captureAny())).captured.single, {
      'fasting_glucose': {'value': 6.2, 'unit': 'mmol/L'},
      'diabetes_classification': {'text_value': 'prediabetes'},
    });
  });
}
