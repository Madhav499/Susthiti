import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/heart_risk.dart';
import '../diabetes/risk_widgets.dart' show RiskWarningNote, ToneCard;

/// "Moderate risk signal", coloured by band. Bands come from the API, never from the app.
/// Deliberately never says "diagnosis" or "you have heart disease" -- see HeartWording.
class HeartRiskLevelPill extends StatelessWidget {
  const HeartRiskLevelPill(this.riskLevel, {super.key});
  final String riskLevel;

  @override
  Widget build(BuildContext context) => StatusPill(HeartWording.signalLabel(riskLevel), tone: HeartWording.tone(riskLevel));
}

/// The headline of one screening: model score, risk signal, basis and when. Mirrors
/// RiskResultBlock (diabetes) in shape, with heart-appropriate, non-diagnostic wording.
class HeartResultBlock extends StatelessWidget {
  const HeartResultBlock({super.key, required this.assessment, this.actions = const []});
  final HeartRiskAssessment assessment;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = assessment;
    return Semantics(
      container: true,
      label: '${HeartWording.title}: ${a.signalLabel}, ${a.percentLabel} model score. ${a.basisText}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(HeartWording.title, style: t.labelLarge?.copyWith(color: AppColors.primaryDeep))),
          HeartRiskLevelPill(a.riskLevel),
        ]),
        const SizedBox(height: AppSpacing.sm),
        ExcludeSemantics(
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(a.percentLabel, style: t.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: Text(HeartWording.estimateLabel, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))),
          ]),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(a.signalLabel, style: t.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(a.reportAvailable ? Icons.description_outlined : Icons.person_outline, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(a.basisText, style: t.bodyMedium)),
        ]),
        const SizedBox(height: AppSpacing.xs),
        Text('Last updated ${Fmt.relative(a.createdAt)} · ${Fmt.dateTime(a.createdAt)}', style: t.bodySmall),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: actions),
        ],
      ]),
    );
  }
}

/// Shown when the patient's health data changed after the latest screening.
class HeartStaleBanner extends StatelessWidget {
  const HeartStaleBanner({super.key, required this.reasons, this.onRefresh});
  final List<String> reasons;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const tone = StatusTone.info;
    return ToneCard(
      tone: tone,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.update, color: tone.foreground),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text('Updated health information is available.', style: t.titleSmall?.copyWith(color: tone.foreground))),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text('The screening above doesn\'t include it yet. Refresh your heart risk screening to use your latest information.', style: t.bodyMedium),
        for (final r in reasons) Padding(padding: const EdgeInsets.only(top: AppSpacing.xs), child: Text('• $r', style: t.bodySmall)),
        if (onRefresh != null) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Update with my latest data')),
        ],
      ]),
    );
  }
}

class HeartRiskHistoryList extends StatelessWidget {
  const HeartRiskHistoryList({super.key, required this.items, required this.patientId});
  final List<HeartRiskAssessment> items;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
          InkWell(
            onTap: () => context.push('/r/$patientId/heart-risk/${items[i].id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${Fmt.date(items[i].createdAt)} · ${items[i].percentLabel}', style: t.titleSmall),
                    Text(items[i].reportAvailable ? 'Included medical report values' : 'Symptoms and risk factors only', style: t.bodySmall),
                  ]),
                ),
                HeartRiskLevelPill(items[i].riskLevel),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class HeartSafetyNote extends StatelessWidget {
  const HeartSafetyNote({super.key});

  @override
  Widget build(BuildContext context) => const Disclaimer(text: HeartWording.safety);
}

/// One warning note per entry in the API's own `warnings` list (RiskWarningNote is generic).
class HeartWarningNotes extends StatelessWidget {
  const HeartWarningNotes(this.warnings, {super.key});
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < warnings.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.sm),
        RiskWarningNote(warnings[i]),
      ],
    ]);
  }
}
