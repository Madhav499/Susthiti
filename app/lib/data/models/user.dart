enum UserRole {
  patient,
  doctor,
  admin;

  static UserRole parse(String v) => UserRole.values.firstWhere((r) => r.name == v, orElse: () => throw FormatException('Unknown role $v'));

  String get label => switch (this) { patient => 'Patient', doctor => 'Doctor', admin => 'Admin' };
}

/// Locale codes SUSTHITI's UI is translated into. Kept next to [UserRole] as the other
/// small, stable enumeration on [AppUser].
const List<String> kSupportedLocales = ['en', 'hi', 'gu'];

/// Safe fallback for a missing, null, or (future) unsupported locale -- always English.
String normalizeLocale(String? value) => kSupportedLocales.contains(value) ? value! : 'en';

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
    this.preferredLocale = 'en',
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
  final String preferredLocale;

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
        preferredLocale: normalizeLocale(j['preferred_locale'] as String?),
      );

  AppUser copyWith({String? fullName, String? preferredLocale}) => AppUser(
        id: id, email: email, role: role, fullName: fullName ?? this.fullName, isDemo: isDemo,
        patientId: patientId, patientCode: patientCode, doctorId: doctorId, doctorCode: doctorCode,
        preferredLocale: preferredLocale ?? this.preferredLocale,
      );
}

class AuthSession {
  const AuthSession({required this.token, required this.user});
  final String token;
  final AppUser user;
}
