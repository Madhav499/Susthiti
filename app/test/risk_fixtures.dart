/// JSON in the exact shape the SUSTHITI backend returns for future diabetes risk (API v4).
library;

Map<String, dynamic> dataUsedJson({bool report = true, bool wearable = true}) => {
      'groups': [
        {
          'key': 'profile',
          'label': 'Profile',
          'items': [
            {'feature': 'age', 'label': 'Age', 'value': '36 years', 'source': 'patient_profile', 'detail': 'Calculated today from your date of birth'},
            {'feature': 'weight_kg', 'label': 'Weight', 'value': '70 kg', 'source': 'health_profile', 'detail': 'Health profile, entered by you on 20 Sep 2026'},
          ],
        },
        if (report)
          {
            'key': 'report',
            'label': 'Medical reports',
            'items': [
              {'feature': 'hba1c', 'label': 'HbA1c', 'value': '6.1 %', 'source': 'medical_report', 'report_code': 'RP-000012',
               'detail': 'HbA1c from report RP-000012 (12 Sep 2026), entered by you'},
            ],
          },
        if (wearable)
          {
            'key': 'wearable',
            'label': 'Smartwatch and health apps',
            'items': [
              {'feature': 'sleep_hours', 'label': 'Sleep', 'value': '7 h a night', 'source': 'wearable', 'detail': 'Average of 9 nights recorded 15 Sep – 28 Sep 2026'},
            ],
          },
      ],
      'missing': [
        {'feature': 'hypertension', 'label': 'High blood pressure', 'reason': 'Not answered yet', 'group': 'medical_history', 'group_label': 'Medical history', 'how_to_add': 'health_profile'},
        if (!report)
          {'feature': 'hba1c', 'label': 'HbA1c', 'reason': 'Not recorded from any uploaded report', 'group': 'report', 'group_label': 'Medical reports', 'how_to_add': 'report_values'},
      ],
      'available_count': report ? 5 : 4,
      'total_count': 29,
    };

Map<String, dynamic> assessmentJson({String id = 'dr1', bool report = true, String category = 'Moderate', double risk = 43.21}) => {
      'id': id,
      'code': 'DR-000001',
      'patient_id': 'pat1',
      'created_at': '2026-09-28T10:42:00Z',
      'risk_percent': risk,
      'risk_category': category,
      'risk_thresholds': {'low': '0-40%', 'moderate': '>40-65%', 'high': '>65%'},
      'prediction': risk >= 50 ? 1 : 0,
      'prediction_label': risk >= 50 ? 'Higher-risk pattern' : 'Lower-risk pattern',
      'prediction_threshold': '50% for binary model target',
      'prediction_basis': report ? 'symptoms_and_available_health_report' : 'symptoms_and_risk_factors_only',
      'report_available': report,
      'report_fields_present': report ? ['hba1c', 'fasting_glucose'] : <String>[],
      'report_fields_label': report ? 'HbA1c and fasting glucose' : null,
      'bmi': 24.5,
      'model_version': '4.0.0',
      'warning': report
          ? 'This is a machine-learning future-risk estimate, not a medical diagnosis.'
          : '100% symptoms/risk-factor-based prediction because no previous medical report data was provided. This result is not fully trusted and is not a medical diagnosis.',
      'performed_by_role': 'patient',
      'data_used': dataUsedJson(report: report),
      'input_features': {'age': 36, 'sex': 'Male', if (report) 'hba1c': 6.1},
    };

Map<String, dynamic> statusJson({Map<String, dynamic>? latest, bool stale = false, List<String> reasons = const [], int history = 0, int earlier = 0}) => {
      'latest': latest,
      'stale': stale,
      'stale_reasons': reasons,
      'current_data': dataUsedJson(report: latest?['report_available'] as bool? ?? false),
      'report_fields_available': <String>[],
      'history_total': history,
      'earlier_model_total': earlier,
    };
