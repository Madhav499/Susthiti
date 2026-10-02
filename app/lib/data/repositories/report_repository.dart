import 'dart:typed_data';

import '../../core/services/api_client.dart';
import '../../core/utils/formatters.dart';
import '../models/health_data.dart';
import '../models/report.dart';

abstract interface class ReportRepository {
  Future<ReportPage> list(String patientId, ReportQuery query, {int offset = 0, int limit = 20});
  Future<MedicalReport> get(String reportId);
  /// [categories]: every type the report covers; the first is the primary type.
  Future<MedicalReport> upload(String patientId, {required List<ReportCategory> categories, required DateTime reportDate, String? description, required Uint8List bytes, required String filename});

  /// Admin uploads on a patient's behalf. Write-only: returns the new report code, since
  /// admins cannot read medical records back.
  Future<String> adminUpload(String patientId, {required List<ReportCategory> categories, required DateTime reportDate, String? description, required Uint8List bytes, required String filename});

  /// Retrieves the ORIGINAL file only when requested.
  Future<Uint8List> originalFile(String reportId);

  /// Structured values confirmed from this report (and strict AI suggestions to confirm).
  Future<ReportValues> values(String reportId);

  /// Confirms, corrects or removes values: analyte -> {value, unit} / {text_value} / {origin: confirm} / null.
  Future<ReportValues> saveValues(String reportId, Map<String, Object?> values);

  /// Reads HbA1c / glucose results from the report file again.
  Future<ReportValues> readValues(String reportId);
}

class ApiReportRepository implements ReportRepository {
  ApiReportRepository(this._api);
  final ApiClient _api;

  @override
  Future<ReportPage> list(String patientId, ReportQuery query, {int offset = 0, int limit = 20}) async {
    final r = await _api.get('/patients/$patientId/reports', query: {
      'q': query.search.trim(),
      'category': query.group.apiValue,
      'start': query.start == null ? null : Fmt.isoDate(query.start!),
      'end': query.end == null ? null : Fmt.isoDate(query.end!),
      'sort': query.newestFirst ? 'newest' : 'oldest',
      'offset': offset,
      'limit': limit,
    });
    return ReportPage(items: [for (final i in r['items'] as List) MedicalReport.fromJson(i as Json)], total: r['total'] as int);
  }

  @override
  Future<MedicalReport> get(String reportId) async => MedicalReport.fromJson(await _api.get('/reports/$reportId'));

  @override
  Future<ReportValues> values(String reportId) async => ReportValues.fromJson(await _api.get('/reports/$reportId/values'));

  @override
  Future<ReportValues> saveValues(String reportId, Map<String, Object?> values) async =>
      ReportValues.fromJson(await _api.put('/reports/$reportId/values', body: {'values': values}));

  @override
  Future<ReportValues> readValues(String reportId) async =>
      ReportValues.fromJson(await _api.post('/reports/$reportId/values/read', timeout: const Duration(seconds: 90)));

  @override
  Future<MedicalReport> upload(String patientId, {required List<ReportCategory> categories, required DateTime reportDate, String? description, required Uint8List bytes, required String filename}) async =>
      MedicalReport.fromJson(await _api.upload(
        '/patients/$patientId/reports',
        fields: {'category': categories.map((c) => c.apiValue).join(','), 'report_date': Fmt.isoDate(reportDate), 'description': description?.trim()},
        fileField: 'file',
        bytes: bytes,
        filename: filename,
      ));

  @override
  Future<String> adminUpload(String patientId, {required List<ReportCategory> categories, required DateTime reportDate, String? description, required Uint8List bytes, required String filename}) async {
    final r = await _api.upload(
      '/admin/patients/$patientId/reports',
      fields: {'category': categories.map((c) => c.apiValue).join(','), 'report_date': Fmt.isoDate(reportDate), 'description': description?.trim()},
      fileField: 'file',
      bytes: bytes,
      filename: filename,
    );
    return r['report_code'] as String;
  }

  @override
  Future<Uint8List> originalFile(String reportId) => _api.getBytes('/reports/$reportId/file');
}
