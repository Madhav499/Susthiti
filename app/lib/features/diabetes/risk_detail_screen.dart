import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/user.dart';
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
    final value = ref.watch(riskAssessmentProvider(assessmentId));
    final role = ref.watch(currentUserProvider)?.role;
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'Risk estimate',
      body: AsyncBody(
        value: value,
        onRetry: () => ref.invalidate(riskAssessmentProvider(assessmentId)),
        data: (a) => PageBody(maxWidth: 860, children: [
          HeroPanel(child: RiskResultBlock(assessment: a)),
          if (a.warning != null) ...[const SizedBox(height: AppSpacing.md), RiskWarningNote(a.warning!)],
          const SizedBox(height: AppSpacing.section),
          const SectionHeader('Data used', subtitle: 'As recorded when this estimate was made.'),
          DataUsedCard(data: a.dataUsed),
          if (a.dataUsed.missing.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.section),
            const SectionHeader('Not available at the time', subtitle: 'Left out of this estimate, not assumed.'),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final m in a.dataUsed.missing) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.xs), child: Text('${m.label} — ${m.reason}', style: t.bodySmall)),
              ]),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Record', style: t.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (a.code != null) KeyValueRow('Assessment ID', a.code!),
              KeyValueRow('Made', Fmt.dateTime(a.createdAt)),
              if (a.performedByRole != null) KeyValueRow('Requested by', Fmt.titleCase(a.performedByRole!)),
              KeyValueRow('Model version', a.modelVersion),
              KeyValueRow('Risk bands', a.riskThresholds.entries.map((e) => '${Fmt.titleCase(e.key)} ${e.value}').join(', ')),
              if (a.predictionThreshold != null) KeyValueRow('Risk pattern threshold', a.predictionThreshold!),
              if (a.bmi != null) KeyValueRow('BMI (calculated by the model service)', a.bmi!.toStringAsFixed(1)),
            ]),
          ),
          if (role == UserRole.doctor || role == UserRole.admin) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Values sent to the model', style: t.titleMedium),
                Text('Only the model\'s own input fields; unknown values were left out.', style: t.bodySmall),
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
