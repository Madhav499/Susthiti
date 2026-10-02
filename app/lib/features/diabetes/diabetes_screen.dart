import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/diabetes_risk.dart';
import '../../data/models/user.dart';
import '../authentication/auth_controller.dart';
import '../notifications/notifications.dart';
import 'diabetes_providers.dart';
import '../patient/patient_sync.dart';
import 'risk_widgets.dart';

class DiabetesScreen extends StatelessWidget {
  const DiabetesScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Diabetes',
      large: true,
      actions: const [NotificationBell()],
      body: DiabetesView(patientId: patientId, canAssess: true),
    );
  }
}

/// Future diabetes risk: the latest model-estimated risk, what it was based on, what's missing,
/// and the history. Used by patients, by doctors with access, and (read-only) by admins.
/// Nothing here runs the model; only "Refresh assessment" asks the backend to.
class DiabetesView extends ConsumerStatefulWidget {
  const DiabetesView({super.key, required this.patientId, this.canAssess = false, this.embedded = false});
  final String patientId;
  final bool canAssess;
  final bool embedded;

  @override
  ConsumerState<DiabetesView> createState() => _DiabetesViewState();
}

class _DiabetesViewState extends ConsumerState<DiabetesView> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final result = await refreshDiabetesRisk(ref, widget.patientId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.created
            ? 'Your future diabetes risk estimate has been updated.'
            : 'Nothing relevant has changed since your last estimate, so it is still current.'),
      ));
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(riskStatusProvider(widget.patientId));
    final role = ref.watch(currentUserProvider)?.role;
    return PageBody(
      maxWidth: 860,
      padding: widget.embedded ? const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xxl) : null,
      onRefresh: () async => ref.invalidate(riskStatusProvider(widget.patientId)),
      children: [
        AsyncBody(
          value: status,
          keepDataOnError: true,
          onRetry: () => ref.invalidate(riskStatusProvider(widget.patientId)),
          data: (s) => _content(context, s, role),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, RiskStatus s, UserRole? role) {
    final canRefresh = widget.canAssess && !s.offline;
    final latest = s.latest;
    // Patients answer every question again (saved to their health profile) before a new
    // assessment; doctors refresh with the patient's current records.
    final isPatient = role == UserRole.patient;
    final Widget mainAction = _refreshing
        ? const FilledButton(onPressed: null, child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
        : isPatient
            ? FilledButton.icon(
                onPressed: () => context.push('/p/diabetes/assess'),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(latest == null ? 'Start assessment' : 'Run new assessment'),
              )
            : (s.stale || latest == null)
                ? FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: Text(latest == null ? 'Get risk estimate' : 'Refresh assessment'))
                : OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Refresh assessment'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (s.offline) ...[OfflineRiskBanner(lastUpdated: latest?.createdAt), const SizedBox(height: AppSpacing.md)],
      if (latest == null)
        _Intro(status: s, action: canRefresh ? mainAction : null)
      else
        HeroPanel(
          child: RiskResultBlock(assessment: latest, actions: [
            if (canRefresh) mainAction,
            TextButton(onPressed: () => context.push('/r/${widget.patientId}/diabetes-risk/${latest.id}'), child: const Text('View details')),
          ]),
        ),
      if (s.stale) ...[
        const SizedBox(height: AppSpacing.md),
        StaleBanner(reasons: s.staleReasons, offline: s.offline, onRefresh: canRefresh && !_refreshing ? _refresh : null),
      ],
      if (latest?.warning != null) ...[const SizedBox(height: AppSpacing.md), RiskWarningNote(latest!.warning!)],
      const SizedBox(height: AppSpacing.section),
      if (latest != null) ...[
        const SectionHeader('Data used for this assessment', subtitle: 'Only information SUSTHITI already had. Nothing was guessed or filled in.'),
        DataUsedCard(data: latest.dataUsed),
      ] else ...[
        const SectionHeader('Health information available now', subtitle: 'What an estimate would use, from your SUSTHITI records.'),
        DataUsedCard(data: s.currentData),
      ],
      if (s.currentData.missing.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.section),
        SectionHeader('Not recorded yet',
            subtitle: 'The estimate uses these when they are in your records. Until then they are left out, not assumed. '
                '${s.currentData.availableCount} of ${s.currentData.totalCount} available.'),
        MissingDataCard(missing: s.currentData.missing, patientId: widget.patientId, role: role),
      ],
      if (s.historyTotal > 0) ...[
        const SizedBox(height: AppSpacing.section),
        const SectionHeader('Assessment history', subtitle: 'Every estimate is kept exactly as it was made.'),
        _History(patientId: widget.patientId),
      ],
      if (s.earlierModelTotal > 0) ...[
        const SizedBox(height: AppSpacing.section),
        _EarlierModel(patientId: widget.patientId),
      ],
      const RiskSafetyNote(),
    ]);
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.status, this.action});
  final RiskStatus status;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return HeroPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(RiskWording.title, style: t.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Estimate your future diabetes risk. You\'ll confirm a few questions, already filled in with what SUSTHITI knows; '
          'values from your medical reports, your lifestyle and connected devices are added automatically.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('${status.currentData.availableCount} of ${status.currentData.totalCount} health details are available now.', style: t.bodySmall),
        if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
      ]),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(riskHistoryProvider(patientId));
    return AsyncBody(
      value: history,
      loading: const SkeletonList(count: 2, itemHeight: 56),
      onRetry: () => ref.invalidate(riskHistoryProvider(patientId)),
      data: (items) => RiskHistoryList(items: items, patientId: patientId),
    );
  }
}

/// Read-only list of assessments made with the retired 16-question symptom model.
class _EarlierModel extends ConsumerWidget {
  const _EarlierModel({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final earlier = ref.watch(assessmentHistoryProvider(patientId));
    return AppCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        title: Text('Earlier symptom questionnaire', style: t.titleSmall),
        subtitle: Text('Results from a previous model, kept for your history', style: t.bodySmall),
        children: [
          AsyncBody(
            value: earlier,
            onRetry: () => ref.invalidate(assessmentHistoryProvider(patientId)),
            data: (items) => Column(children: [
              for (final a in items)
                ListTile(
                  title: Text(Fmt.date(a.assessedAt)),
                  subtitle: Text('Classification: ${a.prediction}'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () => context.push('/r/$patientId/assessments/${a.id}'),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}
