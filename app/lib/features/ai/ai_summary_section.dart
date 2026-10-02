import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/ai_summary.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../authentication/auth_controller.dart';

/// Shared AI block: stored summary (never regenerated on view), explicit Generate /
/// Regenerate, calm loading copy, and failures that reassure the source data is safe.
class AiSummarySection extends ConsumerStatefulWidget {
  const AiSummarySection({
    super.key,
    required this.title,
    required this.value,
    required this.onGenerate,
    required this.onGenerated,
    required this.loadingMessage,
    required this.emptyMessage,
    this.generateLabel = 'Generate Summary',
    this.failureReassurance = 'Your original medical information is still available.',
    this.canGenerate = true,
    this.cannotGenerateReason,
  });

  final String title;
  final AsyncValue<AISummary?> value;
  final Future<AISummary> Function() onGenerate;
  final VoidCallback onGenerated;
  final String loadingMessage;
  final String emptyMessage;
  final String generateLabel;
  final String failureReassurance;
  final bool canGenerate;
  final String? cannotGenerateReason;

  @override
  ConsumerState<AiSummarySection> createState() => _AiSummarySectionState();
}

class _AiSummarySectionState extends ConsumerState<AiSummarySection> {
  bool _generating = false;
  Object? _error;

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      await widget.onGenerate();
      widget.onGenerated();
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _downloadPdf(AISummary s) async {
    try {
      await ref.read(pdfServiceProvider).download(s);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _viewPdf(AISummary s) async {
    try {
      await ref.read(pdfServiceProvider).view(s);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  /// Admins read AI summaries but never generate them (the backend refuses it too).
  bool get _canGenerate => widget.canGenerate && ref.watch(currentUserProvider)?.role != UserRole.admin;

  String? get _cannotGenerateReason => ref.watch(currentUserProvider)?.role == UserRole.admin
      ? 'No AI summary has been generated for this record. Administrators can view AI summaries but cannot generate them.'
      : widget.cannotGenerateReason;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.title, style: t.titleMedium)),
          const AiLabel(),
        ]),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(duration: AppDurations.normal, child: _body(context)),
      ]),
    );
  }

  Widget _body(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (_generating) {
      return Semantics(
        key: const ValueKey('generating'),
        liveRegion: true,
        label: widget.loadingMessage,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Row(children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(widget.loadingMessage, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))),
          ]),
        ),
      );
    }
    if (_error != null) {
      final failure = asFailure(_error!);
      final notConfigured = failure is AIServiceFailure && failure.notConfigured;
      return Column(key: const ValueKey('error'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(notConfigured ? 'AI features are not set up on this server yet.' : "We couldn't generate the summary right now.", style: t.titleSmall),
        const SizedBox(height: 4),
        Text(widget.failureReassurance, style: t.bodyMedium?.copyWith(color: AppColors.primary)),
        if (!notConfigured) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(onPressed: _generate, icon: const Icon(Icons.refresh), label: const Text('Try Again')),
        ],
      ]);
    }
    return widget.value.when(
      skipLoadingOnRefresh: true,
      loading: () => const Column(key: ValueKey('loading'), children: [Skeleton(height: 14), SizedBox(height: 8), Skeleton(height: 14, width: 220)]),
      error: (e, _) => ErrorState(key: const ValueKey('load-error'), error: e, compact: true, onRetry: widget.onGenerated, reassurance: widget.failureReassurance),
      data: (summary) {
        if (summary == null) {
          return Column(key: const ValueKey('empty'), crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_canGenerate ? widget.emptyMessage : (_cannotGenerateReason ?? widget.emptyMessage), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            if (_canGenerate) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(onPressed: _generate, icon: const Icon(Icons.auto_awesome_outlined), label: Text(widget.generateLabel)),
            ],
          ]);
        }
        return Column(key: ValueKey(summary.id), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (summary.isStale)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: AppRadius.controlBorder),
                child: Row(children: [
                  const Icon(Icons.history_outlined, size: 18, color: AppColors.warningText),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('New information has been added since this summary was generated. It may no longer reflect the current records.', style: t.bodySmall?.copyWith(color: AppColors.warningText))),
                ]),
              ),
            ),
          AiSummaryContent(summary),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Text('Generated ${Fmt.dateTime(summary.generatedAt)}${summary.generatedByRole != null ? ' by ${summary.generatedByRole}' : ''}', style: t.bodySmall),
          if (summary.basedOn.isNotEmpty) Text('Based on: ${summary.basedOn.join(', ')}', style: t.bodySmall),
          Text('AI model: ${summary.model}', style: t.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Text(summary.disclaimer, style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: AppSpacing.lg),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            OutlinedButton.icon(onPressed: () => _viewPdf(summary), icon: const Icon(Icons.visibility_outlined), label: const Text('View PDF')),
            FilledButton.icon(onPressed: () => _downloadPdf(summary), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Download PDF')),
            if (_canGenerate) TextButton.icon(onPressed: _generate, icon: const Icon(Icons.refresh), label: const Text('Regenerate')),
          ]),
        ]);
      },
    );
  }
}

/// Structured rendering of each AI output shape. Interpretation is always visually separated
/// from observed information.
class AiSummaryContent extends StatelessWidget {
  const AiSummaryContent(this.s, {super.key});
  final AISummary s;

