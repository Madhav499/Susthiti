import 'package:flutter_test/flutter_test.dart';
import 'package:susthiti/core/routing/app_router.dart';
import 'package:susthiti/data/models/user.dart';

const patient = AppUser(id: 'u1', email: 'p@x.test', role: UserRole.patient, fullName: 'Asha', patientId: 'pat1', patientCode: 'SUS-P-000001');
const doctor = AppUser(id: 'u2', email: 'd@x.test', role: UserRole.doctor, fullName: 'Rao', doctorId: 'doc1');
const admin = AppUser(id: 'u3', email: 'a@x.test', role: UserRole.admin, fullName: 'Admin');

String? go(AppUser? user, String path, {bool loading = false}) => roleRedirect(user, Uri.parse(path), loading: loading);

void main() {
  test('signed-out users only reach public auth pages', () {
    expect(go(null, '/login'), isNull);
    expect(go(null, '/register'), isNull);
    expect(go(null, '/p/home'), '/login');
    expect(go(null, '/d/home'), '/login');
    expect(go(null, '/r/pat1/reports'), '/login');
  });

  test('shows the splash while the session is being restored, then returns to the requested page', () {
    expect(go(null, '/p/home', loading: true), '/splash?from=%2Fp%2Fhome');
    expect(go(null, '/splash', loading: true), isNull);
    expect(go(admin, '/splash?from=%2Fa%2Fpatients%2Fpat1%3Ftab%3Dreports'), '/a/patients/pat1?tab=reports');
    // A remembered page the role may not open falls back to the role home.
    expect(go(patient, '/splash?from=%2Fa%2Fdoctors'), '/p/home');
    expect(go(patient, '/splash?from=https%3A%2F%2Fevil.example'), '/p/home');
  });

  test('signed-in users land on their role home', () {
    expect(go(patient, '/login'), '/p/home');
    expect(go(doctor, '/splash'), '/d/home');
    expect(go(admin, '/'), '/a/home');
  });

  test('patients cannot open doctor, admin or another patient\'s screens', () {
    expect(go(patient, '/p/reports'), isNull);
    expect(go(patient, '/r/pat1/reports/r1'), isNull);
    expect(go(patient, '/r/other/reports/r1'), '/p/home');
    expect(go(patient, '/d/patients'), '/p/home');
    expect(go(patient, '/a/doctors'), '/p/home');
  });

  test('doctors reach record screens (backend enforces approval) but not patient or admin areas', () {
    expect(go(doctor, '/r/pat9/prescriptions'), isNull);
    expect(go(doctor, '/d/patients/pat9'), isNull);
    expect(go(doctor, '/p/home'), '/d/home');
    expect(go(doctor, '/a/home'), '/d/home');
  });

  test('admins open profiles and read any record screen, but not patient/doctor areas or clinical uploads', () {
    expect(go(admin, '/a/patients'), isNull);
    expect(go(admin, '/a/patients/pat1?tab=reports'), isNull);
    expect(go(admin, '/a/doctors/doc1'), isNull);
    expect(go(admin, '/a/doctors/doc1/edit'), isNull);
    expect(go(admin, '/r/pat1/reports'), isNull);
    expect(go(admin, '/r/pat1/reports/r1'), isNull);
    expect(go(admin, '/r/pat1/prescriptions/rx1'), isNull);
    expect(go(admin, '/r/pat1/reports/upload'), '/a/home');
    expect(go(admin, '/d/home'), '/a/home');
    expect(go(admin, '/p/home'), '/a/home');
  });
}
