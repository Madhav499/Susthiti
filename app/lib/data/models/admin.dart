import '../../core/utils/formatters.dart';
import 'care.dart';
import 'diabetes_risk.dart';
import 'patient.dart';
import 'report.dart';
import 'system.dart';

typedef _Json = Map<String, dynamic>;

/// Minimal patient reference used to link any record back to its patient.
class PatientRef {
  const PatientRef({required this.id, required this.name, required this.patientCode, this.isActive = true});
  final String id;
  final String name;
  final String patientCode;
  final bool isActive;

  static PatientRef? maybe(Object? j) => j is _Json ? PatientRef.fromJson(j) : null;

  factory PatientRef.fromJson(Map<String, dynamic> j) => PatientRef(
        id: j['id'] as String,
        name: j['name'] as String,
        patientCode: j['patient_code'] as String,
        isActive: j['is_active'] as bool? ?? true,
      );
}

class DoctorRef {
  const DoctorRef({required this.id, required this.name, required this.doctorCode});
  final String id;
  final String name;
  final String doctorCode;

  static DoctorRef? maybe(Object? j) => j is _Json ? DoctorRef(id: j['id'] as String, name: j['name'] as String, doctorCode: j['doctor_code'] as String) : null;
}

class AttentionReason {
  const AttentionReason({required this.reason, required this.entityType, required this.entityId, this.at});
  final String reason;
  final String entityType;
  final String entityId;
  final DateTime? at;

  factory AttentionReason.fromJson(Map<String, dynamic> j) => AttentionReason(
        reason: j['reason'] as String,
        entityType: j['entity_type'] as String,
        entityId: j['entity_id'] as String,
        at: parseDate(j['at']),
      );
}

/// A patient's current state, derived from stored records only (no health score).
class PatientSnapshot {
  const PatientSnapshot({
    required this.ref,
    this.age,
    this.gender,
    this.isDemo = false,
    this.latestAssessment,
    this.latestGlucose,
    this.latestGlucoseAt,
    this.glucoseAverage7d,
    this.glucoseTrend,
    this.lastActivityAt,
    this.nextFollowUp,
    this.openSideEffects = 0,
    this.attention = const [],
  });

  final PatientRef ref;
  final int? age;
  final String? gender;
  final bool isDemo;
  final RiskBrief? latestAssessment;
  final double? latestGlucose;
  final DateTime? latestGlucoseAt;
  final double? glucoseAverage7d;

  /// higher | lower | stable, versus the previous weeks (null when there is too little data).
  final String? glucoseTrend;
  final DateTime? lastActivityAt;
  final DateTime? nextFollowUp;
  final int openSideEffects;
  final List<AttentionReason> attention;

  factory PatientSnapshot.fromJson(Map<String, dynamic> j) {
    final glucose = j['latest_glucose'] as _Json?;
    return PatientSnapshot(
      ref: PatientRef.fromJson(j),
      age: j['age'] as int?,
      gender: j['gender'] as String?,
      isDemo: j['is_demo'] as bool? ?? false,
      latestAssessment: RiskBrief.maybe(j['latest_assessment']),
      latestGlucose: (glucose?['value'] as num?)?.toDouble(),
      latestGlucoseAt: parseDate(glucose?['measured_at']),
      glucoseAverage7d: (j['glucose_average_7d'] as num?)?.toDouble(),
      glucoseTrend: j['glucose_trend'] as String?,
      lastActivityAt: parseDate(j['last_activity_at']),
      nextFollowUp: parseDate(j['next_follow_up']),
      openSideEffects: j['open_side_effects'] as int? ?? 0,
      attention: [for (final a in (j['attention'] as List? ?? const [])) AttentionReason.fromJson(a as _Json)],
    );
  }
}

/// Factual counts across a doctor's current patients.
class ProgressSummary {
  const ProgressSummary(this.values);
  final Map<String, int> values;
  int operator [](String key) => values[key] ?? 0;

  factory ProgressSummary.fromJson(Map<String, dynamic>? j) => ProgressSummary({for (final e in (j ?? const {}).entries) e.key: (e.value as num).toInt()});
}

class AdminDoctorDetail {
  const AdminDoctorDetail({required this.profile, required this.stats, required this.progress, this.lastLoginAt, this.lastActivityAt});
  final DoctorProfile profile;
  final Map<String, int> stats;
  final ProgressSummary progress;
  final DateTime? lastLoginAt;
  final DateTime? lastActivityAt;

  int stat(String key) => stats[key] ?? 0;

