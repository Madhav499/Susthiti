import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

enum Severity {
  mild,
  moderate,
  severe,
  emergency;

  String get label => Fmt.titleCase(name);
  StatusTone get tone => switch (this) {
        mild => StatusTone.info,
        moderate => StatusTone.attention,
        severe || emergency => StatusTone.critical,
      };
}

enum SideEffectStatus {
  newReport('new', 'New'),
  underReview('under_review', 'Under Review'),
  responded('responded', 'Responded'),
  appointmentRecommended('appointment_recommended', 'Appointment Recommended'),
  resolved('resolved', 'Resolved');

  const SideEffectStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;
  static SideEffectStatus parse(String v) => values.firstWhere((s) => s.apiValue == v);

  StatusTone get tone => switch (this) {
        newReport => StatusTone.attention,
        underReview => StatusTone.info,
        responded || appointmentRecommended => StatusTone.info,
        resolved => StatusTone.positive,
      };
}

/// Doctor responses. The AI never chooses these; the doctor does.
enum DoctorResponse {
  noImmediateAction('no_immediate_action', 'No immediate action'),
  monitor('monitor', 'Monitor'),
  contactDoctor('contact_doctor', 'Contact doctor'),
  appointmentRecommended('appointment_recommended', 'Appointment recommended'),
  urgentMedicalAttention('urgent_medical_attention', 'Urgent medical attention');

  const DoctorResponse(this.apiValue, this.label);
  final String apiValue;
  final String label;
  static DoctorResponse? parse(String? v) => v == null ? null : values.firstWhere((r) => r.apiValue == v);
}

class SideEffectEvent {
  const SideEffectEvent({required this.id, required this.status, required this.actorName, required this.actorRole, required this.createdAt, this.response, this.message});
  final String id;
  final SideEffectStatus status;
  final DoctorResponse? response;
  final String? message;
  final String actorName;
  final String actorRole;
  final DateTime createdAt;

  factory SideEffectEvent.fromJson(Map<String, dynamic> j) => SideEffectEvent(
        id: j['id'] as String,
        status: SideEffectStatus.parse(j['status'] as String),
        response: DoctorResponse.parse(j['response_type'] as String?),
        message: j['message'] as String?,
        actorName: j['actor_name'] as String,
        actorRole: j['actor_role'] as String,
        createdAt: parseDate(j['created_at'])!,
      );
}

class SideEffect {
  const SideEffect({
    required this.id,
    required this.code,
    required this.patientId,
    required this.description,
    required this.severity,
    required this.occurredAt,
    required this.status,
    required this.createdAt,
    this.relatedMedication,
    this.notes,
    this.priorityFlag = false,
    this.history = const [],
  });

  final String id;
  final String code;
  final String patientId;
  final String description;
  final Severity severity;
  final String? relatedMedication;
  final DateTime occurredAt;
  final String? notes;
  final SideEffectStatus status;

  /// Rule-based flag (patient chose severe/emergency). Not a clinical judgement.
  final bool priorityFlag;
  final DateTime createdAt;
  final List<SideEffectEvent> history;

  factory SideEffect.fromJson(Map<String, dynamic> j) => SideEffect(
        id: j['id'] as String,
        code: j['side_effect_code'] as String,
        patientId: j['patient_id'] as String,
        description: j['description'] as String,
        severity: Severity.values.byName(j['severity'] as String),
        relatedMedication: j['related_medication'] as String?,
        occurredAt: parseDate(j['occurred_at'])!,
        notes: j['notes'] as String?,
        status: SideEffectStatus.parse(j['status'] as String),
        priorityFlag: j['priority_flag'] as bool? ?? false,
        createdAt: parseDate(j['created_at'])!,
        history: [for (final e in (j['history'] as List? ?? const [])) SideEffectEvent.fromJson(e as Map<String, dynamic>)],
      );
}

class AppointmentRecommendation {
  const AppointmentRecommendation({required this.id, required this.doctorName, required this.reason, required this.createdAt, this.recommendedFor, this.sideEffectId, this.doctorId, this.patientId});
  final String id;
  final String? doctorId;
  final String? patientId;
  final String doctorName;
  final String reason;
  final DateTime createdAt;
  final DateTime? recommendedFor;
  final String? sideEffectId;

