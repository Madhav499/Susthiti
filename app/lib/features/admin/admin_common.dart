import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/activity_timeline.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/admin.dart';
import '../../data/models/ai_summary.dart';
import '../../data/models/diabetes_risk.dart';
import '../../data/models/patient.dart';
import '../../data/models/system.dart';
import '../../data/models/tracking.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

// ---------- Providers (all read-only views of real records) ----------

final adminDoctorProvider = FutureProvider.autoDispose.family<AdminDoctorDetail, String>((ref, id) => ref.watch(adminRepositoryProvider).doctor(id));
final adminDoctorPatientsProvider = FutureProvider.autoDispose.family<List<DoctorPatientLink>, String>((ref, id) => ref.watch(adminRepositoryProvider).doctorPatients(id));
final adminDoctorReportsProvider = FutureProvider.autoDispose.family<DoctorReportActivity, String>((ref, id) => ref.watch(adminRepositoryProvider).doctorReports(id));
final adminDoctorPrescriptionsProvider =
    FutureProvider.autoDispose.family<({List<PrescriptionWithPatient> items, int total}), String>((ref, id) => ref.watch(adminRepositoryProvider).doctorPrescriptions(id));
final adminDoctorAppointmentsProvider = FutureProvider.autoDispose.family<DoctorAppointments, String>((ref, id) => ref.watch(adminRepositoryProvider).doctorAppointments(id));
final adminDoctorSideEffectsProvider = FutureProvider.autoDispose.family<DoctorSideEffects, String>((ref, id) => ref.watch(adminRepositoryProvider).doctorSideEffects(id));

typedef ActivityKey = ({String id, String scope});
final adminDoctorActivityProvider =
    FutureProvider.autoDispose.family<({List<LinkedAuditEntry> items, int total}), ActivityKey>((ref, k) => ref.watch(adminRepositoryProvider).doctorActivity(k.id, scope: k.scope));

final adminPatientProvider = FutureProvider.autoDispose.family<AdminPatientDetail, String>((ref, id) => ref.watch(adminRepositoryProvider).patient(id));
final adminPatientDevicesProvider = FutureProvider.autoDispose.family<List<WearableConnection>, String>((ref, id) => ref.watch(adminRepositoryProvider).patientDevices(id));
final adminPatientNotificationsProvider = FutureProvider.autoDispose.family<List<AppNotification>, String>((ref, id) => ref.watch(adminRepositoryProvider).patientNotifications(id));
final adminPatientAiSummariesProvider = FutureProvider.autoDispose.family<List<AISummary>, String>((ref, id) => ref.watch(adminRepositoryProvider).patientAiSummaries(id));
final adminPatientAuditProvider =
    FutureProvider.autoDispose.family<({List<LinkedAuditEntry> items, int total}), String>((ref, id) => ref.watch(adminRepositoryProvider).patientAudit(id));

// ---------- Routes ----------

String adminDoctorRoute(String doctorId, {String? tab}) => '/a/doctors/$doctorId${tab == null ? '' : '?tab=$tab'}';
String adminPatientRoute(String patientId, {String? tab}) => '/a/patients/$patientId${tab == null ? '' : '?tab=$tab'}';

/// Where an audit entry leads: the record itself when there is a record screen, otherwise the
/// patient or doctor profile.
String? routeForAudit(LinkedAuditEntry e) {
  final pid = e.patient?.id;
  final id = e.entityId;
  switch (e.entry.entityType) {
    case 'report':
      return pid == null || id == null ? null : '/r/$pid/reports/$id';
    case 'prescription':
      return pid == null || id == null ? null : '/r/$pid/prescriptions/$id';
    case 'visit':
      return pid == null || id == null ? null : '/r/$pid/visits/$id';
    case 'side_effect':
      return pid == null || id == null ? null : '/r/$pid/side-effects/$id';
    case 'assessment':
      return pid == null || id == null ? null : '/r/$pid/assessments/$id';
    case 'ai_summary':
      return pid == null ? null : adminPatientRoute(pid, tab: 'ai');
    case 'doctor':
      return e.doctor == null ? null : adminDoctorRoute(e.doctor!.id);
  }
  return pid == null ? null : adminPatientRoute(pid);
}

// ---------- Wording ----------

Map<String, String> _actionText(AppLocalizations l10n) => {
      'login': l10n.auditLogin,
      'logout': l10n.auditLogout,
      'patient_registered': l10n.auditPatientRegistered,
      'profile_updated': l10n.auditProfileUpdated,
      'profile_photo_updated': l10n.auditProfilePhotoUpdated,
      'patient_updated_by_admin': l10n.auditPatientUpdatedByAdmin,
      'patient_record_viewed': l10n.auditPatientRecordViewed,
      'patient_activated': l10n.auditPatientActivated,
      'patient_deactivated': l10n.auditPatientDeactivated,
      'doctor_created': l10n.auditDoctorCreated,
      'doctor_updated': l10n.auditDoctorUpdated,
      'doctor_activated': l10n.auditDoctorActivated,
      'doctor_deactivated': l10n.auditDoctorDeactivated,
      'access_requested': l10n.auditAccessRequested,
      'access_approved': l10n.auditAccessApproved,
      'access_rejected': l10n.auditAccessRejected,
      'access_revoked': l10n.auditAccessRevoked,
      'report_uploaded': l10n.auditReportUploaded,
      'report_file_accessed': l10n.auditReportFileAccessed,
      'diabetes_assessment_created': l10n.auditDiabetesAssessmentCreated,
      'prescription_created': l10n.auditPrescriptionCreated,
      'visit_recorded': l10n.auditVisitRecorded,
      'appointment_recommended': l10n.auditAppointmentRecommended,
      'side_effect_reported': l10n.auditSideEffectReported,
      'side_effect_responded': l10n.auditSideEffectResponded,
      'side_effect_under_review': l10n.auditSideEffectUnderReview,
      'side_effect_resolved': l10n.auditSideEffectResolved,
      'ai_summary_pdf_downloaded': l10n.auditAiSummaryPdfDownloaded,
      'ai_individual_report_generated': l10n.auditAiIndividualReportGenerated,
      'ai_all_reports_generated': l10n.auditAiAllReportsGenerated,
      'ai_patient_summary_generated': l10n.auditAiPatientSummaryGenerated,
      'ai_lifestyle_generated': l10n.auditAiLifestyleGenerated,
      'ai_assessment_interpretation_generated': l10n.auditAiAssessmentInterpretationGenerated,
      'wearable_connected': l10n.auditWearableConnected,
      'wearable_disconnected': l10n.auditWearableDisconnected,
      'password_changed': l10n.auditPasswordChanged,
      'password_reset_requested': l10n.auditPasswordResetRequested,
      'password_reset_completed': l10n.auditPasswordResetCompleted,
      'settings_updated': l10n.auditSettingsUpdated,
    };

