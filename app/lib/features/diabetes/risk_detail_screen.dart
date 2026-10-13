import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/user.dart';
import '../../l10n/app_localizations.dart';
import '../authentication/auth_controller.dart';
import 'diabetes_providers.dart';
import 'risk_widgets.dart';

/// One stored estimate exactly as it was made: the result, the data it used, what was missing
/// at the time, and (for doctors and admins) the values sent to the model.
class RiskDetailScreen extends ConsumerWidget {
  const RiskDetailScreen({super.key, required this.patientId, required this.assessmentId});
  final String patientId;
  final String assessmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(riskAssessmentProvider(assessmentId));
    final role = ref.watch(currentUserProvider)?.role;
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: l10n.riskEstimateTitle,
      body: AsyncBody(
        value: value,
        onRetry: () => ref.invalidate(riskAssessmentProvider(assessmentId)),
        data: (a) => PageBody(maxWidth: 860, children: [
          HeroPanel(child: RiskResultBlock(assessment: a)),
          if (a.warning != null) ...[const SizedBox(height: AppSpacing.md), RiskWarningNote(a.warning!)],
          const SizedBox(height: AppSpacing.section),
          SectionHeader(l10n.riskDetailDataUsedHeader, subtitle: l10n.riskDetailDataUsedSubtitleEstimate),
          DataUsedCard(data: a.dataUsed),
          if (a.dataUsed.missing.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.section),
            SectionHeader(l10n.riskDetailNotAvailableHeader, subtitle: l10n.riskDetailNotAssumedSubtitleEstimate),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final m in a.dataUsed.missing) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.xs), child: Text('${m.label} — ${m.reason}', style: t.bodySmall)),
              ]),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.commonRecordLabel, style: t.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (a.code != null) KeyValueRow(l10n.assessmentIdLabel, a.code!),
              KeyValueRow(l10n.commonMadeLabel, Fmt.dateTime(a.createdAt)),
              if (a.performedByRole != null) KeyValueRow(l10n.commonRequestedByLabel, Fmt.titleCase(a.performedByRole!)),
              KeyValueRow(l10n.commonModelVersionLabel, a.modelVersion),
              KeyValueRow(l10n.riskBandsLabel, a.riskThresholds.entries.map((e) => '${Fmt.titleCase(e.key)} ${e.value}').join(', ')),
              if (a.predictionThreshold != null) KeyValueRow(l10n.riskPatternThresholdLabel, a.predictionThreshold!),
              if (a.bmi != null) KeyValueRow(l10n.bmiCalculatedByModelLabel, a.bmi!.toStringAsFixed(1)),
            ]),
          ),
          if (role == UserRole.doctor || role == UserRole.admin) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.valuesSentToModelLabel, style: t.titleMedium),
                Text(l10n.modelInputFieldsNote, style: t.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                for (final e in a.inputFeatures.entries) KeyValueRow(e.key, '${e.value}'),
              ]),
            ),
          ],
          const RiskSafetyNote(),
        ]),
      ),
    );
  }
}
