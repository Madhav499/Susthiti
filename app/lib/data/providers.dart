import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/api_client.dart';
import '../core/services/push_notification_service.dart';
import '../core/services/token_storage.dart';
import 'datasources/health_platform.dart';
import 'repositories/auth_repository.dart';
import 'repositories/diabetes_repository.dart';
import 'repositories/food_repository.dart';
import 'repositories/glucose_repository.dart';
import 'repositories/lifestyle_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/patient_repository.dart';
import 'repositories/prescription_repository.dart';
import 'repositories/report_repository.dart';
import 'repositories/side_effect_repository.dart';
import 'repositories/visit_repository.dart';
import 'services/ai_services.dart';
import 'services/file_services.dart';
import 'services/risk_cache.dart';
import 'services/wearable_service.dart';

/// Dependency wiring. Tests override these providers with fakes.
final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(tokenStorage: ref.watch(tokenStorageProvider)));

final authRepositoryProvider = Provider<AuthRepository>((ref) => ApiAuthRepository(ref.watch(apiClientProvider)));
final patientRepositoryProvider = Provider<PatientRepository>((ref) => ApiPatientRepository(ref.watch(apiClientProvider)));
final doctorRepositoryProvider = Provider<DoctorRepository>((ref) => ApiDoctorRepository(ref.watch(apiClientProvider)));
final adminRepositoryProvider = Provider<AdminRepository>((ref) => ApiAdminRepository(ref.watch(apiClientProvider)));
final reportRepositoryProvider = Provider<ReportRepository>((ref) => ApiReportRepository(ref.watch(apiClientProvider)));
final diabetesRepositoryProvider = Provider<DiabetesRepository>((ref) => ApiDiabetesRepository(ref.watch(apiClientProvider)));
final glucoseRepositoryProvider = Provider<GlucoseRepository>((ref) => ApiGlucoseRepository(ref.watch(apiClientProvider)));
final foodRepositoryProvider = Provider<FoodRepository>((ref) => ApiFoodRepository(ref.watch(apiClientProvider)));
final lifestyleRepositoryProvider = Provider<LifestyleRepository>((ref) => ApiLifestyleRepository(ref.watch(apiClientProvider)));
final wearableRepositoryProvider = Provider<WearableRepository>((ref) => ApiWearableRepository(ref.watch(apiClientProvider)));
final prescriptionRepositoryProvider = Provider<PrescriptionRepository>((ref) => ApiPrescriptionRepository(ref.watch(apiClientProvider)));
final sideEffectRepositoryProvider = Provider<SideEffectRepository>((ref) => ApiSideEffectRepository(ref.watch(apiClientProvider)));
final visitRepositoryProvider = Provider<VisitRepository>((ref) => ApiVisitRepository(ref.watch(apiClientProvider)));
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => ApiNotificationRepository(ref.watch(apiClientProvider)));
/// Lives for the whole app (wired up once in SusthitiApp); see push_notification_service.dart.
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) => PushNotificationService(ref.watch(notificationRepositoryProvider)));

final aiRepositoryProvider = Provider<AIRepository>((ref) => AIRepository(ref.watch(apiClientProvider)));
/// The signed-in patient's own last diabetes risk status, for showing it offline.
final riskCacheProvider = Provider<RiskCache>((ref) => SecureRiskCache());
final fileStorageServiceProvider = Provider<FileStorageService>((ref) => FileStorageService(ref.watch(reportRepositoryProvider)));
final pdfServiceProvider = Provider<PDFService>((ref) => PDFService(ref.watch(apiClientProvider)));
/// The phone's health platform (Health Connect / Apple Health), or unsupported on web and desktop.
/// Providers are lazy: nothing touches the health plugin until the lifestyle or devices screens need it.
final healthPlatformProvider = Provider<HealthPlatform>((ref) => createHealthPlatform());
final wearableServiceProvider = Provider<WearableService>((ref) => WearableService(ref.watch(wearableRepositoryProvider), ref.watch(healthPlatformProvider)));
