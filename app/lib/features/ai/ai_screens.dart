import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../data/models/ai_summary.dart';
import '../../data/providers.dart';
import 'ai_summary_section.dart';

final patientSummaryProvider = FutureProvider.autoDispose.family<AISummary?, String>((ref, pid) => ref.watch(aiRepositoryProvider).patient.latest(pid));
final lifestyleInsightProvider = FutureProvider.autoDispose.family<AISummary?, String>((ref, pid) => ref.watch(aiRepositoryProvider).lifestyle.latestInsight(pid));

/// AI Patient Summary: a longitudinal overview of the authorized record. Separate from the
/// report summaries and the lifestyle insight.
class PatientSummaryView extends ConsumerWidget {
  const PatientSummaryView({super.key, required this.patientId, this.embedded = false});
  final String patientId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageBody(
      maxWidth: 820,
      padding: embedded ? const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xxl) : null,
      onRefresh: () async => ref.invalidate(patientSummaryProvider(patientId)),
      children: [
        AiSummarySection(
          title: 'AI Patient Summary',
          value: ref.watch(patientSummaryProvider(patientId)),
          onGenerate: () => ref.read(aiRepositoryProvider).patient.generate(patientId),
          onGenerated: () => ref.invalidate(patientSummaryProvider(patientId)),
          loadingMessage: 'Reviewing assessments, reports, glucose, lifestyle and care history...',
          emptyMessage: 'No patient summary yet. Generate one to see an overview of the recorded history.',
          generateLabel: 'Generate Patient Summary',
          failureReassurance: 'All original records are unchanged and still available.',
        ),
        const Disclaimer(),
      ],
    );
  }
}

class PatientSummaryScreen extends StatelessWidget {
  const PatientSummaryScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context) => AppPage(title: 'AI Patient Summary', body: PatientSummaryView(patientId: patientId));
}

/// Lifestyle AI: suggestions from recorded activity, sleep, food and glucose. Never prescribes.
class LifestyleInsightScreen extends ConsumerWidget {
  const LifestyleInsightScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      title: 'Lifestyle Insight',
      body: PageBody(
        maxWidth: 820,
        onRefresh: () async => ref.invalidate(lifestyleInsightProvider(patientId)),
        children: [
          AiSummarySection(
            title: 'Lifestyle Insight',
            value: ref.watch(lifestyleInsightProvider(patientId)),
            onGenerate: () => ref.read(aiRepositoryProvider).lifestyle.generateInsight(patientId),
            onGenerated: () => ref.invalidate(lifestyleInsightProvider(patientId)),
            loadingMessage: 'Looking at your recent activity, sleep, food and glucose...',
            emptyMessage: 'Get gentle, practical suggestions based on what you have recorded.',
            generateLabel: 'Generate Insight',
            failureReassurance: 'Your recorded lifestyle data is unchanged.',
          ),
          const Disclaimer(),
        ],
      ),
    );
  }
}
