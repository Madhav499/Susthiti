import 'dart:typed_data';

import '../../core/services/api_client.dart';
import '../../core/utils/formatters.dart';
import '../models/admin.dart';
import '../models/ai_summary.dart';
import '../models/care.dart';
import '../models/health_data.dart';
import '../models/patient.dart';
import '../models/system.dart';
import '../models/tracking.dart';

abstract interface class PatientRepository {
  Future<PatientProfile> myProfile();
  Future<PatientProfile> profile(String patientId);
  Future<PatientProfile> updateProfile(Map<String, dynamic> changes);
  Future<PatientProfile> uploadPhoto(Uint8List bytes, String filename);
  Future<Uint8List> photo(String patientId);
  Future<PatientDashboard> dashboard(String patientId);
  Future<({List<TimelineEvent> items, bool hasMore})> timeline(String patientId, {String type = 'all', DateTime? before});
  Future<TrendSeries> trend(String patientId, String metric, String range, {DateTime? start, DateTime? end});

  Future<List<AccessRequest>> accessRequests({String? status});
  Future<AccessRequest> respondToAccess(String requestId, {required bool approve});
  Future<AccessRequest> revokeAccess(String requestId);
  Future<List<AppointmentRecommendation>> appointments(String patientId);
  Future<List<FollowUpTask>> followUps(String patientId);
  Future<List<Surgery>> surgeries(String patientId);

  /// Health profile: body measurements, medical and family history, habits, recent symptoms.
  Future<HealthProfile> healthProfile(String patientId);

  /// field -> value (null records "not sure"). Only the fields given are recorded.
  Future<HealthProfile> updateHealthProfile(String patientId, Map<String, Object?> values);
}

class ApiPatientRepository implements PatientRepository {
  ApiPatientRepository(this._api);
  final ApiClient _api;

  @override
  Future<PatientProfile> myProfile() async => PatientProfile.fromJson(await _api.get('/patients/me'));

  @override
  Future<PatientProfile> profile(String patientId) async => PatientProfile.fromJson(await _api.get('/patients/$patientId/profile'));

  @override
  Future<PatientProfile> updateProfile(Map<String, dynamic> changes) async => PatientProfile.fromJson(await _api.patch('/patients/me', body: changes));

  @override
  Future<PatientProfile> uploadPhoto(Uint8List bytes, String filename) async =>
      PatientProfile.fromJson(await _api.upload('/patients/me/photo', fields: const {}, fileField: 'file', bytes: bytes, filename: filename, method: 'PUT'));

  @override
  Future<Uint8List> photo(String patientId) => _api.getBytes('/patients/$patientId/photo');

  @override
  Future<PatientDashboard> dashboard(String patientId) async => PatientDashboard.fromJson(await _api.get('/patients/$patientId/dashboard'));

  @override
  Future<({List<TimelineEvent> items, bool hasMore})> timeline(String patientId, {String type = 'all', DateTime? before}) async {
    final r = await _api.get('/patients/$patientId/timeline', query: {'type': type, 'before': before?.toUtc().toIso8601String()});
    return (items: [for (final e in r['items'] as List) TimelineEvent.fromJson(e as Json)], hasMore: r['has_more'] as bool? ?? false);
  }

  @override
  Future<TrendSeries> trend(String patientId, String metric, String range, {DateTime? start, DateTime? end}) async => TrendSeries.fromJson(await _api.get(
        '/patients/$patientId/trends',
        query: {'metric': metric, 'range': range, 'start': start == null ? null : Fmt.isoDate(start), 'end': end == null ? null : Fmt.isoDate(end)},
      ));

  @override
  Future<List<AccessRequest>> accessRequests({String? status}) async {
    final r = await _api.get('/access-requests', query: {'status': status});
    return [for (final a in r['items'] as List) AccessRequest.fromJson(a as Json)];
  }

