import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/diabetes_risk.dart';
import '../../data/models/system.dart';
import '../../data/models/tracking.dart';
import '../../data/providers.dart';
import '../diabetes/risk_widgets.dart';
import '../glucose/glucose_screen.dart';
import '../notifications/notifications.dart';
import '../reports/reports_screen.dart';
import '../wearables/health_connection.dart';

final patientDashboardProvider = FutureProvider.autoDispose.family<PatientDashboard, String>((ref, pid) => ref.watch(patientRepositoryProvider).dashboard(pid));

class PatientDashboardScreen extends ConsumerStatefulWidget {
  const PatientDashboardScreen({super.key, required this.patientId});
  final String patientId;

  @override
  ConsumerState<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends ConsumerState<PatientDashboardScreen> {
  String get patientId => widget.patientId;

  @override
  void initState() {
    super.initState();
    // On launch: bring health data up to date in the foreground (lazy: only now is the health
    // platform touched), then refresh the dashboard if anything new arrived.
    WidgetsBinding.instance.addPostFrameCallback((_) => syncHealthIfDue(ref, onSynced: () => ref.invalidate(patientDashboardProvider(patientId))));
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(patientDashboardProvider(patientId));
    void refresh() => ref.invalidate(patientDashboardProvider(patientId));
    final name = value.value?.patientName;
    final birthday = value.value?.isBirthday ?? false;
    return AppPage(
      title: name == null ? 'Home' : '${birthday ? 'Happy birthday' : Fmt.greeting()}, ${Fmt.firstName(name)}',
      subtitle: Fmt.date(DateTime.now()),
      large: true,
      actions: const [NotificationBell()],
      body: PageBody(
        onRefresh: () async => refresh(),
        children: [
          AsyncBody(
            value: value,
            onRetry: refresh,
            loading: const Column(children: [Skeleton(height: 180, radius: 20), SizedBox(height: AppSpacing.xl), SkeletonList(count: 3)]),
            data: (d) => _DashboardBody(patientId: patientId, d: d),
          ),
        ],
      ),
    );
  }
}

/// Greeting (app bar) -> Diabetes Assessment -> Today's Overview -> AI Lifestyle Insight ->
/// Quick Actions -> Recent Reports / My Records. Desktop pairs the first two side by side.
class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.patientId, required this.d});
  final String patientId;
  final PatientDashboard d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final size = context.screenSize;
    final risk = d.risk;
    final hero = HeroPanel(
      onTap: () => context.go('/p/diabetes'),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(RiskWording.title, style: t.labelMedium?.copyWith(color: AppColors.primaryDeep)),
            const SizedBox(height: AppSpacing.sm),
            if (risk == null) ...[
              Text('No estimate yet', style: t.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Estimate your future diabetes risk. A few questions, already filled in with what SUSTHITI knows.',
                style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: () => context.push('/p/diabetes/assess'), child: const Text('Start assessment')),
            ] else ...[
              Wrap(spacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(risk.percentLabel, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                RiskCategoryPill(risk.riskCategory),
              ]),
              Text(RiskWording.estimateLabel, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              Text(risk.reportAvailable ? 'Includes medical report values' : 'Based on symptoms and risk factors only', style: t.bodySmall),
              Text('Updated ${Fmt.relative(risk.assessedAt)}', style: t.bodySmall),
              if (d.riskStale) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Updated health information is available. Refresh your assessment to include it.', style: t.bodySmall?.copyWith(color: AppColors.primaryDeep)),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: () => context.go('/p/diabetes'), child: Text(d.riskStale ? 'Review and refresh' : 'View details')),
            ],
          ]),
        ),
        const SizedBox(width: AppSpacing.lg),
        Container(
          width: size == ScreenSize.mobile ? 72 : 96,
          height: size == ScreenSize.mobile ? 72 : 96,
          decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.primaryBorder, width: 6)),
          child: const Icon(Icons.insights_outlined, color: AppColors.primary, size: 32),
        ),
      ]),
    );

    final today = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader("Today's Overview"),
      ResponsiveGrid(minItemWidth: 150, maxColumns: size == ScreenSize.desktop ? 2 : 4, children: [
        MetricTile(
          icon: Icons.water_drop_outlined,
          label: 'Glucose',
          value: d.glucose.latestValue == null ? 'No data' : '${d.glucose.latestValue!.round()} mg/dL',
          caption: d.glucose.latestAt == null ? 'No readings yet' : Fmt.relative(d.glucose.latestAt),
          onTap: () => context.push('/p/glucose'),
        ),
        for (final m in [LifestyleMetricType.steps, LifestyleMetricType.sleep, LifestyleMetricType.heartRate]) _metric(d.metrics[m], m, context),
      ]),
    ]);

    final actions = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Quick Actions'),
      ResponsiveGrid(minItemWidth: 100, maxColumns: 5, children: [
        ActionTile(icon: Icons.upload_file_outlined, label: 'Upload Report', onTap: () => context.push('/r/$patientId/reports/upload')),
        ActionTile(
          icon: Icons.water_drop_outlined,
          label: 'Record Glucose',
          onTap: () => showRecordGlucoseSheet(context, ref, patientId).then((_) => ref.invalidate(patientDashboardProvider(patientId))),
        ),
        ActionTile(icon: Icons.restaurant_outlined, label: 'Log Food', onTap: () => context.push('/p/food')),
        ActionTile(icon: Icons.insights_outlined, label: 'Diabetes Risk', onTap: () => context.go('/p/diabetes')),
        ActionTile(icon: Icons.healing_outlined, label: 'Report Side Effect', onTap: () => context.push('/p/side-effects/new')),
      ]),
    ]);

    final insight = AppCard(
      tinted: true,
      onTap: () => context.push('/p/lifestyle/insight'),
      padding: const EdgeInsets.all(AppSpacing.lgPlus),
      child: Row(children: [
        const IconBadge(Icons.auto_awesome_outlined, size: 44),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('AI Lifestyle Insight', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const AiLabel(),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text(
              d.insightHeadline ?? 'Generate suggestions based on your activity, sleep, food and glucose.',
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            if (d.insightGeneratedAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('Generated ${Fmt.relative(d.insightGeneratedAt)}', style: t.labelSmall),
            ],
          ]),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Icon(Icons.chevron_right, color: AppColors.primary),
      ]),
    );

    final reports = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader('Recent Reports', action: TextButton(onPressed: () => context.go('/p/reports'), child: const Text('View all'))),
      if (d.recentReports.isEmpty)
        AppCard(
          child: EmptyState(
            icon: Icons.description_outlined,
            title: 'No reports available.',
            compact: true,
            actionLabel: 'Upload Report',
            onAction: () => context.push('/r/$patientId/reports/upload'),
          ),
        )
      else
        for (final r in d.recentReports) ...[
          ReportTile(report: r, onTap: () => context.push('/r/$patientId/reports/${r.id}')),
          const SizedBox(height: AppSpacing.sm),
        ],
    ]);

    final records = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('My Records'),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(children: [
          _RecordLink(icon: Icons.medication_outlined, label: 'Prescriptions', onTap: () => context.push('/r/$patientId/prescriptions')),
          _RecordLink(icon: Icons.event_note_outlined, label: 'Doctor visits', onTap: () => context.push('/r/$patientId/visits')),
          _RecordLink(icon: Icons.healing_outlined, label: 'Side effects', onTap: () => context.push('/r/$patientId/side-effects')),
          _RecordLink(icon: Icons.event_available_outlined, label: 'Appointment recommendations', onTap: () => context.push('/p/appointments')),
          _RecordLink(icon: Icons.timeline_outlined, label: 'Health timeline', onTap: () => context.push('/p/timeline')),
          _RecordLink(icon: Icons.summarize_outlined, label: 'AI Patient Summary', onTap: () => context.push('/r/$patientId/patient-summary')),
          _RecordLink(icon: Icons.verified_user_outlined, label: 'Doctor access', onTap: () => context.push('/p/access'), last: true),
        ]),
      ),
    ]);

    const gap = SizedBox(height: AppSpacing.section);
    const hgap = SizedBox(width: AppSpacing.xl);
    final birthday = d.isBirthday
        ? AppCard(
            tinted: true,
            child: Row(children: [
              const IconBadge(Icons.cake_outlined, size: 44),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: Text('Happy birthday, ${Fmt.firstName(d.patientName)}! Wishing you a happy and healthy year ahead.', style: t.titleSmall)),
            ]),
          )
        : null;
    if (size != ScreenSize.desktop) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (birthday != null) ...[birthday, gap],
        hero, gap, today, gap, insight, gap, actions, gap, reports, gap, records, const Disclaimer(),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (birthday != null) ...[birthday, gap],
      // Top-aligned rather than IntrinsicHeight: the metric grid uses a LayoutBuilder.
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 6, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SectionHeader('Your Health'), hero])),
        hgap,
        Expanded(flex: 5, child: today),
      ]),
      gap,
      insight,
      gap,
      actions,
      gap,
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: reports),
        hgap,
        Expanded(flex: 2, child: records),
      ]),
      const Disclaimer(),
    ]);
  }

  Widget _metric(MetricOverview? o, LifestyleMetricType m, BuildContext context) {
    final icon = switch (m) {
      LifestyleMetricType.steps => Icons.directions_walk_outlined,
      LifestyleMetricType.sleep => Icons.bedtime_outlined,
      _ => Icons.favorite_border,
    };
    final latest = o?.latest;
    return MetricTile(
      icon: icon,
      label: m.label,
      value: latest == null ? 'No data' : m.format(latest.value, latest.value2),
      caption: latest == null ? 'Not recorded yet' : (o!.isToday ? 'today' : 'Last recorded ${Fmt.shortDate(latest.date)}'),
      isDemo: latest?.isDemo ?? false,
      onTap: () => context.go('/p/lifestyle'),
    );
  }
}

class _RecordLink extends StatelessWidget {
  const _RecordLink({required this.icon, required this.label, required this.onTap, this.last = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        leading: IconBadge(icon, size: 36),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: onTap,
      ),
      if (!last) const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
    ]);
  }
}
