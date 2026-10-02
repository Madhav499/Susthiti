import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../data/models/diabetes.dart';
import '../../data/models/diabetes_risk.dart';
import '../../data/models/health_data.dart';
import '../../data/providers.dart';
import '../authentication/auth_controller.dart';

/// The latest risk estimate and whether the patient's health data has changed since. Reading it
/// never runs the model. When SUSTHITI can't be reached, the signed-in patient sees their own
/// last status from this device, marked offline.
final riskStatusProvider = FutureProvider.autoDispose.family<RiskStatus, String>((ref, patientId) async {
  final repo = ref.watch(diabetesRepositoryProvider);
  final cache = ref.watch(riskCacheProvider);
  final ownRecord = ref.watch(currentUserProvider)?.patientId == patientId;
  try {
    final status = await repo.riskStatus(patientId);
    if (ownRecord) await cache.save(patientId, status.raw);
    return status;
  } on Failure catch (failure) {
    if (ownRecord && (failure is NetworkFailure || failure is TimeoutFailure)) {
      final cached = await cache.load(patientId);
      if (cached != null) return RiskStatus.fromJson(cached, offline: true);
    }
    rethrow;
  }
});

final riskHistoryProvider = FutureProvider.autoDispose.family<List<RiskAssessment>, String>(
  (ref, patientId) async => (await ref.watch(diabetesRepositoryProvider).riskHistory(patientId)).items,
);

final riskAssessmentProvider = FutureProvider.autoDispose.family<RiskAssessment, String>((ref, id) => ref.watch(diabetesRepositoryProvider).riskAssessment(id));

/// Assessments from the earlier symptom-questionnaire model (read-only history).
final assessmentHistoryProvider = FutureProvider.autoDispose.family<List<DiabetesAssessment>, String>(
  (ref, patientId) async => (await ref.watch(diabetesRepositoryProvider).earlierHistory(patientId)).items,
);

final assessmentProvider = FutureProvider.autoDispose.family<DiabetesAssessment, String>((ref, id) => ref.watch(diabetesRepositoryProvider).earlierAssessment(id));

final healthProfileProvider = FutureProvider.autoDispose.family<HealthProfile, String>((ref, patientId) => ref.watch(patientRepositoryProvider).healthProfile(patientId));

final reportValuesProvider = FutureProvider.autoDispose.family<ReportValues, String>((ref, reportId) => ref.watch(reportRepositoryProvider).values(reportId));