  @override
  Future<AccessRequest> respondToAccess(String requestId, {required bool approve}) async =>
      AccessRequest.fromJson(await _api.post('/access-requests/$requestId/${approve ? 'approve' : 'reject'}'));

  @override
  Future<AccessRequest> revokeAccess(String requestId) async => AccessRequest.fromJson(await _api.post('/access-requests/$requestId/revoke'));

  @override
  Future<List<AppointmentRecommendation>> appointments(String patientId) async {
    final r = await _api.get('/patients/$patientId/appointment-recommendations');
    return [for (final a in r['items'] as List) AppointmentRecommendation.fromJson(a as Json)];
  }

  @override
  Future<List<FollowUpTask>> followUps(String patientId) async {
    final r = await _api.get('/patients/$patientId/follow-ups');
    return [for (final f in r['items'] as List) FollowUpTask.fromJson(f as Json)];
  }

  @override
  Future<List<Surgery>> surgeries(String patientId) async {
    final r = await _api.get('/patients/$patientId/surgeries');
    return [for (final s in r['items'] as List) Surgery.fromJson(s as Json)];
  }

  @override
  Future<HealthProfile> healthProfile(String patientId) async => HealthProfile.fromJson(await _api.get('/patients/$patientId/health-profile'));

  @override
  Future<HealthProfile> updateHealthProfile(String patientId, Map<String, Object?> values) async =>
      HealthProfile.fromJson(await _api.put('/patients/$patientId/health-profile', body: {'values': values}));
}

abstract interface class DoctorRepository {
  Future<DoctorDashboard> dashboard();
  Future<List<DoctorPatientSummary>> patients({String query = '', String filter = 'all'});
  Future<AccessRequest> requestAccess({required String patientName, required String patientCode, String? message});
  Future<List<AccessRequest>> accessRequests();
  Future<AppointmentRecommendation> recommendAppointment(String patientId, {required String reason, DateTime? recommendedFor, String? sideEffectId});
  Future<FollowUpTask> createFollowUp(String patientId, {required String purpose, required DateTime dueDate});
  Future<FollowUpTask> completeFollowUp(String followUpId, {String? notes});
  Future<FollowUpTask> cancelFollowUp(String followUpId, {String? notes});
  Future<FollowUpTask> rescheduleFollowUp(String followUpId, DateTime dueDate);

  Future<Surgery> createSurgery(
    String patientId, {
    required String name,
    required String purpose,
    DateTime? scheduledAt,
    String? hospital,
    String? patientInstructions,
    String? internalNotes,
  });
  /// Only the keys present in [changes] are updated (name, purpose, hospital,
  /// patient_instructions, internal_notes) -- omit a key to leave it unchanged.
  Future<Surgery> updateSurgery(String surgeryId, Map<String, dynamic> changes);
  Future<Surgery> rescheduleSurgery(String surgeryId, DateTime scheduledAt);
  Future<Surgery> completeSurgery(String surgeryId);
  Future<Surgery> cancelSurgery(String surgeryId);
}

class ApiDoctorRepository implements DoctorRepository {
  ApiDoctorRepository(this._api);
  final ApiClient _api;

  @override
  Future<DoctorDashboard> dashboard() async => DoctorDashboard.fromJson(await _api.get('/doctor/dashboard'));

  @override
  Future<List<DoctorPatientSummary>> patients({String query = '', String filter = 'all'}) async {
    final r = await _api.get('/doctor/patients', query: {'q': query.trim(), 'filter': filter});
    return [for (final p in r['items'] as List) DoctorPatientSummary.fromJson(p as Json)];
  }

  @override
  Future<AccessRequest> requestAccess({required String patientName, required String patientCode, String? message}) async => AccessRequest.fromJson(await _api.post(
        '/access-requests',
        body: {'patient_name': patientName.trim(), 'patient_code': patientCode.trim().toUpperCase(), if (message != null && message.trim().isNotEmpty) 'message': message.trim()},
      ));