  factory AdminDoctorDetail.fromJson(Map<String, dynamic> j) => AdminDoctorDetail(
        profile: DoctorProfile.fromJson(j),
        stats: {for (final e in (j['stats'] as _Json).entries) e.key: (e.value as num).toInt()},
        progress: ProgressSummary.fromJson(j['progress'] as _Json?),
        lastLoginAt: parseDate(j['last_login_at']),
        lastActivityAt: parseDate(j['last_activity_at']),
      );
}

/// One doctor-patient relationship. Approved relationships carry a full snapshot.
class DoctorPatientLink {
  const DoctorPatientLink({required this.access, required this.snapshot});
  final AccessRequest access;
  final PatientSnapshot snapshot;

  factory DoctorPatientLink.fromJson(Map<String, dynamic> j) => DoctorPatientLink(access: AccessRequest.fromJson(j), snapshot: PatientSnapshot.fromJson(j['patient'] as _Json));
}

class ReportWithPatient {
  const ReportWithPatient({required this.report, this.patient, this.openedAt});
  final MedicalReport report;
  final PatientRef? patient;
  final DateTime? openedAt;

  factory ReportWithPatient.fromJson(Map<String, dynamic> j) => ReportWithPatient(report: MedicalReport.fromJson(j), patient: PatientRef.maybe(j['patient']), openedAt: parseDate(j['opened_at']));
}

class SummaryActivity {
  const SummaryActivity({required this.id, required this.kind, required this.generatedAt, this.subjectId, this.patient});
  final String id;
  final String kind;
  final String? subjectId;
  final DateTime generatedAt;
  final PatientRef? patient;

  factory SummaryActivity.fromJson(Map<String, dynamic> j) => SummaryActivity(
        id: j['id'] as String,
        kind: j['kind'] as String,
        subjectId: j['subject_id'] as String?,
        generatedAt: parseDate(j['generated_at'])!,
        patient: PatientRef.maybe(j['patient']),
      );
}

class DoctorReportActivity {
  const DoctorReportActivity({required this.uploaded, required this.opened, required this.summaries});
  final List<ReportWithPatient> uploaded;
  final List<ReportWithPatient> opened;
  final List<SummaryActivity> summaries;

  factory DoctorReportActivity.fromJson(Map<String, dynamic> j) => DoctorReportActivity(
        uploaded: [for (final r in j['uploaded'] as List) ReportWithPatient.fromJson(r as _Json)],
        opened: [for (final r in j['opened'] as List) ReportWithPatient.fromJson(r as _Json)],
        summaries: [for (final s in j['summaries'] as List) SummaryActivity.fromJson(s as _Json)],
      );
}

class PrescriptionWithPatient {
  const PrescriptionWithPatient({required this.prescription, this.patient});
  final Prescription prescription;
  final PatientRef? patient;

  factory PrescriptionWithPatient.fromJson(Map<String, dynamic> j) => PrescriptionWithPatient(prescription: Prescription.fromJson(j), patient: PatientRef.maybe(j['patient']));
}

class FollowUp {
  const FollowUp({required this.date, required this.source, required this.recordId, required this.code, this.reason, this.patient});
  final DateTime date;

  /// visit | prescription
  final String source;
  final String recordId;
  final String code;
  final String? reason;
  final PatientRef? patient;

  factory FollowUp.fromJson(Map<String, dynamic> j) => FollowUp(
        date: parseDate(j['date'])!,
        source: j['source'] as String,
        recordId: j['record_id'] as String,
        code: j['code'] as String,
        reason: j['reason'] as String?,
        patient: PatientRef.maybe(j['patient']),
      );
}

class VisitBrief {
  const VisitBrief({required this.id, required this.code, required this.visitDate, required this.reason, this.followUpDate, this.patient});
  final String id;
  final String code;
  final DateTime visitDate;
  final String reason;
  final DateTime? followUpDate;
  final PatientRef? patient;

  factory VisitBrief.fromJson(Map<String, dynamic> j) => VisitBrief(
        id: j['id'] as String,
        code: j['visit_code'] as String,
        visitDate: parseDate(j['visit_date'])!,
        reason: j['reason'] as String,
        followUpDate: parseDate(j['follow_up_date']),
        patient: PatientRef.maybe(j['patient']),
      );
}

class AppointmentWithPatient {
  const AppointmentWithPatient({required this.appointment, this.patient});
  final AppointmentRecommendation appointment;
  final PatientRef? patient;
}

class DoctorAppointments {
  const DoctorAppointments({required this.recommendations, required this.followUps, required this.visits});
  final List<AppointmentWithPatient> recommendations;
  final List<FollowUp> followUps;
  final List<VisitBrief> visits;

