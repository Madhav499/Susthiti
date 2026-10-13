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
import '../../l10n/app_localizations.dart';
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

  Future<void> _pick(AppLocalizations l10n) async {
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: _allowedExtensions, dialogTitle: l10n.uploadChooseReportDialogTitle);
      if (file == null) return;
      final ext = (file.extension ?? '').toLowerCase().replaceAll('.', '');
      if (!_allowedExtensions.contains(ext)) {
        setState(() => _fileError = l10n.uploadFileTypeError);
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > AppConfig.maxUploadBytes) {
        setState(() => _fileError = l10n.uploadFileTooLargeError('${AppConfig.maxUploadBytes ~/ (1024 * 1024)}'));
        return;
      }
      if (bytes.isEmpty) {
        setState(() => _fileError = l10n.uploadFileEmptyError);
        return;
      }
      setState(() {
        _bytes = bytes;
        _filename = file.name;
        _fileError = null;
      });
    } catch (_) {
      if (mounted) showToast(context, AppLocalizations.of(context).uploadPickerFailedToast, error: true);
    }
  }

  Future<void> _submit(AppLocalizations l10n) async {
    final valid = _form.currentState!.validate();
    if (_bytes == null) setState(() => _fileError = l10n.uploadChooseFileError);
    setState(() => _categoryError = _categories.isEmpty ? l10n.uploadChooseCategoryError : null);
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
        showToast(context, l10n.uploadAdminAddedToast(code));
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
      showToast(context, l10n.uploadReportUploadedToast);
      context.pushReplacement('/r/${widget.patientId}/reports/${report.id}');
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: l10n.dashUploadReport,
      body: Form(
        key: _form,
        child: PageBody(maxWidth: 640, children: [
          LabeledField(
            label: l10n.uploadReportTypeLabel,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.uploadReportTypeHelp, style: t.bodySmall),
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
            label: l10n.uploadReportDateLabel,
            value: _reportDate,
            onChanged: (d) => setState(() => _reportDate = d),
            helper: l10n.uploadReportDateHelper,
            validator: (d) => Validators.notFuture(l10n, d, l10n.uploadReportDateLabel),
          ),
          LabeledField(
            label: l10n.uploadReportFileLabel,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppCard(
                onTap: () => _pick(l10n),
                child: Row(children: [
                  Icon(_bytes == null ? Icons.upload_file_outlined : Icons.check_circle_outline, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_filename ?? l10n.uploadChooseFilePlaceholder, style: t.titleSmall, overflow: TextOverflow.ellipsis),
                      Text(_bytes == null ? l10n.uploadFileTypesHint : Fmt.fileSize(_bytes!.length), style: t.bodySmall),
                    ]),
                  ),
                  if (_bytes != null) Text(l10n.commonChange, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
              if (_fileError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_fileError!, style: t.bodySmall?.copyWith(color: AppColors.error))),
              const SizedBox(height: 6),
              Text(l10n.uploadFileStoredNote, style: t.bodySmall),
            ]),
          ),
          AppTextField(
            label: l10n.commonDescriptionLabel,
            controller: _description,
            optional: true,
            maxLines: 3,
            helper: l10n.uploadDescriptionHelper,
            validator: (v) => (v?.length ?? 0) > 1000 ? l10n.uploadDescriptionTooLong : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          BusyButton(label: l10n.dashUploadReport, onPressed: () => _submit(l10n), expand: true),
        ]),
      ),
    );
  }
}