  @override
  Future<List<AccessRequest>> accessRequests() async {
    final r = await _api.get('/access-requests');
    return [for (final a in r['items'] as List) AccessRequest.fromJson(a as Json)];
  }

  @override
  Future<AppointmentRecommendation> recommendAppointment(String patientId, {required String reason, DateTime? recommendedFor, String? sideEffectId}) async =>
      AppointmentRecommendation.fromJson(await _api.post('/patients/$patientId/appointment-recommendations', body: {
        'reason': reason.trim(),
        'recommended_for': recommendedFor?.toUtc().toIso8601String(),
        'side_effect_id': sideEffectId,
      }));

  @override
  Future<FollowUpTask> createFollowUp(String patientId, {required String purpose, required DateTime dueDate}) async =>
      FollowUpTask.fromJson(await _api.post('/patients/$patientId/follow-ups', body: {'purpose': purpose.trim(), 'due_date': Fmt.isoDate(dueDate)}));

  @override
  Future<FollowUpTask> completeFollowUp(String followUpId, {String? notes}) async =>
      FollowUpTask.fromJson(await _api.post('/follow-ups/$followUpId/complete', body: {'notes': notes?.trim()}));

  @override
  Future<FollowUpTask> cancelFollowUp(String followUpId, {String? notes}) async =>
      FollowUpTask.fromJson(await _api.post('/follow-ups/$followUpId/cancel', body: {'notes': notes?.trim()}));

  @override
  Future<FollowUpTask> rescheduleFollowUp(String followUpId, DateTime dueDate) async =>
      FollowUpTask.fromJson(await _api.post('/follow-ups/$followUpId/reschedule', body: {'due_date': Fmt.isoDate(dueDate)}));

  @override
  Future<Surgery> createSurgery(
    String patientId, {
    required String name,
    required String purpose,
    DateTime? scheduledAt,
    String? hospital,
    String? patientInstructions,
    String? internalNotes,
  }) async =>
      Surgery.fromJson(await _api.post('/patients/$patientId/surgeries', body: {
        'name': name.trim(),
        'purpose': purpose.trim(),
        'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
        'hospital': hospital?.trim(),
        'patient_instructions': patientInstructions?.trim(),
        'internal_notes': internalNotes?.trim(),
      }));

  @override
  Future<Surgery> updateSurgery(String surgeryId, Map<String, dynamic> changes) async => Surgery.fromJson(await _api.post('/surgeries/$surgeryId/update', body: changes));

  @override
  Future<Surgery> rescheduleSurgery(String surgeryId, DateTime scheduledAt) async =>
      Surgery.fromJson(await _api.post('/surgeries/$surgeryId/reschedule', body: {'scheduled_at': scheduledAt.toUtc().toIso8601String()}));

  @override
  Future<Surgery> completeSurgery(String surgeryId) async => Surgery.fromJson(await _api.post('/surgeries/$surgeryId/complete'));

  @override
  Future<Surgery> cancelSurgery(String surgeryId) async => Surgery.fromJson(await _api.post('/surgeries/$surgeryId/cancel'));
}

abstract interface class AdminRepository {
  Future<AdminDashboard> dashboard();
  Future<List<DoctorProfile>> doctors({String query = '', String status = 'all'});
  Future<DoctorProfile> createDoctor({required String fullName, required String email, required String temporaryPassword, String? specialization, String? licenseNumber, String? phone});
  Future<DoctorProfile> updateDoctor(String doctorId, Map<String, dynamic> changes);
  Future<({List<AdminPatient> items, int total})> patients({String query = '', String status = 'all', int offset = 0});
  Future<void> setPatientActive(String patientId, bool active);
  Future<PatientProfile> updatePatient(String patientId, Map<String, dynamic> changes);

