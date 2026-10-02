import 'package:flutter_test/flutter_test.dart';
import 'package:susthiti/core/validators/validators.dart';
import 'package:susthiti/data/models/ai_summary.dart';
import 'package:susthiti/data/models/care.dart';
import 'package:susthiti/data/models/diabetes.dart';
import 'package:susthiti/data/models/patient.dart';

void main() {
  group('DiabetesAssessment', () {
    Map<String, dynamic> json(String prediction) => {
          'id': 'a1', 'assessment_code': 'DA-000001', 'patient_id': 'p1', 'assessed_at': '2026-09-20T10:00:00Z',
          'model_version': 'diabetes_all_age_gender_model', 'inputs': {'Age': 40}, 'prediction': prediction, 'classification_probability': 0.82,
        };

    test('uses responsible headline wording', () {
      expect(DiabetesAssessment.fromJson(json('Positive')).headline, 'Diabetes-related pattern detected');
      expect(DiabetesAssessment.fromJson(json('Negative')).headline, 'No diabetes-related pattern detected');
    });

    test('never phrases the result as a future-onset prediction', () {
      final a = DiabetesAssessment.fromJson(json('Positive'));
      expect(a.explanation.toLowerCase(), isNot(contains('will develop')));
      expect(a.explanation, contains('pattern associated with diabetes'));
      expect(a.classificationProbability, 0.82);
    });
  });

  test('AI summary PDF filename follows the SUSTHITI_<Label>_<date> pattern', () {
    final s = AISummary.fromJson({
      'id': 's1', 'kind': 'patient_summary', 'content': {'overview': 'x'}, 'generated_at': '2026-09-24T08:00:00Z', 'model': 'gemini', 'provider': 'google',
    });
    expect(s.pdfFilename, 'SUSTHITI_Patient_Summary_2026-09-24.pdf');
    expect(s.kind.label, 'AI Patient Summary');
  });

  test('side effect parses status history and priority flag', () {
    final s = SideEffect.fromJson({
      'id': 'se1', 'side_effect_code': 'SE-000001', 'patient_id': 'p1', 'description': 'Dizziness', 'severity': 'severe',
      'occurred_at': '2026-09-20T10:00:00Z', 'status': 'appointment_recommended', 'priority_flag': true, 'created_at': '2026-09-20T10:05:00Z',
      'history': [
        {'id': 'e1', 'status': 'new', 'actor_name': 'Asha', 'actor_role': 'patient', 'created_at': '2026-09-20T10:05:00Z'},
        {'id': 'e2', 'status': 'appointment_recommended', 'response_type': 'appointment_recommended', 'message': 'Please visit', 'actor_name': 'Rao', 'actor_role': 'doctor', 'created_at': '2026-09-20T12:00:00Z'},
      ],
    });
    expect(s.priorityFlag, isTrue);
    expect(s.status, SideEffectStatus.appointmentRecommended);
    expect(s.history.last.response, DoctorResponse.appointmentRecommended);
  });

  test('prescription keeps its structured medicine list', () {
    final p = Prescription.fromJson({
      'id': 'rx1', 'prescription_code': 'RX-000001', 'doctor_name': 'Rao', 'prescribed_on': '2026-09-20', 'created_at': '2026-09-20T10:00:00Z',
      'medicines': [
        {'medicine': 'Metformin', 'dosage': '500 mg', 'frequency': 'Twice daily', 'duration': '30 days', 'instructions': 'After meals'},
      ],
    });
    expect(p.medicines.single.medicine, 'Metformin');
    expect(p.medicines.single.toJson()['instructions'], 'After meals');
  });

  test('access request parses both sides', () {
    final r = AccessRequest.fromJson({
      'id': 'ar1', 'status': 'pending', 'requested_at': '2026-09-20T10:00:00Z',
      'doctor': {'id': 'd1', 'name': 'Rao', 'doctor_code': 'SUS-D-000001', 'specialization': 'Endocrinology'},
      'patient': {'id': 'p1', 'name': 'Asha', 'patient_code': 'SUS-P-0A1B2C'},
    });
    expect(r.status, AccessStatus.pending);
    expect(r.doctorSpecialization, 'Endocrinology');
  });

  group('validators', () {
    test('Patient ID format', () {
      expect(Validators.patientId('SUS-P-8A42F1'), isNull);
      expect(Validators.patientId('sus-p-8a42f1'), isNull);
      expect(Validators.patientId('SUS-D-8A42F1'), isNotNull);
      expect(Validators.patientId(''), isNotNull);
    });

    test('glucose ranges depend on unit', () {
      expect(Validators.glucose('110', 'mg/dL'), isNull);
      expect(Validators.glucose('700', 'mg/dL'), isNotNull);
      expect(Validators.glucose('6.1', 'mmol/L'), isNull);
      expect(Validators.glucose('110', 'mmol/L'), isNotNull);
    });

    test('password strength matches the backend rule', () {
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('lettersonly'), isNotNull);
      expect(Validators.password('Demo@12345'), isNull);
    });

    test('dates cannot be in the future', () {
      expect(Validators.notFuture(DateTime.now().add(const Duration(days: 1))), isNotNull);
      expect(Validators.notFuture(DateTime.now()), isNull);
      expect(Validators.notFuture(null), isNotNull);
    });
  });
}
