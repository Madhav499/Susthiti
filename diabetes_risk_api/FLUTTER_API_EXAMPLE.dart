import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> predictSusthiti() async {
  const apiUrl = 'http://10.0.2.2:8000/predict';

  final response = await http.post(
    Uri.parse(apiUrl),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'data': {
        'age': 48,
        'sex': 'Male',
        'height_cm': 175.3,
        'weight_kg': 82,
        // bmi can be omitted; the API calculates it.
        'family_history_diabetes': 0,
        'previous_prediabetes': 0,
        'physical_activity_level': 'Moderate',
        'diet_quality': 'Average',
        'hypertension': 0,
        'high_cholesterol': 0,
        'polyuria': 0,
        'polydipsia': 0,
        'unexplained_weight_loss': 1,
        'polyphagia': 0,

        // No report: omit these fields or send null.
        'hba1c': null,
        'fasting_glucose': null,
        'random_glucose': null,
        'previous_ogtt_2h': null,
        'previous_health_report_status': null,
      }
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('SUSTHITI API error ${response.statusCode}: ${response.body}');
  }

  return jsonDecode(response.body) as Map<String, dynamic>;
}