  // Read-only profile views (the doctor's or patient's complete system record).
  Future<AdminDoctorDetail> doctor(String doctorId);
  Future<List<DoctorPatientLink>> doctorPatients(String doctorId, {String status = 'all'});
  Future<DoctorReportActivity> doctorReports(String doctorId);
  Future<({List<PrescriptionWithPatient> items, int total})> doctorPrescriptions(String doctorId, {int offset = 0});
  Future<DoctorAppointments> doctorAppointments(String doctorId);
  Future<DoctorSideEffects> doctorSideEffects(String doctorId);
  Future<({List<LinkedAuditEntry> items, int total})> doctorActivity(String doctorId, {String scope = 'actions', int offset = 0});
  Future<AdminPatientDetail> patient(String patientId);
  Future<List<WearableConnection>> patientDevices(String patientId);
  Future<List<AppNotification>> patientNotifications(String patientId);
  Future<List<AISummary>> patientAiSummaries(String patientId);
  Future<({List<LinkedAuditEntry> items, int total})> patientAudit(String patientId, {int offset = 0});
  Future<List<AccessRequest>> accessRequests({String? status});
  Future<AccessRequest> revokeAccess(String requestId);
  Future<({List<AuditEntry> items, int total})> auditLogs({String query = '', int offset = 0});
  Future<({List<NotificationDeliveryEntry> items, int total})> notificationDelivery({String? status, int offset = 0});
  Future<SystemSettings> settings();
  Future<SystemSettings> updateSettings(Map<String, String> values);
}

class ApiAdminRepository implements AdminRepository {
  ApiAdminRepository(this._api);
  final ApiClient _api;

  @override
  Future<AdminDashboard> dashboard() async => AdminDashboard.fromJson(await _api.get('/admin/dashboard'));

  @override
  Future<List<DoctorProfile>> doctors({String query = '', String status = 'all'}) async {
    final r = await _api.get('/admin/doctors', query: {'q': query.trim(), 'status': status});
    return [for (final d in r['items'] as List) DoctorProfile.fromJson(d as Json)];
  }

  @override
  Future<DoctorProfile> createDoctor({required String fullName, required String email, required String temporaryPassword, String? specialization, String? licenseNumber, String? phone}) async =>
      DoctorProfile.fromJson(await _api.post('/admin/doctors', body: {
        'full_name': fullName.trim(),
        'email': email.trim(),
        'temporary_password': temporaryPassword,
        'specialization': _blankToNull(specialization),
        'license_number': _blankToNull(licenseNumber),
        'phone': _blankToNull(phone),
      }));

  @override
  Future<DoctorProfile> updateDoctor(String doctorId, Map<String, dynamic> changes) async => DoctorProfile.fromJson(await _api.patch('/admin/doctors/$doctorId', body: changes));

  @override
  Future<({List<AdminPatient> items, int total})> patients({String query = '', String status = 'all', int offset = 0}) async {
    final r = await _api.get('/admin/patients', query: {'q': query.trim(), 'status': status, 'offset': offset, 'limit': 50});
    return (items: [for (final p in r['items'] as List) AdminPatient.fromJson(p as Json)], total: r['total'] as int);
  }

  @override
  Future<void> setPatientActive(String patientId, bool active) => _api.post('/admin/patients/$patientId/status', body: {'is_active': active});

  @override
  Future<PatientProfile> updatePatient(String patientId, Map<String, dynamic> changes) async => PatientProfile.fromJson(await _api.patch('/admin/patients/$patientId', body: changes));

  @override
  Future<AdminDoctorDetail> doctor(String doctorId) async => AdminDoctorDetail.fromJson(await _api.get('/admin/doctors/$doctorId'));

  @override
  Future<List<DoctorPatientLink>> doctorPatients(String doctorId, {String status = 'all'}) async {
    final r = await _api.get('/admin/doctors/$doctorId/patients', query: {'status': status});
    return [for (final p in r['items'] as List) DoctorPatientLink.fromJson(p as Json)];
  }

  @override
  Future<DoctorReportActivity> doctorReports(String doctorId) async => DoctorReportActivity.fromJson(await _api.get('/admin/doctors/$doctorId/reports'));

