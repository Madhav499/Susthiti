import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

const _actionText = {
  'login': 'Signed in',
  'logout': 'Signed out',
  'patient_registered': 'Registered as a patient',
  'profile_updated': 'Updated their profile',
  'profile_photo_updated': 'Updated their profile photo',
  'patient_updated_by_admin': 'Patient details updated by admin',
  'patient_record_viewed': 'Patient record viewed by admin',
  'patient_activated': 'Patient account reactivated',
  'patient_deactivated': 'Patient account deactivated',
  'doctor_created': 'Doctor account created',
  'doctor_updated': 'Doctor details updated',
  'doctor_activated': 'Doctor account reactivated',
  'doctor_deactivated': 'Doctor account deactivated',
  'access_requested': 'Requested patient access',
  'access_approved': 'Patient access approved',
  'access_rejected': 'Patient access rejected',
  'access_revoked': 'Patient access revoked',
  'report_uploaded': 'Report uploaded',
  'report_file_accessed': 'Original report opened',
  'diabetes_assessment_created': 'Diabetes assessment completed',
  'prescription_created': 'Prescription created',
  'visit_recorded': 'Doctor visit recorded',
  'appointment_recommended': 'Appointment recommended',
  'side_effect_reported': 'Side effect reported',
  'side_effect_responded': 'Responded to a side-effect report',
  'side_effect_under_review': 'Side-effect report marked under review',
  'side_effect_resolved': 'Side-effect report resolved',
  'ai_summary_pdf_downloaded': 'AI summary PDF downloaded',
  'ai_individual_report_generated': 'AI report summary generated',
  'ai_all_reports_generated': 'AI all-reports summary generated',
  'ai_patient_summary_generated': 'AI patient summary generated',
  'ai_lifestyle_generated': 'AI lifestyle insight generated',
  'ai_assessment_interpretation_generated': 'AI assessment interpretation generated',
  'wearable_connected': 'Wearable device connected',
  'wearable_disconnected': 'Wearable device disconnected',
  'password_changed': 'Password changed',
  'password_reset_requested': 'Password reset requested',
  'password_reset_completed': 'Password reset completed',
  'settings_updated': 'System settings updated',
};

String auditActionText(String action) => _actionText[action] ?? Fmt.titleCase(action);

String auditActor(AuditEntry e) {
  final name = e.actorName ?? 'System';
  return switch (e.actorRole) {
    'doctor' => 'Dr. $name',
    'admin' => '$name (Admin)',
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
TimelineEntry auditTimelineEntry(LinkedAuditEntry e, {required void Function(String route) open, bool showActor = true, bool showPatient = true}) {
  final route = routeForAudit(e);
  final parts = [
    if (showActor) auditActor(e.entry),
    ?e.entry.entityLabel,
    if (showPatient && e.patient != null) 'Patient: ${e.patient!.name}',
  ];
  return TimelineEntry(
    title: auditActionText(e.entry.action),
    subtitle: parts.join(' · '),
    at: e.entry.createdAt,
    icon: auditIcon(e.entry.entityType),
    tone: auditTone(e.entry.action),
    onTap: route == null ? null : () => open(route),
  );
}

String trendLabel(String? trend) => switch (trend) {
      'higher' => 'Higher than previous weeks',
      'lower' => 'Lower than previous weeks',
      'stable' => 'Similar to previous weeks',
      _ => 'Not enough readings to compare',
    };

IconData trendIcon(String? trend) => switch (trend) {
      'higher' => Icons.trending_up,
      'lower' => Icons.trending_down,
      'stable' => Icons.trending_flat,
      _ => Icons.remove,
    };

// ---------- Status labels ----------

Widget activePill(bool active) => StatusPill(active ? 'Active' : 'Inactive', tone: active ? StatusTone.positive : StatusTone.inactive);

Widget accessPill(AccessStatus status) => StatusPill(
      status == AccessStatus.approved ? 'Approved' : status.label,
      tone: switch (status) {
        AccessStatus.approved => StatusTone.positive,
        AccessStatus.pending => StatusTone.attention,
        AccessStatus.rejected || AccessStatus.revoked => StatusTone.inactive,
      },
    );

/// The latest model-estimated future diabetes risk band (a screening estimate, never a diagnosis).
Widget diabetesStatusPill(String? riskCategory) => switch (riskCategory) {
      'Low' || 'Moderate' || 'High' => StatusPill(RiskWording.categoryLabel(riskCategory!), tone: RiskWording.tone(riskCategory)),
      _ => const StatusPill('Not assessed', tone: StatusTone.inactive),
    };

/// Operational state from the same rules as the doctor dashboard (not a health score).
Widget progressPill(PatientSnapshot s) {
  if (s.attention.isNotEmpty) {
    return Tooltip(message: s.attention.map((a) => a.reason).join('\n'), child: const StatusPill('Needs attention', tone: StatusTone.attention));
  }
  final recent = s.lastActivityAt != null && DateTime.now().difference(s.lastActivityAt!).inDays <= 30;
  return recent ? const StatusPill('No open items', tone: StatusTone.positive) : const StatusPill('No recent activity', tone: StatusTone.inactive);
}
