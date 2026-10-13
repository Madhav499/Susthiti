import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../ai/ai_summary_section.dart';
import 'reports_providers.dart';

/// "What does the patient's collection of reports show over time?" (separate from the
/// individual report summary).
class AllReportsSummaryScreen extends ConsumerWidget {
  const AllReportsSummaryScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(allReportsSummaryProvider(patientId));
    final count = value.value?.reportCount ?? 0;
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: l10n.allReportsSummaryTitle,
      body: PageBody(maxWidth: 820, children: [
        AppCard(
          tinted: true,
          child: Text(
            l10n.allReportsSummaryDisclaimer,
            style: t.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AiSummarySection(
          title: l10n.combinedReportSummaryTitle,
          value: value.whenData((v) => v.summary),
          emptyMessage: l10n.combinedSummaryEmptyMessage(count),
          canGenerate: count >= 2,
          cannotGenerateReason: l10n.needTwoReportsReason,
          generateLabel: l10n.generateAllReportsSummaryButton,
          loadingMessage: l10n.reviewingHistoricalReportsMessage,
          failureReassurance: l10n.originalReportsSafeMessage,
          onGenerate: () => ref.read(aiRepositoryProvider).reports.generateAllReports(patientId),
          onGenerated: () => ref.invalidate(allReportsSummaryProvider(patientId)),
        ),
      ]),
    );
  }
}
