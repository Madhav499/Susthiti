import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/heart_risk.dart';
import '../../data/providers.dart';

/// The latest heart risk screening and whether the patient's health data has changed since.
/// Reading it never runs the model. Mirrors diabetes_providers.dart's riskStatusProvider.
final heartRiskStatusProvider = FutureProvider.autoDispose.family<HeartRiskStatus, String>(
  (ref, patientId) => ref.watch(heartRepositoryProvider).heartRiskStatus(patientId),
);

final heartRiskHistoryProvider = FutureProvider.autoDispose.family<List<HeartRiskAssessment>, String>(
  (ref, patientId) async => (await ref.watch(heartRepositoryProvider).heartRiskHistory(patientId)).items,
);

final heartRiskAssessmentProvider = FutureProvider.autoDispose.family<HeartRiskAssessment, String>(
  (ref, id) => ref.watch(heartRepositoryProvider).heartRiskAssessment(id),
);
