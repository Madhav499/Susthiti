import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:susthiti/data/models/care.dart';
import 'package:susthiti/data/providers.dart';
import 'package:susthiti/data/repositories/side_effect_repository.dart';
import 'package:susthiti/features/side_effects/side_effects_screens.dart';

import '../helpers.dart';

class MockSideEffectRepository extends Mock implements SideEffectRepository {}

final effect = SideEffect.fromJson({
  'id': 'se1', 'side_effect_code': 'SE-000001', 'patient_id': 'pat1', 'description': 'Dizziness after morning dose', 'severity': 'severe',
  'related_medication': 'Metformin', 'occurred_at': '2026-09-20T07:00:00Z', 'status': 'new', 'priority_flag': true, 'created_at': '2026-09-20T07:30:00Z',
  'history': [
    {'id': 'e1', 'status': 'new', 'actor_name': 'Asha Demo', 'actor_role': 'patient', 'created_at': '2026-09-20T07:30:00Z'},
  ],
});

void main() {
  late MockSideEffectRepository repo;
  setUp(() {
    repo = MockSideEffectRepository();
    when(() => repo.get('se1')).thenAnswer((_) async => effect);
  });

  testWidgets('patient sees the report and priority reason but no doctor actions', (tester) async {
    await pumpScreen(tester, const SideEffectDetailScreen(patientId: 'pat1', sideEffectId: 'se1'), user: testPatient, overrides: [sideEffectRepositoryProvider.overrideWithValue(repo)]);
    expect(find.text('Dizziness after morning dose'), findsOneWidget);
    expect(find.textContaining('This is not a clinical judgement'), findsOneWidget);
    expect(find.text('Doctor actions'), findsNothing);
  });

  testWidgets('doctor can respond and change status', (tester) async {
    when(() => repo.setStatus('se1', SideEffectStatus.underReview)).thenAnswer((_) async => effect);
    await pumpScreen(tester, const SideEffectDetailScreen(patientId: 'pat1', sideEffectId: 'se1'), user: testDoctor, overrides: [sideEffectRepositoryProvider.overrideWithValue(repo)]);
    expect(find.text('Doctor actions'), findsOneWidget);
    expect(find.text('Respond'), findsOneWidget);
    await tester.tap(find.text('Mark under review'));
    await tester.pumpAndSettle();
    verify(() => repo.setStatus('se1', SideEffectStatus.underReview)).called(1);
  });
}
