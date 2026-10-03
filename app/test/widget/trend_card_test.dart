import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/data/models/tracking.dart';
import 'package:susthiti/data/providers.dart';
import 'package:susthiti/data/repositories/patient_repository.dart';
import 'package:susthiti/features/lifestyle/trend_card.dart';

import '../helpers.dart';

class MockPatientRepository extends Mock implements PatientRepository {}

void main() {
  late MockPatientRepository patients;

  setUp(() => patients = MockPatientRepository());

  Future<void> pump(WidgetTester tester, TrendSeries series) async {
    when(() => patients.trend(any(), any(), any(), start: any(named: 'start'), end: any(named: 'end'))).thenAnswer((_) async => series);
    await pumpScreen(
      tester,
      Scaffold(body: TrendCard(patientId: 'pat1', metric: 'hba1c', title: 'HbA1c', ranges: TrendCard.clinicalRanges)),
      user: testPatient,
      overrides: [patientRepositoryProvider.overrideWithValue(patients)],
    );
  }

  // Regression: TrendCard used to assume every non-glucose metric was a LifestyleMetricType and
  // crashed with "Bad state: No element" for a report-derived analyte like HbA1c.
  testWidgets('a report analyte metric does not crash and shows its own unit', (tester) async {
    await pump(tester, TrendSeries(metric: 'hba1c', unit: '%', points: [DailyValue(date: DateTime(2026, 1, 5), value: 6.0), DailyValue(date: DateTime(2026, 4, 10), value: 8.0)]));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('7 %'), findsOneWidget); // average of 6.0 and 8.0
  });

  testWidgets('a single result is shown as a fact, not a trend', (tester) async {
    await pump(tester, TrendSeries(metric: 'hba1c', unit: '%', points: [DailyValue(date: DateTime(2026, 1, 5), value: 6.1)]));
    expect(tester.takeException(), isNull);
    expect(find.text('Single recorded result'), findsOneWidget);
    expect(find.textContaining('6.1 %'), findsOneWidget);
    expect(find.text('More results are needed to show a trend.'), findsOneWidget);
  });

  testWidgets('no recorded values shows an honest empty state, not a fabricated chart', (tester) async {
    await pump(tester, const TrendSeries(metric: 'hba1c', unit: '%', points: []));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('No hba1c recorded in this period.'), findsOneWidget);
  });
}