  factory DoctorAppointments.fromJson(Map<String, dynamic> j) => DoctorAppointments(
        recommendations: [
          for (final r in j['recommendations'] as List) AppointmentWithPatient(appointment: AppointmentRecommendation.fromJson(r as _Json), patient: PatientRef.maybe(r['patient'])),
        ],
        followUps: [for (final f in j['follow_ups'] as List) FollowUp.fromJson(f as _Json)],
        visits: [for (final v in j['visits'] as List) VisitBrief.fromJson(v as _Json)],
      );
}

class SideEffectWithPatient {
  const SideEffectWithPatient({required this.sideEffect, this.patient, this.doctorResponse, this.doctorRespondedAt});
  final SideEffect sideEffect;
  final PatientRef? patient;
  final DoctorResponse? doctorResponse;
  final DateTime? doctorRespondedAt;

  factory SideEffectWithPatient.fromJson(Map<String, dynamic> j) {
    final response = j['doctor_response'] as _Json?;
    return SideEffectWithPatient(
      sideEffect: SideEffect.fromJson(j),
      patient: PatientRef.maybe(j['patient']),
      doctorResponse: DoctorResponse.parse(response?['response_type'] as String?),
      doctorRespondedAt: parseDate(response?['created_at']),
    );
  }
}

class DoctorSideEffects {
  const DoctorSideEffects({required this.items, required this.pending, required this.resolved});
  final List<SideEffectWithPatient> items;
  final int pending;
  final int resolved;

  factory DoctorSideEffects.fromJson(Map<String, dynamic> j) => DoctorSideEffects(
        items: [for (final s in j['items'] as List) SideEffectWithPatient.fromJson(s as _Json)],
        pending: j['pending'] as int? ?? 0,
        resolved: j['resolved'] as int? ?? 0,
      );
}

/// An audit entry resolved to the patient (and doctor) it concerns, so it can be opened.
class LinkedAuditEntry {
  const LinkedAuditEntry({required this.entry, this.entityId, this.patient, this.doctor});
  final AuditEntry entry;
  final String? entityId;
  final PatientRef? patient;
  final DoctorRef? doctor;

  factory LinkedAuditEntry.fromJson(Map<String, dynamic> j) => LinkedAuditEntry(
        entry: AuditEntry.fromJson(j),
        entityId: j['entity_id'] as String?,
        patient: PatientRef.maybe(j['patient']),
        doctor: DoctorRef.maybe(j['doctor']),
      );
}

class AdminPatientDetail {
  const AdminPatientDetail({
    required this.profile,
    required this.doctors,
    required this.counts,
    this.isActive = true,
    this.lastLoginAt,
    this.lastActivityAt,
    this.latestAssessment,
    this.latestGlucose,
    this.latestGlucoseAt,
    this.glucoseAverage7d,
    this.glucoseTrend,
    this.nextFollowUp,
    this.openSideEffects = 0,
    this.attention = const [],
  });

  final PatientProfile profile;
  final List<AccessRequest> doctors;
  final Map<String, int> counts;
  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime? lastActivityAt;
  final RiskBrief? latestAssessment;
  final double? latestGlucose;
  final DateTime? latestGlucoseAt;
  final double? glucoseAverage7d;
  final String? glucoseTrend;
  final DateTime? nextFollowUp;
  final int openSideEffects;
  final List<AttentionReason> attention;

  int count(String key) => counts[key] ?? 0;
  List<AccessRequest> get currentDoctors => [for (final d in doctors) if (d.status == AccessStatus.approved) d];

  factory AdminPatientDetail.fromJson(Map<String, dynamic> j) {
    final glucose = j['latest_glucose'] as _Json?;
    return AdminPatientDetail(
      profile: PatientProfile.fromJson(j),
      doctors: [for (final d in j['doctors'] as List) AccessRequest.fromJson(d as _Json)],
      counts: {for (final e in (j['counts'] as _Json).entries) e.key: (e.value as num).toInt()},
      isActive: j['is_active'] as bool? ?? true,
      lastLoginAt: parseDate(j['last_login_at']),
      lastActivityAt: parseDate(j['last_activity_at']),
      latestAssessment: RiskBrief.maybe(j['latest_assessment']),
      latestGlucose: (glucose?['value'] as num?)?.toDouble(),
      latestGlucoseAt: parseDate(glucose?['measured_at']),
      glucoseAverage7d: (j['glucose_average_7d'] as num?)?.toDouble(),
      glucoseTrend: j['glucose_trend'] as String?,
      nextFollowUp: parseDate(j['next_follow_up']),
      openSideEffects: j['open_side_effects'] as int? ?? 0,
      attention: [for (final a in (j['attention'] as List? ?? const [])) AttentionReason.fromJson(a as _Json)],
    );
  }
}
