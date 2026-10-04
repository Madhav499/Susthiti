import 'dart:convert';

/// The patient identity QR code's payload: just the opaque Patient ID and the patient's own
/// name, exactly the two things a doctor already has to type into the existing manual
/// "Request Access" form (see doctor/doctor_patients_screens.dart). Nothing else -- no medical
/// data, no reports, no diagnoses. Scanning it only pre-fills those two fields; the backend's
/// existing name+code match check on POST /access-requests is still the sole authority, exactly
/// as it is for a manually typed request, so this adds no new attack surface (no lookup
/// endpoint, no way to resolve a code to a name except by having scanned the patient's own QR).
class PatientQrPayload {
  const PatientQrPayload({required this.patientCode, required this.fullName});
  final String patientCode;
  final String fullName;

  static const _tag = 'susthiti_patient';
  static const _version = 1;

  String encode() => jsonEncode({'t': _tag, 'v': _version, 'code': patientCode, 'name': fullName});

  /// Returns null for anything that isn't a recognised SUSTHITI patient QR code (a QR scanner
  /// can pick up any arbitrary code; this must never crash or half-parse one).
  static PatientQrPayload? tryDecode(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['t'] != _tag) return null;
      final code = j['code'];
      final name = j['name'];
      if (code is! String || code.isEmpty || name is! String || name.isEmpty) return null;
      return PatientQrPayload(patientCode: code, fullName: name);
    } catch (_) {
      return null;
    }
  }
}
