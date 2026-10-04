import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/diabetes_risk.dart';
import '../../data/models/heart_risk.dart';
import '../../data/providers.dart';
import '../diabetes/diabetes_providers.dart';
import '../heart/heart_providers.dart';
import 'patient_dashboard_screen.dart';
import 'timeline_screen.dart';

/// A patient's records changed (a report, report values, the health profile, an assessment...).
/// Every screen that shows that patient re-reads, so the dashboard, the Diabetes tab, the timeline
/// and the doctor's view always agree. Screens kept alive in the background (the dashboard tab)
/// refresh too.
void patientDataChanged(WidgetRef ref, String patientId) {
  ref.invalidate(patientDashboardProvider(patientId));
  ref.invalidate(riskStatusProvider(patientId));
  ref.invalidate(riskHistoryProvider(patientId));
  ref.invalidate(heartRiskStatusProvider(patientId));
  ref.invalidate(heartRiskHistoryProvider(patientId));
  ref.invalidate(healthProfileProvider(patientId));
  ref.invalidate(timelineProvider);
}

/// Health data changed (profile answers, report values): screens re-read it so an out-of-date
/// estimate is flagged. The model itself only runs when an assessment is requested.
void healthDataChanged(WidgetRef ref, String patientId) => patientDataChanged(ref, patientId);

/// Asks the backend to assess again, and shows the result everywhere the risk appears.
/// [force]: the patient reviewed every answer and asked for a new assessment, so a new dated
/// record is made even if nothing changed. Otherwise the backend only calls the model when
/// relevant data changed.
Future<RiskRefresh> refreshDiabetesRisk(WidgetRef ref, String patientId, {bool force = false}) async {
  final result = await ref.read(diabetesRepositoryProvider).refreshRisk(patientId, force: force);
  patientDataChanged(ref, patientId);
  return result;
}

/// Same pattern for the heart risk screening (a separate, synthetic-data model; see
/// HeartWording). [force]: the patient reviewed every answer and asked for a new assessment
/// without changing anything reusable, so a new dated record is made even if nothing changed.
Future<HeartRiskRefresh> refreshHeartRisk(WidgetRef ref, String patientId, {bool force = false}) async {
  final result = await ref.read(heartRepositoryProvider).refreshHeartRisk(patientId, force: force);
  patientDataChanged(ref, patientId);
  return result;
}

/// The heart assessment form's submission: always creates a new, fully-answered assessment.
Future<HeartRiskRefresh> submitHeartAssessment(WidgetRef ref, String patientId, Map<String, Object?> fields) async {
  final result = await ref.read(heartRepositoryProvider).submitHeartAssessment(patientId, fields);
  patientDataChanged(ref, patientId);
  return result;
}
