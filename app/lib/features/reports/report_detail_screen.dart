import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/report.dart';
import '../../data/providers.dart';
import '../ai/ai_summary_section.dart';
import 'report_values_section.dart';
import 'reports_providers.dart';

class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.patientId, required this.reportId});
  final String patientId;
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportProvider(reportId));
    return AppPage(
      title: report.value?.title ?? 'Report',
      body: ReportDetailBody(reportId: reportId),
    );
  }
}

/// Metadata, original file and AI summary for one report. Used full-screen on phones and tablets
/// and in the detail pane beside the report list on desktop.
class ReportDetailBody extends ConsumerWidget {
  const ReportDetailBody({super.key, required this.reportId, this.showTitle = false});
  final String reportId;

  /// In a side pane there is no app bar, so the report's title is shown in the body.
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportProvider(reportId));
    return AsyncBody(
      value: report,
      onRetry: () => ref.invalidate(reportProvider(reportId)),
      data: (r) => PageBody(
        maxWidth: 820,
        children: [
          if (showTitle) ...[Text(r.title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: AppSpacing.md)],
          _Metadata(report: r),
          const SizedBox(height: AppSpacing.lg),
          _OriginalReport(report: r),
          const SizedBox(height: AppSpacing.lg),
          ReportValuesSection(reportId: reportId, patientId: r.patientId),
          const SizedBox(height: AppSpacing.lg),
          AiSummarySection(
            title: 'AI Summary',
            value: ref.watch(individualSummaryProvider(reportId)),
            emptyMessage: 'No summary generated yet.',
            loadingMessage: 'Analyzing report...',
            failureReassurance: 'Your original report is still safely available.',
            onGenerate: () => ref.read(aiRepositoryProvider).reports.generateIndividual(reportId),
            onGenerated: () => ref.invalidate(individualSummaryProvider(reportId)),
          ),
        ],
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.report});
  final MedicalReport report;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(report.title, style: t.titleLarge)),
              if (report.allCategories.length == 1) StatusPill(report.category.label, dot: false),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (report.allCategories.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [for (final c in report.allCategories) StatusPill(c.label, dot: false)]),
            ),
          KeyValueRow('Report date', Fmt.date(report.reportDate)),
          KeyValueRow('Uploaded', Fmt.dateTime(report.uploadedAt)),
          KeyValueRow('Uploaded by', report.uploadedBy.display, trailing: SourceLabel(report.uploadedBy.role)),
          KeyValueRow('Report ID', report.reportCode),
          if (report.description != null) KeyValueRow('Description', report.description!),
        ],
      ),
    );
  }
}

/// The original file always stays available, independent of AI.
class _OriginalReport extends ConsumerStatefulWidget {
  const _OriginalReport({required this.report});
  final MedicalReport report;

  @override
  ConsumerState<_OriginalReport> createState() => _OriginalReportState();
}

class _OriginalReportState extends ConsumerState<_OriginalReport> {
  Uint8List? _bytes;
  bool _busy = false;

  Future<Uint8List?> _load() async {
    if (_bytes != null) return _bytes;
    setState(() => _busy = true);
    try {
      _bytes = await ref.read(fileStorageServiceProvider).original(widget.report);
      return _bytes;
    } catch (e) {
      if (mounted) showFailure(context, e);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _view() async {
    final bytes = await _load();
    if (bytes == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OriginalFileViewer(report: widget.report, bytes: bytes),
      ),
    );
  }

  Future<void> _download() async {
    final bytes = await _load();
    if (bytes == null) return;
    try {
      await ref.read(fileStorageServiceProvider).download(widget.report, bytes: bytes);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Original Report', style: t.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('${widget.report.originalFilename} · ${Fmt.fileSize(widget.report.fileSize)}', style: t.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(onPressed: _busy ? null : _view, icon: const Icon(Icons.visibility_outlined), label: const Text('View')),
              OutlinedButton.icon(onPressed: _busy ? null : _download, icon: const Icon(Icons.download_outlined), label: const Text('Download')),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class OriginalFileViewer extends StatelessWidget {
  const OriginalFileViewer({super.key, required this.report, required this.bytes});
  final MedicalReport report;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(report.originalFilename, overflow: TextOverflow.ellipsis)),
      backgroundColor: AppColors.neutralSoft,
      body: report.isPdf
          ? PdfPreview(
              build: (_) async => bytes,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: true,
              allowSharing: true,
              pdfFileName: report.originalFilename,
            )
          : InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: Image.memory(
                  bytes,
                  semanticLabel: report.title,
                  errorBuilder: (_, _, _) =>
                      const EmptyState(icon: Icons.image_not_supported_outlined, title: "This image can't be previewed here.", message: 'Use Download to open it in another app.'),
                ),
              ),
            ),
    );
  }
}
