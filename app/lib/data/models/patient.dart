import '../../core/utils/formatters.dart';

class EmergencyContact {
  const EmergencyContact({this.name, this.relationship, this.phone});
  final String? name;
  final String? relationship;
  final String? phone;

  bool get isEmpty => (name ?? '').isEmpty && (phone ?? '').isEmpty;

  factory EmergencyContact.fromJson(Map<String, dynamic>? j) =>
      EmergencyContact(name: j?['name'] as String?, relationship: j?['relationship'] as String?, phone: j?['phone'] as String?);
}

/// Latest height and weight from the health profile, and the BMI SUSTHITI calculates from them.
class BodyMeasurements {
  const BodyMeasurements({this.heightCm, this.weightKg, this.bmi, this.weightRecordedAt});
  final double? heightCm;
  final double? weightKg;
  final double? bmi;
  final DateTime? weightRecordedAt;

  static const empty = BodyMeasurements();

  factory BodyMeasurements.fromJson(Map<String, dynamic>? j) => j == null
      ? empty
      : BodyMeasurements(
          heightCm: (j['height_cm'] as num?)?.toDouble(),
          weightKg: (j['weight_kg'] as num?)?.toDouble(),
          bmi: (j['bmi'] as num?)?.toDouble(),
          weightRecordedAt: parseDate(j['weight_recorded_at']),
        );
}

class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.patientCode,
    required this.fullName,
    required this.email,
    this.dateOfBirth,
    this.age,
    this.gender,
    this.phone,
    this.hasPhoto = false,
    this.emergencyContact = const EmergencyContact(),
    this.isDemo = false,
    this.body = BodyMeasurements.empty,
  });

  final String id;
  final String patientCode;
  final String fullName;
  final String email;
  final DateTime? dateOfBirth;
  final int? age;
  final String? gender;
  final String? phone;
  final bool hasPhoto;
  final EmergencyContact emergencyContact;
  final bool isDemo;
  final BodyMeasurements body;

  factory PatientProfile.fromJson(Map<String, dynamic> j) => PatientProfile(
        id: j['id'] as String,
        patientCode: j['patient_code'] as String,
        fullName: j['full_name'] as String,
        email: j['email'] as String,
        dateOfBirth: parseDate(j['date_of_birth']),
        age: j['age'] as int?,
        gender: j['gender'] as String?,
        phone: j['phone'] as String?,
        hasPhoto: j['has_photo'] as bool? ?? false,
        emergencyContact: EmergencyContact.fromJson(j['emergency_contact'] as Map<String, dynamic>?),
        isDemo: j['is_demo'] as bool? ?? false,
        body: BodyMeasurements.fromJson(j['body'] as Map<String, dynamic>?),
      );
}

class DoctorProfile {
  const DoctorProfile({
    required this.id,
    required this.doctorCode,
    required this.fullName,
    required this.email,
    this.specialization,
    this.licenseNumber,
    this.phone,
    this.isActive = true,
    this.isDemo = false,
    this.createdAt,
    this.activePatients,
    this.lastLoginAt,
    this.lastActivityAt,
  });

  final String id;
  final String doctorCode;
  final String fullName;
  final String email;
  final String? specialization;
  final String? licenseNumber;
  final String? phone;
  final bool isActive;
  final bool isDemo;
  final DateTime? createdAt;

  /// Admin list only: approved patient relationships and the latest recorded activity.
  final int? activePatients;
  final DateTime? lastLoginAt;
  final DateTime? lastActivityAt;

  factory DoctorProfile.fromJson(Map<String, dynamic> j) => DoctorProfile(
        id: j['id'] as String,
        doctorCode: j['doctor_code'] as String,
        fullName: j['full_name'] as String,
        email: j['email'] as String,
        specialization: j['specialization'] as String?,
        licenseNumber: j['license_number'] as String?,
        phone: j['phone'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        isDemo: j['is_demo'] as bool? ?? false,
        createdAt: parseDate(j['created_at']),
        activePatients: j['active_patients'] as int?,
        lastLoginAt: parseDate(j['last_login_at']),
        lastActivityAt: parseDate(j['last_activity_at']),
      );
}

enum AccessStatus {
  pending,
  approved,
  rejected,
  revoked;

  static AccessStatus parse(String v) => AccessStatus.values.byName(v);
  String get label => Fmt.titleCase(name);
}

class AccessRequest {
  const AccessRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.doctorId,
    required this.doctorName,
    required this.doctorCode,
    required this.patientId,
    required this.patientName,
    required this.patientCode,
    this.doctorSpecialization,
    this.message,
    this.respondedAt,
    this.revokedAt,
  });

  final String id;
  final AccessStatus status;
  final DateTime requestedAt;
  final String doctorId;
  final String doctorName;
  final String doctorCode;
  final String? doctorSpecialization;
  final String patientId;
  final String patientName;
  final String patientCode;
  final String? message;
  final DateTime? respondedAt;
  final DateTime? revokedAt;

  factory AccessRequest.fromJson(Map<String, dynamic> j) {
    final d = j['doctor'] as Map<String, dynamic>;
    final p = j['patient'] as Map<String, dynamic>;
    return AccessRequest(
      id: j['id'] as String,
      status: AccessStatus.parse(j['status'] as String),
      requestedAt: parseDate(j['requested_at'])!,
      respondedAt: parseDate(j['responded_at']),
      revokedAt: parseDate(j['revoked_at']),
      message: j['message'] as String?,
      doctorId: d['id'] as String,
      doctorName: d['name'] as String,
      doctorCode: d['doctor_code'] as String,
      doctorSpecialization: d['specialization'] as String?,
      patientId: p['id'] as String,
      patientName: p['name'] as String,
      patientCode: p['patient_code'] as String,
    );
  }
}

class DoctorPatientSummary {
  const DoctorPatientSummary({required this.id, required this.name, required this.patientCode, this.gender, this.age, this.openSideEffects = 0, this.nextFollowUp, this.lastActivityAt});

  final String id;
  final String name;
  final String patientCode;
  final String? gender;
  final int? age;
  final int openSideEffects;
  final DateTime? nextFollowUp;
  final DateTime? lastActivityAt;

  factory DoctorPatientSummary.fromJson(Map<String, dynamic> j) => DoctorPatientSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        patientCode: j['patient_code'] as String,
        gender: j['gender'] as String?,
        age: j['age'] as int?,
        openSideEffects: j['open_side_effects'] as int? ?? 0,
        nextFollowUp: parseDate(j['next_follow_up']),
        lastActivityAt: parseDate(j['last_activity_at']),
      );
}
