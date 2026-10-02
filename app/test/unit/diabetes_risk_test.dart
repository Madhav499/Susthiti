import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/core/errors/failures.dart';
import 'package:susthiti/data/models/diabetes_risk.dart';
import 'package:susthiti/data/models/health_data.dart';
import 'package:susthiti/data/providers.dart';
import 'package:susthiti/data/repositories/diabetes_repository.dart';
import 'package:susthiti/data/services/risk_cache.dart';
import 'package:susthiti/features/authentication/auth_controller.dart';
import 'package:susthiti/features/diabetes/diabetes_providers.dart';

import '../helpers.dart';
import '../risk_fixtures.dart';

class MockDiabetesRepository extends Mock implements DiabetesRepository {}

void main() {
  test('an assessment keeps the API\'s own numbers, category and report basis', () {
    final a = RiskAssessment.fromJson(assessmentJson());
    expect(a.riskPercent, 43.21);
    expect(a.percentLabel, '43.2%');
    expect(a.riskCategory, 'Moderate');
    expect(a.reportAvailable, isTrue);
    expect(a.reportFieldsPresent, ['hba1c', 'fasting_glucose']);
    expect(a.basisText, 'Includes HbA1c and fasting glucose from your medical reports.');
    expect(a.riskThresholds['moderate'], '>40-65%');
    expect(a.dataUsed.groups.map((g) => g.key), ['profile', 'report', 'wearable']);
    expect(a.dataUsed.missing.single.target, AddDataTarget.healthProfile);
  });

  test('without report values the basis says so, and never implies a normal result', () {
    final a = RiskAssessment.fromJson(assessmentJson(report: false));
    expect(a.basisText, RiskWording.noReportBasis);
    expect(a.basisText.toLowerCase(), isNot(contains('normal')));
    expect(a.dataUsed.missing.map((m) => m.target), contains(AddDataTarget.reportValues));
  });

  test('incomplete responses are rejected, not shown with made-up values', () {
    expect(() => RiskAssessment.fromJson({...assessmentJson(), 'risk_percent': null}), throwsFormatException);
    expect(RiskBrief.maybe({'id': 'x', 'risk_category': 'Low'}), isNull);
  });

  test('risk band tones follow the API category', () {
    expect(RiskWording.categoryLabel('High'), 'High risk');
    expect(RiskWording.tone('High'), isNot(RiskWording.tone('Low')));
  });

  test('"not sure" and "not answered" are different', () {
    const unsure = HealthProfileField(key: 'hypertension', group: 'medical_history', label: 'High blood pressure', kind: ProfileFieldKind.yesNo, answered: true);
    const blank = HealthProfileField(key: 'hypertension', group: 'medical_history', label: 'High blood pressure', kind: ProfileFieldKind.yesNo);
    expect(unsure.answerLabel, 'Not sure');
    expect(blank.answerLabel, 'Not answered');
    const female = HealthProfileField(key: 'pcos', group: 'medical_history', label: 'PCOS', kind: ProfileFieldKind.yesNo, appliesTo: 'Female');
    expect(female.appliesToSex('Male'), isFalse);
  });

  group('offline', () {
    late MockDiabetesRepository repo;
    late MemoryRiskCache cache;
    setUp(() {
      repo = MockDiabetesRepository();
      cache = MemoryRiskCache();
    });

    ProviderContainer container(user) {
      final c = ProviderContainer(retry: (_, _) => null, overrides: [
        diabetesRepositoryProvider.overrideWithValue(repo),
        riskCacheProvider.overrideWithValue(cache),
        currentUserProvider.overrideWithValue(user),
      ]);
      c.listen(riskStatusProvider('pat1'), (_, _) {}); // keep the auto-disposing provider alive
      return c;
    }

    test('the patient sees their last assessment, marked offline', () async {  // TEST 15
      when(() => repo.riskStatus('pat1')).thenAnswer((_) async => RiskStatus.fromJson(statusJson(latest: assessmentJson())));
      final online = container(testPatient);
      addTearDown(online.dispose);
      expect((await online.read(riskStatusProvider('pat1').future)).offline, isFalse);

      when(() => repo.riskStatus('pat1')).thenThrow(const NetworkFailure());
      final offline = container(testPatient);
      addTearDown(offline.dispose);
      final status = await offline.read(riskStatusProvider('pat1').future);
      expect(status.offline, isTrue);
      expect(status.latest!.riskPercent, 43.21);
    });

    test('other patients\' data is never cached on a doctor\'s device', () async {
      when(() => repo.riskStatus('pat1')).thenAnswer((_) async => RiskStatus.fromJson(statusJson(latest: assessmentJson())));
      final c = container(testDoctor);
      addTearDown(c.dispose);
      await c.read(riskStatusProvider('pat1').future);
      expect(await cache.load('pat1'), isNull);
    });

    test('with nothing cached, the failure is shown', () async {  // TEST 16
      when(() => repo.riskStatus('pat1')).thenThrow(const NetworkFailure());
      final c = container(testPatient);
      addTearDown(c.dispose);
      await expectLater(c.read(riskStatusProvider('pat1').future), throwsA(isA<NetworkFailure>()));
    });
  });
}
