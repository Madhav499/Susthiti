enum UserRole {
  patient,
  doctor,
  admin;

  static UserRole parse(String v) => UserRole.values.firstWhere((r) => r.name == v, orElse: () => throw FormatException('Unknown role $v'));

  String get label => switch (this) { patient => 'Patient', doctor => 'Doctor', admin => 'Admin' };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    this.isDemo = false,
    this.patientId,
    this.patientCode,
    this.doctorId,
    this.doctorCode,
  });

  final String id;
  final String email;
  final UserRole role;
  final String fullName;
  final bool isDemo;
  final String? patientId;
  final String? patientCode;
  final String? doctorId;
  final String? doctorCode;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String,
        role: UserRole.parse(j['role'] as String),
        fullName: j['full_name'] as String,
        isDemo: j['is_demo'] as bool? ?? false,
        patientId: j['patient_id'] as String?,
        patientCode: j['patient_code'] as String?,
        doctorId: j['doctor_id'] as String?,
        doctorCode: j['doctor_code'] as String?,
      );

  AppUser copyWith({String? fullName}) => AppUser(
        id: id, email: email, role: role, fullName: fullName ?? this.fullName, isDemo: isDemo,
        patientId: patientId, patientCode: patientCode, doctorId: doctorId, doctorCode: doctorCode,
      );
}

class AuthSession {
  const AuthSession({required this.token, required this.user});
  final String token;
  final AppUser user;
}
