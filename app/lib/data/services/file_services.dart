import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/api_client.dart';
import '../../core/services/browser_files.dart';
import '../models/ai_summary.dart';
import '../models/report.dart';
import '../repositories/report_repository.dart';

/// FileStorageService: retrieves protected original reports through the authorized API
/// (never a public URL) and hands them to the platform save/share sheet.
class FileStorageService {
  FileStorageService(this._reports);
  final ReportRepository _reports;

  Future<Uint8List> original(MedicalReport report) => _reports.originalFile(report.id);

  Future<void> download(MedicalReport report, {Uint8List? bytes}) async {
    final data = bytes ?? await original(report);
    // Web: the browser's normal download. Mobile/desktop: the platform save/share sheet.
    if (kIsWeb && BrowserFiles.save(data, filename: report.originalFilename, mimeType: report.fileType)) return;
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(data, mimeType: report.fileType, name: report.originalFilename)],
      fileNameOverrides: [report.originalFilename],
    ));
  }
}

/// PDFService: SUSTHITI-styled PDFs are rendered by the backend from the stored summary.
class PDFService {
  PDFService(this._api);
  final ApiClient _api;

  Future<Uint8List> summaryPdf(AISummary summary) => _api.getBytes('/ai-summaries/${summary.id}/pdf');

  Future<void> download(AISummary summary) async {
    final bytes = await summaryPdf(summary);
    if (kIsWeb && BrowserFiles.save(bytes, filename: summary.pdfFilename, mimeType: 'application/pdf')) return;
    await Printing.sharePdf(bytes: bytes, filename: summary.pdfFilename);
  }

  /// Web: opens the PDF in a new tab. Elsewhere: the platform's PDF preview.
  Future<void> view(AISummary summary) async {
    final bytes = await summaryPdf(summary);
    if (kIsWeb && BrowserFiles.open(bytes, mimeType: 'application/pdf')) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: summary.pdfFilename);
  }
}
