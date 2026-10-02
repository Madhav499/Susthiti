import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/diabetes.dart';
import '../../data/models/tracking.dart';
import '../../data/providers.dart';
import '../ai/ai_summary_section.dart';
import 'assessment_widgets.dart';
import 'diabetes_providers.dart';

/// An assessment from the earlier 16-question symptom model (retired, read-only history): all
/// inputs, the model output, lifestyle snapshot and the (separate) AI interpretation.
class AssessmentDetailScreen extends ConsumerWidget {
  const AssessmentDetailScreen({super.key, required this.assessmentId});
  final String assessmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(assessmentProvider(assessmentId));
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: ScreeningWording.resultTitle,
      body: AsyncBody(
        value: value,
        onRetry: () => ref.invalidate(assessmentProvider(assessmentId)),
        data: (a) => PageBody(maxWidth: 820, children: [
          HeroPanel(child: AssessmentResultBlock(assessment: a, onMeaning: () => showAssessmentMeaning(context))),
          const SizedBox(height: AppSpacing.lg),
          ResultMeaningCard(assessment: a),
          const SizedBox(height: AppSpacing.md),
          ResultDisclaimerCard(text: a.disclaimerText),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Record', style: t.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              KeyValueRow('Assessment ID', a.assessmentCode),
              KeyValueRow('Date', Fmt.date(a.assessedAt)),
              KeyValueRow('Time', Fmt.time(a.assessedAt)),
              if (a.modelName != null) KeyValueRow('Model', a.modelName!),
              KeyValueRow('Model version', a.modelVersion),
              if (a.performedByRole != null) KeyValueRow('Entered by', Fmt.titleCase(a.performedByRole!)),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Model inputs', style: t.titleMedium),
              Text('All 16 answers exactly as sent to the earlier model.', style: t.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              for (final e in a.inputs.entries) KeyValueRow(e.key, '${e.value ?? '—'}'),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SnapshotCard(snapshot: a.lifestyleSnapshot),
          const SizedBox(height: AppSpacing.lg),
          AiSummarySection(
            title: 'AI Interpretation',
            value: AsyncData(a.interpretation),
            emptyMessage: 'Combine this assessment with your recent lifestyle and glucose data for a calm, forward-looking explanation. This is an AI interpretation, not a new prediction.',
            generateLabel: 'Generate interpretation',
            loadingMessage: 'Analyzing lifestyle patterns...',
            failureReassurance: 'Your assessment result is still saved and unchanged.',
            onGenerate: () => ref.read(aiRepositoryProvider).lifestyle.interpretAssessment(a.id),
            onGenerated: () => ref.invalidate(assessmentProvider(assessmentId)),
          ),
          const Disclaimer(),
        ]),
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.snapshot});
  final Map<String, dynamic> snapshot;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = <Widget>[];
    for (final metric in LifestyleMetricType.values) {
      final m = snapshot[metric.apiValue];
      if (m is Map && m['average_7d'] != null) {
        rows.add(KeyValueRow(metric.label, '${metric.format((m['average_7d'] as num).toDouble())} average (${m['days_recorded_7d']} days)'));
      }
    }
    final g = snapshot['glucose'];
    if (g is Map && g['recent_average_7d'] != null) rows.add(KeyValueRow('Glucose', '${g['recent_average_7d']} mg/dL average (${g['readings_7d']} readings)'));
    final f = snapshot['food'];
    if (f is Map) rows.add(KeyValueRow('Food log', '${f['entries_7d']} entries over ${f['days_logged_7d']} days'));
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Lifestyle snapshot', style: t.titleMedium),
        Text('Recorded data from the 7 days before this assessment.', style: t.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        if (rows.isEmpty) Text('No lifestyle data was recorded at the time.', style: t.bodyMedium) else ...rows,
      ]),
    );
  }
}