  factory AppointmentRecommendation.fromJson(Map<String, dynamic> j) => AppointmentRecommendation(
        id: j['id'] as String,
        doctorName: j['doctor_name'] as String,
        reason: j['reason'] as String,
        createdAt: parseDate(j['created_at'])!,
        recommendedFor: parseDate(j['recommended_for']),
        sideEffectId: j['side_effect_id'] as String?,
        doctorId: j['doctor_id'] as String?,
        patientId: j['patient_id'] as String?,
      );
}

class Visit {
  const Visit({
    required this.id,
    required this.code,
    required this.doctorName,
    this.doctorId,
    required this.visitDate,
    required this.reason,
    required this.createdAt,
    this.clinicalNotes,
    this.assessment,
    this.doctorReasoning,
    this.treatmentDecision,
    this.followUpDate,
    this.instructions,
  });

  final String id;
  final String code;
  final String? doctorId;
  final String doctorName;
  final DateTime visitDate;
  final String reason;
  final String? clinicalNotes;
  final String? assessment;
  final String? doctorReasoning;
  final String? treatmentDecision;
  final DateTime? followUpDate;
  final String? instructions;
  final DateTime createdAt;

  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
        id: j['id'] as String,
        code: j['visit_code'] as String,
        doctorName: j['doctor_name'] as String,
        doctorId: j['doctor_id'] as String?,
        visitDate: parseDate(j['visit_date'])!,
        reason: j['reason'] as String,
        clinicalNotes: j['clinical_notes'] as String?,
        assessment: j['assessment'] as String?,
        doctorReasoning: j['doctor_reasoning'] as String?,
        treatmentDecision: j['treatment_decision'] as String?,
        followUpDate: parseDate(j['follow_up_date']),
        instructions: j['instructions'] as String?,
        createdAt: parseDate(j['created_at'])!,
      );
}

class Medicine {
  const Medicine({required this.medicine, required this.dosage, required this.frequency, required this.duration, this.instructions});
  final String medicine;
  final String dosage;
  final String frequency;
  final String duration;
  final String? instructions;

  Map<String, dynamic> toJson() => {'medicine': medicine, 'dosage': dosage, 'frequency': frequency, 'duration': duration, 'instructions': instructions};

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
        medicine: j['medicine'] as String,
        dosage: j['dosage'] as String,
        frequency: j['frequency'] as String,
        duration: j['duration'] as String,
        instructions: j['instructions'] as String?,
      );
}

class Prescription {
  const Prescription({
    required this.id,
    required this.code,
    required this.doctorName,
    required this.prescribedOn,
    required this.medicines,
    required this.createdAt,
    this.instructions,
    this.notes,
    this.followUpDate,
    this.doctorId,
    this.patientId,
  });

  final String id;
  final String? doctorId;
  final String? patientId;
  final String code;
  final String doctorName;
  final DateTime prescribedOn;
  final List<Medicine> medicines;
  final String? instructions;
  final String? notes;
  final DateTime? followUpDate;
  final DateTime createdAt;

  factory Prescription.fromJson(Map<String, dynamic> j) => Prescription(
        id: j['id'] as String,
        code: j['prescription_code'] as String,
        doctorName: j['doctor_name'] as String,
        prescribedOn: parseDate(j['prescribed_on'])!,
        medicines: [for (final m in j['medicines'] as List) Medicine.fromJson(m as Map<String, dynamic>)],
        instructions: j['instructions'] as String?,
        notes: j['notes'] as String?,
        followUpDate: parseDate(j['follow_up_date']),
        createdAt: parseDate(j['created_at'])!,
        doctorId: j['doctor_id'] as String?,
        patientId: j['patient_id'] as String?,
      );
}

class TimelineEvent {
  const TimelineEvent({required this.type, required this.id, required this.date, required this.title, required this.subtitle, this.code});
  final String type;
  final String id;
  final DateTime date;
  final String title;
  final String subtitle;
  final String? code;

  factory TimelineEvent.fromJson(Map<String, dynamic> j) => TimelineEvent(
        type: j['type'] as String,
        id: j['id'] as String,
        date: parseDate(j['date'])!,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String? ?? '',
        code: j['code'] as String?,
      );
}
