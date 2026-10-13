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
import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(assessmentProvider(assessmentId));
    final t = Theme.of(context).textTheme;
    return AppPage(
      // ScreeningWording's clinical headline/disclaimer stay English: a retired, read-only
      // model whose wording is also asserted byte-for-byte in models_test.dart.
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
              Text(l10n.commonRecordLabel, style: t.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              KeyValueRow(l10n.assessmentIdLabel, a.assessmentCode),
              KeyValueRow(l10n.commonDateColumnLabel, Fmt.date(a.assessedAt)),
              KeyValueRow(l10n.commonTimeLabel, Fmt.time(a.assessedAt)),
              if (a.modelName != null) KeyValueRow(l10n.commonModelLabel, a.modelName!),
              KeyValueRow(l10n.commonModelVersionLabel, a.modelVersion),
              if (a.performedByRole != null) KeyValueRow(l10n.commonEnteredByLabel, Fmt.titleCase(a.performedByRole!)),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.modelInputsHeader, style: t.titleMedium),
              Text(l10n.sixteenAnswersNote, style: t.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              for (final e in a.inputs.entries) KeyValueRow(e.key, '${e.value ?? '—'}'),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SnapshotCard(snapshot: a.lifestyleSnapshot),
          const SizedBox(height: AppSpacing.lg),
          AiSummarySection(
            title: l10n.aiInterpretationTitle,
            value: AsyncData(a.interpretation),
            emptyMessage: l10n.aiInterpretationEmptyMessage,
            generateLabel: l10n.generateInterpretationButton,
            loadingMessage: l10n.analyzingLifestylePatternsMessage,
            failureReassurance: l10n.assessmentResultSafeMessage,
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
    final l10n = AppLocalizations.of(context);
    final rows = <Widget>[];
    for (final metric in LifestyleMetricType.values) {
      final m = snapshot[metric.apiValue];
      if (m is Map && m['average_7d'] != null) {
        rows.add(KeyValueRow(metric.label, l10n.metricAverageDays(metric.format((m['average_7d'] as num).toDouble()), '${m['days_recorded_7d']}')));
      }
    }
    final g = snapshot['glucose'];
    if (g is Map && g['recent_average_7d'] != null) rows.add(KeyValueRow(l10n.navGlucose, l10n.glucoseAverageReadings('${g['recent_average_7d']}', '${g['readings_7d']}')));
    final f = snapshot['food'];
    if (f is Map) rows.add(KeyValueRow(l10n.navFoodLog, l10n.foodEntriesOverDays('${f['entries_7d']}', '${f['days_logged_7d']}')));
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.lifestyleSnapshotHeader, style: t.titleMedium),
        Text(l10n.last7DaysBeforeAssessmentNote, style: t.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        if (rows.isEmpty) Text(l10n.noLifestyleDataAtTime, style: t.bodyMedium) else ...rows,
      ]),
    );
  }
}
