import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/diabetes_risk.dart';
import '../../data/models/user.dart';

/// "Moderate risk", coloured by band. Bands and category come from the API, never from the app.
class RiskCategoryPill extends StatelessWidget {
  const RiskCategoryPill(this.category, {super.key});
  final String category;

  @override
  Widget build(BuildContext context) => StatusPill(RiskWording.categoryLabel(category), tone: RiskWording.tone(category));
}

/// The headline of one assessment: model-estimated risk, category, basis and when.
class RiskResultBlock extends StatelessWidget {
  const RiskResultBlock({super.key, required this.assessment, this.actions = const []});
  final RiskAssessment assessment;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = assessment;
    return Semantics(
      container: true,
      label: '${RiskWording.title}: ${RiskWording.estimateLabel.toLowerCase()} ${a.percentLabel}, ${RiskWording.categoryLabel(a.riskCategory)}. ${a.basisText}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(RiskWording.title, style: t.labelLarge?.copyWith(color: AppColors.primaryDeep))),
          RiskCategoryPill(a.riskCategory),
        ]),
        const SizedBox(height: AppSpacing.sm),
        ExcludeSemantics(
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(a.percentLabel, style: t.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: Text(RiskWording.estimateLabel, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))),
          ]),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Risk pattern: ${a.predictionLabel}', style: t.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        _BasisLine(assessment: a),
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

class _BasisLine extends StatelessWidget {
  const _BasisLine({required this.assessment});
  final RiskAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final withReport = assessment.reportAvailable;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(withReport ? Icons.description_outlined : Icons.person_outline, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(assessment.basisText, style: t.bodyMedium)),
    ]);
  }
}

/// The API's own warning for this result (e.g. that a no-report estimate is not fully trusted).
class RiskWarningNote extends StatelessWidget {
  const RiskWarningNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return ToneCard(
      tone: StatusTone.attention,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, color: StatusTone.attention.foreground, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: StatusTone.attention.foreground))),
      ]),
    );
  }
}

/// Shown when the patient's health data changed after the latest estimate.
class StaleBanner extends StatelessWidget {
  const StaleBanner({super.key, required this.reasons, this.offline = false, this.onRefresh});
  final List<String> reasons;
  final bool offline;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tone = StatusTone.info;
    return ToneCard(
      tone: tone,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.update, color: tone.foreground),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text('Updated health information is available.', style: t.titleSmall?.copyWith(color: tone.foreground))),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text(
          offline
              ? 'New health information is available. Connect to the internet to update your assessment.'
              : 'The estimate above doesn\'t include it yet. Refresh your diabetes risk assessment to use your latest information.',
          style: t.bodyMedium,
        ),
        for (final r in reasons)
          Padding(padding: const EdgeInsets.only(top: AppSpacing.xs), child: Text('• $r', style: t.bodySmall)),
        if (onRefresh != null && !offline) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Update with my latest data')),
        ],
      ]),
    );
  }
}

class OfflineRiskBanner extends StatelessWidget {
  const OfflineRiskBanner({super.key, this.lastUpdated});
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    return ToneCard(
      tone: StatusTone.inactive,
      child: Row(children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            lastUpdated == null
                ? 'You\'re offline. Showing the information saved on this device.'
                : 'You\'re offline. Showing your last assessment, updated ${Fmt.relative(lastUpdated)}. Newer health information isn\'t included until you\'re back online.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ]),
    );
  }
}

/// Which health information an assessment used, grouped by where it came from.
class DataUsedCard extends StatelessWidget {
  const DataUsedCard({super.key, required this.data});
  final DataUsed data;

