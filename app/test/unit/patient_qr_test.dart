import 'package:flutter_test/flutter_test.dart';
import 'package:susthiti/data/models/patient_qr.dart';

void main() {
  test('encodes and decodes a patient QR payload round-trip', () {
    const payload = PatientQrPayload(patientCode: 'SUS-P-3F9A1B', fullName: 'Asha Rao');
    final decoded = PatientQrPayload.tryDecode(payload.encode());
    expect(decoded, isNotNull);
    expect(decoded!.patientCode, 'SUS-P-3F9A1B');
    expect(decoded.fullName, 'Asha Rao');
  });

  test('never encodes anything beyond name and code (no medical data possible)', () {
    const payload = PatientQrPayload(patientCode: 'SUS-P-3F9A1B', fullName: 'Asha Rao');
    final raw = payload.encode();
    expect(raw, isNot(contains('report')));
    expect(raw, isNot(contains('diagnos')));
    expect(raw, isNot(contains('medication')));
  });

  test('rejects an arbitrary (non-SUSTHITI) QR code instead of crashing', () {
    expect(PatientQrPayload.tryDecode('https://example.com/not-susthiti'), isNull);
    expect(PatientQrPayload.tryDecode('{"unrelated": true}'), isNull);
    expect(PatientQrPayload.tryDecode('not even json'), isNull);
    expect(PatientQrPayload.tryDecode(''), isNull);
  });

  test('rejects a malformed SUSTHITI-tagged payload (missing or empty fields)', () {
    expect(PatientQrPayload.tryDecode('{"t": "susthiti_patient", "v": 1}'), isNull);
    expect(PatientQrPayload.tryDecode('{"t": "susthiti_patient", "v": 1, "code": "", "name": "Asha"}'), isNull);
    expect(PatientQrPayload.tryDecode('{"t": "susthiti_patient", "v": 1, "code": "SUS-P-3F9A1B", "name": ""}'), isNull);
  });

  test('rejects a payload from an unrelated app that happens to use similar JSON keys', () {
    expect(PatientQrPayload.tryDecode('{"t": "some_other_app", "code": "X", "name": "Y"}'), isNull);
  });
}
