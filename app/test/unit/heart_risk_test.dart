import 'package:flutter_test/flutter_test.dart';
import 'package:susthiti/data/models/heart_risk.dart';

Map<String, dynamic> _assessmentJson({bool report = true}) => {
      'id': 'a1', 'code': 'HR-000001', 'created_at': '2026-10-04T09:00:00Z',
      'probability_percent': 37.38, 'risk_level': 'low', 'prediction': 1,
      'prediction_label': 'Heart disease risk detected', 'decision_threshold': 0.3275,
      'report_available': report, 'report_fields_present': report ? ['troponin'] : [],
      'model_version': 'susthiti-heart-v3', 'warnings': [],
      'data_used': {'groups': [], 'missing': [], 'available_count': 2, 'total_count': 58},
    };

void main() {
  test('an assessment keeps the API\'s own numbers and wording, never a diagnosis', () {
    final a = HeartRiskAssessment.fromJson(_assessmentJson());
    expect(a.probabilityPercent, 37.38);
    expect(a.percentLabel, '37.4%');
    expect(a.riskLevel, 'low');
    expect(a.modelVersion, 'susthiti-heart-v3');
    expect(a.signalLabel, isNot(contains('diagnos')));
    expect(a.signalLabel, isNot(contains('has heart disease')));
    expect(a.reportAvailable, isTrue);
    expect(a.reportFieldsPresent, ['troponin']);
  });

  test('without report values the basis says so, and never implies a normal result', () {
    final a = HeartRiskAssessment.fromJson(_assessmentJson(report: false));
    expect(a.basisText, HeartWording.noReportBasis);
    expect(a.basisText.toLowerCase(), isNot(contains('normal')));
  });

  test('incomplete responses are rejected, not shown with made-up values', () {
    expect(() => HeartRiskAssessment.fromJson({..._assessmentJson(), 'probability_percent': null}), throwsFormatException);
    expect(HeartRiskBrief.maybe({'id': 'x', 'risk_level': 'low'}), isNull);
  });

  test('risk signal wording never claims diagnostic certainty', () {
    for (final level in ['low', 'moderate', 'high']) {
      final label = HeartWording.signalLabel(level);
      expect(label.toLowerCase(), isNot(contains('you have')));
      expect(label.toLowerCase(), contains('signal'));
    }
    expect(HeartWording.safety.toLowerCase(), contains('not a medical diagnosis'));
    expect(HeartWording.safety.toLowerCase(), contains('synthetic'));
  });

  test('risk tones differ by band, same pattern as diabetes', () {
    expect(HeartWording.tone('high'), isNot(HeartWording.tone('low')));
  });
}