  @override
  Widget build(BuildContext context) {
    final blocks = switch (s.kind) {
      AISummaryKind.individualReport => [
          _para(context, null, s.text('summary')),
          _para(context, 'Report information', s.text('report_information')),
          _bullets(context, 'Key findings', s.list('key_findings')),
          _values(context, s.maps('relevant_values')),
          _bullets(context, 'Observed information', s.list('observed_trends')),
          _interpretation(context, s.text('interpretation')),
          _bullets(context, 'Questions to discuss', s.list('questions_for_doctor')),
          _bullets(context, 'Limitations', s.list('limitations')),
        ],
      AISummaryKind.allReports => [
          _para(context, null, s.text('summary')),
          _trends(context, s.maps('observed_trends')),
          _bullets(context, 'Key findings', s.list('key_findings')),
          _bullets(context, 'Not enough information to compare', s.list('gaps')),
          _interpretation(context, s.text('interpretation')),
          _bullets(context, 'Questions to discuss', s.list('questions_for_doctor')),
        ],
      AISummaryKind.patientSummary => [
          for (final (key, label) in const [
            ('patient_overview', 'Patient Overview'),
            ('diabetes_history', 'Diabetes History'),
            ('recent_assessments', 'Recent Assessments'),
            ('medical_reports', 'Medical Reports'),
            ('relevant_trends', 'Relevant Trends'),
            ('glucose_history', 'Glucose History'),
            ('lifestyle_trends', 'Lifestyle Trends'),
            ('medication_history', 'Medication / Prescription History'),
            ('side_effects', 'Side Effects'),
            ('doctor_visits', 'Doctor Visits'),
            ('recent_developments', 'Recent Developments'),
          ])
            _para(context, label, s.text(key)),
          _bullets(context, 'Items to Discuss With Patient', s.list('items_to_discuss')),
          _interpretation(context, s.text('interpretation')),
        ],
      AISummaryKind.lifestyle => [
          _para(context, null, s.text('headline')),
          _overview(context, Map<String, dynamic>.from(s.content['overview'] as Map? ?? const {})),
          _bullets(context, 'Observations', s.list('observations')),
          _numbered(context, 'AI Suggestions', s.list('suggestions')),
          _interpretation(context, s.text('interpretation')),
        ],
      AISummaryKind.assessmentInterpretation => [
          _para(context, null, s.text('interpretation')),
          _bullets(context, 'Patterns considered', s.list('contributing_patterns')),
          _numbered(context, 'Suggestions', s.list('suggestions')),
        ],
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final b in blocks) ?b]);
  }

  static Widget _heading(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
        child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleSmall)),
      );

  Widget? _para(BuildContext context, String? label, String text) {
    if (text.isEmpty) return null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null) _heading(context, label),
      Text(text, style: Theme.of(context).textTheme.bodyMedium),
    ]);
  }

  Widget? _bullets(BuildContext context, String label, List<String> items) {
    if (items.isEmpty) return null;
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading(context, label),
      for (final i in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 8, right: 10), child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle))),
            Expanded(child: Text(i, style: t.bodyMedium)),
          ]),
        ),
    ]);
  }

  Widget? _numbered(BuildContext context, String label, List<String> items) {
    if (items.isEmpty) return null;
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading(context, label),
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 22, child: Text('${i + 1}.', style: t.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600))),
            Expanded(child: Text(items[i], style: t.bodyMedium)),
          ]),
        ),
    ]);
  }

  Widget? _interpretation(BuildContext context, String text) {
    if (text.isEmpty) return null;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.controlBorder),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AI interpretation', style: t.labelMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(text, style: t.bodyMedium),
        ]),
      ),
    );
  }

  Widget? _values(BuildContext context, List<Map<String, dynamic>> values) {
    if (values.isEmpty) return null;
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading(context, 'Relevant values'),
      for (final v in values)
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: Text('${v['name']}', style: t.bodyMedium)),
            Expanded(
              flex: 3,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${v['value']} ${v['unit'] ?? ''}'.trim(), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (v['reference_range'] != null) Text('Reference ${v['reference_range']}', style: t.bodySmall),
                if (v['note'] != null) Text('${v['note']}', style: t.bodySmall),
              ]),
            ),
          ]),
        ),
    ]);
  }

  Widget? _trends(BuildContext context, List<Map<String, dynamic>> trends) {
    if (trends.isEmpty) return null;
    final t = Theme.of(context).textTheme;
    String point(Object? p) {
      if (p is! Map) return '—';
      final date = p['date'] != null ? ' (${p['date']})' : '';
      return '${p['value']}$date';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading(context, 'Observed trends'),
      for (final tr in trends)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tr['parameter']}', style: t.titleSmall),
              const SizedBox(height: 6),
              KeyValueRow('Earlier', point(tr['earlier'])),
              KeyValueRow('Latest', point(tr['latest'])),
              KeyValueRow('Observed change', '${tr['observed_change'] ?? '—'}'),
            ]),
          ),
        ),
    ]);
  }

  Widget? _overview(BuildContext context, Map<String, dynamic> overview) {
    final rows = [for (final e in overview.entries) if ((e.value as String? ?? '').isNotEmpty) KeyValueRow(Fmt.titleCase(e.key), e.value as String)];
    if (rows.isEmpty) return null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_heading(context, 'Lifestyle Overview'), ...rows]);
  }
}
