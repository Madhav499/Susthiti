import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../data/models/ai_summary.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import 'ai_summary_section.dart';

final patientSummaryProvider = FutureProvider.autoDispose.family<AISummary?, String>((ref, pid) => ref.watch(aiRepositoryProvider).patient.latest(pid));
final patientFriendlySummaryProvider = FutureProvider.autoDispose.family<AISummary?, String>((ref, pid) => ref.watch(aiRepositoryProvider).patient.latestFriendly(pid));
final lifestyleInsightProvider = FutureProvider.autoDispose.family<AISummary?, String>((ref, pid) => ref.watch(aiRepositoryProvider).lifestyle.latestInsight(pid));

/// AI Patient Summary: a longitudinal overview of the authorized record. Separate from the
/// report summaries and the lifestyle insight.
class PatientSummaryView extends ConsumerWidget {
  const PatientSummaryView({super.key, required this.patientId, this.embedded = false});
  final String patientId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PageBody(
      maxWidth: 820,
      padding: embedded ? const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xxl) : null,
      onRefresh: () async => ref.invalidate(patientSummaryProvider(patientId)),
      children: [
        AiSummarySection(
          title: l10n.aiPatientSummaryTitle,
          value: ref.watch(patientSummaryProvider(patientId)),
          onGenerate: () => ref.read(aiRepositoryProvider).patient.generate(patientId),
          onGenerated: () => ref.invalidate(patientSummaryProvider(patientId)),
          loadingMessage: l10n.aiPatientSummaryLoadingMessage,
          emptyMessage: l10n.aiPatientSummaryEmptyMessage,
          generateLabel: l10n.aiGeneratePatientSummaryButton,
          failureReassurance: l10n.aiOriginalRecordsUnchangedNote,
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
  Widget build(BuildContext context) => AppPage(title: AppLocalizations.of(context).aiPatientSummaryTitle, body: PatientSummaryView(patientId: patientId));
}

/// "Your Health Summary": the patient-facing counterpart to AI Patient Summary. A separate
/// AI generation (see PatientFriendlySummaryService), written in plain language, with no
/// clinical "view details" layer -- this is the whole thing, kept short.
class YourHealthSummaryScreen extends ConsumerWidget {
  const YourHealthSummaryScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: l10n.aiYourHealthSummaryTitle,
      body: PageBody(
        maxWidth: 820,
        onRefresh: () async => ref.invalidate(patientFriendlySummaryProvider(patientId)),
        children: [
          AiSummarySection(
            title: l10n.aiYourHealthSummaryTitle,
            value: ref.watch(patientFriendlySummaryProvider(patientId)),
            onGenerate: () => ref.read(aiRepositoryProvider).patient.generateFriendly(patientId),
            onGenerated: () => ref.invalidate(patientFriendlySummaryProvider(patientId)),
            loadingMessage: l10n.aiHealthSummaryLoadingMessage,
            emptyMessage: l10n.aiHealthSummaryEmptyMessage,
            generateLabel: l10n.aiGenerateSummaryButton,
            failureReassurance: l10n.aiYourRecordsUnchangedNote,
          ),
          const Disclaimer(),
        ],
      ),
    );
  }
}

/// Lifestyle AI: suggestions from recorded activity, sleep, food and glucose. Never prescribes.
class LifestyleInsightScreen extends ConsumerWidget {
  const LifestyleInsightScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: l10n.aiLifestyleInsightTitle,
      body: PageBody(
        maxWidth: 820,
        onRefresh: () async => ref.invalidate(lifestyleInsightProvider(patientId)),
        children: [
          AiSummarySection(
            title: l10n.aiLifestyleInsightTitle,
            value: ref.watch(lifestyleInsightProvider(patientId)),
            onGenerate: () => ref.read(aiRepositoryProvider).lifestyle.generateInsight(patientId),
            onGenerated: () => ref.invalidate(lifestyleInsightProvider(patientId)),
            loadingMessage: l10n.aiLifestyleLoadingMessage,
            emptyMessage: l10n.aiLifestyleEmptyMessage,
            generateLabel: l10n.aiGenerateInsightButton,
            failureReassurance: l10n.aiLifestyleUnchangedNote,
          ),
          const Disclaimer(),
        ],
      ),
    );
  }
}