  static IconData iconFor(String group) => switch (group) {
        'profile' => Icons.badge_outlined,
        'medical_history' => Icons.history_edu_outlined,
        'report' => Icons.description_outlined,
        'lifestyle' => Icons.self_improvement_outlined,
        'wearable' => Icons.watch_outlined,
        'symptoms' => Icons.sick_outlined,
        _ => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (data.groups.isEmpty) {
      return AppCard(child: Text('No health information was available yet beyond what the model requires.', style: t.bodyMedium));
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var g = 0; g < data.groups.length; g++) ...[
          if (g > 0) const Divider(height: AppSpacing.xl),
          Row(children: [
            Icon(iconFor(data.groups[g].key), size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(data.groups[g].label, style: t.titleSmall),
          ]),
          const SizedBox(height: AppSpacing.sm),
          for (final item in data.groups[g].items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check_circle, size: 16, color: AppColors.success)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${item.label}: ${item.value}', style: t.bodyMedium),
                    if (item.detail != null) Text(item.detail!, style: t.bodySmall),
                  ]),
                ),
              ]),
            ),
        ],
      ]),
    );
  }
}

/// Where a viewer can add missing information (null: nowhere for this viewer).
String? addDataRoute(AddDataTarget target, String patientId, UserRole? role) {
  if (role == null || role == UserRole.admin) return null;
  final patient = role == UserRole.patient;
  return switch (target) {
    AddDataTarget.profile => patient ? '/p/profile' : null,
    AddDataTarget.healthProfile => '/r/$patientId/health-profile',
    AddDataTarget.reportValues => '/r/$patientId/reports',
    AddDataTarget.healthConnection => patient ? '/p/devices' : null,
  };
}

String addDataLabel(AddDataTarget target) => switch (target) {
      AddDataTarget.profile => 'Update profile',
      AddDataTarget.healthProfile => 'Open health profile',
      AddDataTarget.reportValues => 'Add values from a report',
      AddDataTarget.healthConnection => 'Connect health data',
    };

/// Information the estimate could use but doesn't have, and where to add it. Nothing is guessed.
class MissingDataCard extends StatelessWidget {
  const MissingDataCard({super.key, required this.missing, required this.patientId, required this.role});
  final List<MissingItem> missing;
  final String patientId;
  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final byGroup = <String, List<MissingItem>>{};
    for (final m in missing) {
      byGroup.putIfAbsent(m.groupLabel, () => []).add(m);
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final entry in byGroup.entries) ...[
          Text(entry.key, style: t.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final m in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.radio_button_unchecked, size: 16, color: AppColors.inactive)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('${m.label} — ${m.reason}', style: t.bodySmall)),
              ]),
            ),
          Builder(builder: (context) {
            final targets = {for (final m in entry.value) m.target};
            final links = [
              for (final target in targets)
                if (addDataRoute(target, patientId, role) case final route?) TextButton(onPressed: () => context.push(route), child: Text(addDataLabel(target))),
            ];
            return links.isEmpty ? const SizedBox(height: AppSpacing.sm) : Wrap(spacing: AppSpacing.sm, children: links);
          }),
        ],
      ]),
    );
  }
}

class RiskHistoryList extends StatelessWidget {
  const RiskHistoryList({super.key, required this.items, required this.patientId});
  final List<RiskAssessment> items;
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
            onTap: () => context.push('/r/$patientId/diabetes-risk/${items[i].id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${Fmt.date(items[i].createdAt)} · ${items[i].percentLabel}', style: t.titleSmall),
                    Text(items[i].reportAvailable ? 'Included medical report values' : 'Symptoms and risk factors only', style: t.bodySmall),
                  ]),
                ),
                RiskCategoryPill(items[i].riskCategory),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

/// A card tinted with a status tone (notices and banners).
class ToneCard extends StatelessWidget {
  const ToneCard({super.key, required this.tone, required this.child});
  final StatusTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: tone.background, borderRadius: AppRadius.cardBorder),
      child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: child),
    );
  }
}

class RiskSafetyNote extends StatelessWidget {
  const RiskSafetyNote({super.key});

  @override
  Widget build(BuildContext context) => const Disclaimer(text: RiskWording.safety);
}
