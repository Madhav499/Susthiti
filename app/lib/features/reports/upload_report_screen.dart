import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../data/models/report.dart';
import '../../data/providers.dart';
import '../patient/patient_sync.dart';
import 'reports_providers.dart';

const _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'];

class UploadReportScreen extends ConsumerStatefulWidget {
  const UploadReportScreen({super.key, required this.patientId, this.asAdmin = false});
  final String patientId;

  /// Admin uploads are write-only; the admin returns to the patient list afterwards.
  final bool asAdmin;

  @override
  ConsumerState<UploadReportScreen> createState() => _UploadReportScreenState();
}

class _UploadReportScreenState extends ConsumerState<UploadReportScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final List<ReportCategory> _categories = [];
  String? _categoryError;
  DateTime? _reportDate;
  Uint8List? _bytes;
  String? _filename;
  String? _fileError;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: _allowedExtensions, dialogTitle: 'Choose a report');
      if (file == null) return;
      final ext = (file.extension ?? '').toLowerCase().replaceAll('.', '');
      if (!_allowedExtensions.contains(ext)) {
        setState(() => _fileError = 'Choose a PDF or an image (JPEG, PNG, WebP, HEIC).');
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > AppConfig.maxUploadBytes) {
        setState(() => _fileError = 'File must be ${AppConfig.maxUploadBytes ~/ (1024 * 1024)} MB or smaller.');
        return;
      }
      if (bytes.isEmpty) {
        setState(() => _fileError = 'The selected file is empty.');
        return;
      }
      setState(() {
        _bytes = bytes;
        _filename = file.name;
        _fileError = null;
      });
    } catch (_) {
      if (mounted) showToast(context, "Couldn't open the file picker. Please try again.", error: true);
    }
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    if (_bytes == null) setState(() => _fileError = 'Choose the report file to upload.');
    setState(() => _categoryError = _categories.isEmpty ? 'Choose at least one report type.' : null);
    if (!valid || _bytes == null || _categories.isEmpty) return;
    try {
      if (widget.asAdmin) {
        final code = await ref.read(reportRepositoryProvider).adminUpload(
              widget.patientId,
              categories: _categories,
              reportDate: _reportDate!,
              description: _description.text,
              bytes: _bytes!,
              filename: _filename!,
            );
        if (!mounted) return;
        showToast(context, 'Report $code added to the patient\'s record');
        context.pop();
        return;
      }
      final report = await ref.read(reportRepositoryProvider).upload(
            widget.patientId,
            categories: _categories,
            reportDate: _reportDate!,
            description: _description.text,
            bytes: _bytes!,
            filename: _filename!,
          );
      ref.invalidate(reportsControllerProvider);
      patientDataChanged(ref, widget.patientId);  // dashboard, timeline and values read from it
      if (!mounted) return;
      showToast(context, 'Report uploaded');
      context.pushReplacement('/r/${widget.patientId}/reports/${report.id}');
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'Upload Report',
      body: Form(
        key: _form,
        child: PageBody(maxWidth: 640, children: [
          LabeledField(
            label: 'What type of report is this?',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Choose every type it covers. A full body checkup, for example, can also include HbA1c.', style: t.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                for (final c in ReportCategory.values)
                  FilterChip(
                    label: Text(c.label),
                    selected: _categories.contains(c),
                    onSelected: (on) => setState(() {
                      on ? _categories.add(c) : _categories.remove(c);
                      if (_categories.isNotEmpty) _categoryError = null;
                    }),
                  ),
              ]),
              if (_categoryError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_categoryError!, style: t.bodySmall?.copyWith(color: AppColors.error))),
            ]),
          ),
          DateTimeField(
            label: 'Report date',
            value: _reportDate,
            onChanged: (d) => setState(() => _reportDate = d),
            helper: 'The date on the report itself (when the test was done), not today. Older reports are welcome.',
            validator: (d) => Validators.notFuture(d, 'Report date'),
          ),
          LabeledField(
            label: 'Report file',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppCard(
                onTap: _pick,
                child: Row(children: [
                  Icon(_bytes == null ? Icons.upload_file_outlined : Icons.check_circle_outline, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_filename ?? 'Choose file', style: t.titleSmall, overflow: TextOverflow.ellipsis),
                      Text(_bytes == null ? 'PDF, JPEG, PNG, WebP or HEIC, up to 20 MB' : Fmt.fileSize(_bytes!.length), style: t.bodySmall),
                    ]),
                  ),
                  if (_bytes != null) const Text('Change', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
              if (_fileError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_fileError!, style: t.bodySmall?.copyWith(color: AppColors.error))),
              const SizedBox(height: 6),
              Text('Your original file is stored securely and always stays available, even if AI features are unavailable.', style: t.bodySmall),
            ]),
          ),
          AppTextField(label: 'Description', controller: _description, optional: true, maxLines: 3, helper: 'For example the lab name or why the test was done.', validator: (v) => (v?.length ?? 0) > 1000 ? 'Keep the description under 1000 characters.' : null),
          const SizedBox(height: AppSpacing.sm),
          BusyButton(label: 'Upload Report', onPressed: _submit, expand: true),
        ]),
      ),
    );
  }
}