String auditActionText(AppLocalizations l10n, String action) => _actionText(l10n)[action] ?? Fmt.titleCase(action);

String auditActor(AppLocalizations l10n, AuditEntry e) {
  final name = e.actorName ?? l10n.auditSystemActor;
  return switch (e.actorRole) {
    'doctor' => l10n.commonDrName(name),
    'admin' => l10n.auditAdminSuffix(name),
    _ => name,
  };
}

StatusTone auditTone(String action) {
  if (action.contains('deactivated') || action.contains('rejected') || action.contains('revoked')) return StatusTone.attention;
  if (action.startsWith('side_effect_reported')) return StatusTone.attention;
  if (action.contains('resolved') || action.contains('approved') || action.contains('activated')) return StatusTone.positive;
  if (action == 'patient_record_viewed' || action.startsWith('login') || action.startsWith('logout')) return StatusTone.inactive;
  return StatusTone.info;
}

IconData auditIcon(String? entityType) => switch (entityType) {
      'report' => Icons.description_outlined,
      'prescription' => Icons.medication_outlined,
      'visit' => Icons.event_note_outlined,
      'side_effect' => Icons.healing_outlined,
      'assessment' => Icons.fact_check_outlined,
      'ai_summary' => Icons.auto_awesome_outlined,
      'access_request' => Icons.verified_user_outlined,
      'appointment' => Icons.event_available_outlined,
      'wearable' => Icons.watch_outlined,
      _ => Icons.history,
    };

/// Timeline entry for an audit row. [showActor] is off when the timeline is already about the
/// actor (a doctor's own activity); [showPatient] names the patient the record belongs to.
TimelineEntry auditTimelineEntry(AppLocalizations l10n, LinkedAuditEntry e, {required void Function(String route) open, bool showActor = true, bool showPatient = true}) {
  final route = routeForAudit(e);
  final parts = [
    if (showActor) auditActor(l10n, e.entry),
    ?e.entry.entityLabel,
    if (showPatient && e.patient != null) l10n.auditPatientPrefix(e.patient!.name),
  ];
  return TimelineEntry(
    title: auditActionText(l10n, e.entry.action),
    subtitle: parts.join(' · '),
    at: e.entry.createdAt,
    icon: auditIcon(e.entry.entityType),
    tone: auditTone(e.entry.action),
    onTap: route == null ? null : () => open(route),
  );
}

String trendLabel(AppLocalizations l10n, String? trend) => switch (trend) {
      'higher' => l10n.trendHigher,
      'lower' => l10n.trendLower,
      'stable' => l10n.trendStable,
      _ => l10n.trendInsufficientData,
    };

IconData trendIcon(String? trend) => switch (trend) {
      'higher' => Icons.trending_up,
      'lower' => Icons.trending_down,
      'stable' => Icons.trending_flat,
      _ => Icons.remove,
    };

// ---------- Status labels ----------

Widget activePill(AppLocalizations l10n, bool active) => StatusPill(active ? l10n.commonActive : l10n.commonInactive, tone: active ? StatusTone.positive : StatusTone.inactive);

Widget accessPill(AppLocalizations l10n, AccessStatus status) => StatusPill(
      accessStatusLabel(l10n, status),
      tone: switch (status) {
        AccessStatus.approved => StatusTone.positive,
        AccessStatus.pending => StatusTone.attention,
        AccessStatus.rejected || AccessStatus.revoked => StatusTone.inactive,
      },
    );

/// The latest model-estimated future diabetes risk band (a screening estimate, never a diagnosis).
Widget diabetesStatusPill(AppLocalizations l10n, String? riskCategory) => switch (riskCategory) {
      'Low' || 'Moderate' || 'High' => StatusPill(RiskWording.categoryLabel(l10n, riskCategory!), tone: RiskWording.tone(riskCategory)),
      _ => StatusPill(l10n.diabetesNotAssessed, tone: StatusTone.inactive),
    };

/// Operational state from the same rules as the doctor dashboard (not a health score).
Widget progressPill(AppLocalizations l10n, PatientSnapshot s) {
  if (s.attention.isNotEmpty) {
    return Tooltip(message: s.attention.map((a) => a.reason).join('\n'), child: StatusPill(l10n.docNeedsAttention, tone: StatusTone.attention));
  }
  final recent = s.lastActivityAt != null && DateTime.now().difference(s.lastActivityAt!).inDays <= 30;
  return recent ? StatusPill(l10n.adminProgressNoOpenItems, tone: StatusTone.positive) : StatusPill(l10n.adminNoRecentActivity, tone: StatusTone.inactive);
}
