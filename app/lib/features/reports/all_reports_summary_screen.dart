import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';
import '../ai/ai_summary_section.dart';
import 'reports_providers.dart';

/// "What does the patient's collection of reports show over time?" (separate from the
/// individual report summary).
class AllReportsSummaryScreen extends ConsumerWidget {
  const AllReportsSummaryScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(allReportsSummaryProvider(patientId));
    final count = value.value?.reportCount ?? 0;
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'All Reports Summary',
      body: PageBody(maxWidth: 820, children: [
        AppCard(
          tinted: true,
          child: Text(
            'This summary reviews your authorized report history together, in order of report date, and only describes trends that the reports actually support. '
            'For what a single report says, open that report and use its AI Summary.',
            style: t.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AiSummarySection(
          title: 'Combined report summary',
          value: value.whenData((v) => v.summary),
          emptyMessage: 'No combined summary generated yet. $count report${count == 1 ? '' : 's'} available.',
          canGenerate: count >= 2,
          cannotGenerateReason: 'At least two reports are needed to look at changes over time.',
          generateLabel: 'Generate All Reports Summary',
          loadingMessage: 'Reviewing historical reports...',
          failureReassurance: 'Your original reports are still safely available.',
          onGenerate: () => ref.read(aiRepositoryProvider).reports.generateAllReports(patientId),
          onGenerated: () => ref.invalidate(allReportsSummaryProvider(patientId)),
        ),
      ]),
    );
  }
}
