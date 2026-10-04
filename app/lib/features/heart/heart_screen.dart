import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/heart_risk.dart';
import '../../data/models/user.dart';
import '../authentication/auth_controller.dart';
import '../diabetes/risk_widgets.dart' show DataUsedCard, MissingDataCard;
import '../notifications/notifications.dart';
import '../patient/patient_sync.dart';
import 'heart_providers.dart';
import 'heart_widgets.dart';

/// Mirrors features/diabetes/diabetes_screen.dart's DiabetesScreen for its sibling feature.
class HeartScreen extends StatelessWidget {
  const HeartScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Heart',
      large: true,
      actions: const [NotificationBell()],
      body: HeartView(patientId: patientId, canAssess: true),
    );
  }
}

/// Heart disease risk SCREENING: the latest model score, what it was based on, what's missing,
/// and the history. Used by patients, by doctors with access, and (read-only) by admins.
/// Nothing here runs the model; only "Refresh assessment" / the assessment form asks the
/// backend to. Mirrors features/diabetes/diabetes_screen.dart's DiabetesView for its sibling
/// feature -- same widgets, same container sizes, same visual hierarchy.
class HeartView extends ConsumerStatefulWidget {
  const HeartView({super.key, required this.patientId, this.canAssess = false, this.embedded = false});
  final String patientId;
  final bool canAssess;
  final bool embedded;

  @override
  ConsumerState<HeartView> createState() => _HeartViewState();
}

class _HeartViewState extends ConsumerState<HeartView> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final result = await refreshHeartRisk(ref, widget.patientId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.created
            ? 'Your heart risk screening has been updated.'
            : 'Nothing relevant has changed since your last screening, so it is still current.'),
      ));
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(heartRiskStatusProvider(widget.patientId));
    final role = ref.watch(currentUserProvider)?.role;
    return PageBody(
      maxWidth: 860,
      padding: widget.embedded ? const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xxl) : null,
      onRefresh: () async => ref.invalidate(heartRiskStatusProvider(widget.patientId)),
      children: [
        AsyncBody(
          value: status,
          keepDataOnError: true,
          onRetry: () => ref.invalidate(heartRiskStatusProvider(widget.patientId)),
          data: (s) => _content(context, s, role),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, HeartRiskStatus s, UserRole? role) {
    final canRefresh = widget.canAssess;
    final latest = s.latest;
    // Patients answer the assessment form again (point-in-time symptoms and cardiac test
    // results are never reused); doctors refresh with the patient's current records only.
    final isPatient = role == UserRole.patient;
    final Widget mainAction = _refreshing
        ? const FilledButton(onPressed: null, child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
        : isPatient
            ? FilledButton.icon(
                onPressed: () => context.push('/p/heart/assess'),
                icon: const Icon(Icons.favorite_border),
                label: Text(latest == null ? 'Start screening' : 'Run new screening'),
              )
            : (s.stale || latest == null)
                ? FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: Text(latest == null ? 'Get risk screening' : 'Refresh screening'))
                : OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Refresh screening'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (latest == null)
        _Intro(status: s, action: canRefresh ? mainAction : null)
      else
        HeroPanel(
          child: HeartResultBlock(assessment: latest, actions: [
            if (canRefresh) mainAction,
            TextButton(onPressed: () => context.push('/r/${widget.patientId}/heart-risk/${latest.id}'), child: const Text('View details')),
          ]),
        ),
      if (s.stale) ...[
        const SizedBox(height: AppSpacing.md),
        HeartStaleBanner(reasons: s.staleReasons, onRefresh: canRefresh && !_refreshing ? _refresh : null),
      ],
      if (latest != null && latest.warnings.isNotEmpty) ...[const SizedBox(height: AppSpacing.md), HeartWarningNotes(latest.warnings)],
      const SizedBox(height: AppSpacing.section),
      if (latest != null) ...[
        const SectionHeader('Data used for this screening', subtitle: 'Only information SUSTHITI already had, or that was answered on the assessment form.'),
        DataUsedCard(data: latest.dataUsed),
      ] else ...[
        const SectionHeader('Health information available now', subtitle: 'What a screening would use, from your SUSTHITI records.'),
        DataUsedCard(data: s.currentData),
      ],
      if (s.currentData.missing.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.section),
        SectionHeader('Not recorded yet',
            subtitle: 'The screening uses these when they are in your records or answered on the form. '
                '${s.currentData.availableCount} of ${s.currentData.totalCount} available.'),
        MissingDataCard(missing: s.currentData.missing, patientId: widget.patientId, role: role),
      ],
      if (s.historyTotal > 0) ...[
        const SizedBox(height: AppSpacing.section),
        const SectionHeader('Screening history', subtitle: 'Every screening is kept exactly as it was made.'),
        _History(patientId: widget.patientId),
      ],
      const HeartSafetyNote(),
    ]);
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.status, this.action});
  final HeartRiskStatus status;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return HeroPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(HeartWording.title, style: t.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Screen your heart disease risk. You\'ll answer a short form covering symptoms, vitals and cardiac tests; '
          'values already in your SUSTHITI records (profile, labs, lifestyle) are filled in for you to review.',
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
    final history = ref.watch(heartRiskHistoryProvider(patientId));
    return AsyncBody(
      value: history,
      loading: const SkeletonList(count: 2, itemHeight: 56),
      onRetry: () => ref.invalidate(heartRiskHistoryProvider(patientId)),
      data: (items) => HeartRiskHistoryList(items: items, patientId: patientId),
    );
  }
}