  @override
  Future<({List<PrescriptionWithPatient> items, int total})> doctorPrescriptions(String doctorId, {int offset = 0}) async {
    final r = await _api.get('/admin/doctors/$doctorId/prescriptions', query: {'offset': offset, 'limit': 50});
    return (items: [for (final p in r['items'] as List) PrescriptionWithPatient.fromJson(p as Json)], total: r['total'] as int);
  }

  @override
  Future<DoctorAppointments> doctorAppointments(String doctorId) async => DoctorAppointments.fromJson(await _api.get('/admin/doctors/$doctorId/appointments'));

  @override
  Future<DoctorSideEffects> doctorSideEffects(String doctorId) async => DoctorSideEffects.fromJson(await _api.get('/admin/doctors/$doctorId/side-effects'));

  @override
  Future<({List<LinkedAuditEntry> items, int total})> doctorActivity(String doctorId, {String scope = 'actions', int offset = 0}) async {
    final r = await _api.get('/admin/doctors/$doctorId/activity', query: {'scope': scope, 'offset': offset, 'limit': 50});
    return (items: [for (final a in r['items'] as List) LinkedAuditEntry.fromJson(a as Json)], total: r['total'] as int);
  }

  @override
  Future<AdminPatientDetail> patient(String patientId) async => AdminPatientDetail.fromJson(await _api.get('/admin/patients/$patientId'));

  @override
  Future<List<WearableConnection>> patientDevices(String patientId) async {
    final r = await _api.get('/admin/patients/$patientId/devices');
    return [for (final d in r['items'] as List) WearableConnection.fromJson(d as Json)];
  }

  @override
  Future<List<AppNotification>> patientNotifications(String patientId) async {
    final r = await _api.get('/admin/patients/$patientId/notifications');
    return [for (final n in r['items'] as List) AppNotification.fromJson(n as Json)];
  }

  @override
  Future<List<AISummary>> patientAiSummaries(String patientId) async {
    final r = await _api.get('/admin/patients/$patientId/ai-summaries');
    return [for (final s in r['items'] as List) AISummary.fromJson(s as Json)];
  }

  @override
  Future<({List<LinkedAuditEntry> items, int total})> patientAudit(String patientId, {int offset = 0}) async {
    final r = await _api.get('/admin/patients/$patientId/audit', query: {'offset': offset, 'limit': 50});
    return (items: [for (final a in r['items'] as List) LinkedAuditEntry.fromJson(a as Json)], total: r['total'] as int);
  }

  @override
  Future<List<AccessRequest>> accessRequests({String? status}) async {
    final r = await _api.get('/access-requests', query: {'status': status});
    return [for (final a in r['items'] as List) AccessRequest.fromJson(a as Json)];
  }

  @override
  Future<AccessRequest> revokeAccess(String requestId) async => AccessRequest.fromJson(await _api.post('/access-requests/$requestId/revoke'));

  @override
  Future<({List<AuditEntry> items, int total})> auditLogs({String query = '', int offset = 0}) async {
    final r = await _api.get('/admin/audit-logs', query: {'q': query.trim(), 'offset': offset, 'limit': 50});
    return (items: [for (final a in r['items'] as List) AuditEntry.fromJson(a as Json)], total: r['total'] as int);
  }

  @override
  Future<({List<NotificationDeliveryEntry> items, int total})> notificationDelivery({String? status, int offset = 0}) async {
    final r = await _api.get('/admin/notifications/delivery', query: {'status': status, 'offset': offset, 'limit': 50});
    return (items: [for (final n in r['items'] as List) NotificationDeliveryEntry.fromJson(n as Json)], total: r['total'] as int);
  }

  @override
  Future<SystemSettings> settings() async => SystemSettings.fromJson(await _api.get('/admin/settings'));

  @override
  Future<SystemSettings> updateSettings(Map<String, String> values) async => SystemSettings.fromJson(await _api.put('/admin/settings', body: {'values': values}));
}

String? _blankToNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
