import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/day_change_watcher.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/care.dart';
import '../../data/models/diabetes_risk.dart';
import '../../data/models/heart_risk.dart';
import '../../data/models/system.dart';
import '../../data/models/tracking.dart';
import '../../data/providers.dart';
import '../diabetes/risk_widgets.dart';
import '../glucose/glucose_screen.dart';
import '../heart/heart_widgets.dart';
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
  DayChangeWatcher? _dayWatcher;

  @override
  void initState() {
    super.initState();
    _dayWatcher = DayChangeWatcher(() => ref.invalidate(patientDashboardProvider(patientId)));
    // On launch: bring health data up to date in the foreground (lazy: only now is the health
    // platform touched), then refresh the dashboard if anything new arrived.
    WidgetsBinding.instance.addPostFrameCallback((_) => syncHealthIfDue(ref, onSynced: () => ref.invalidate(patientDashboardProvider(patientId))));
  }

  @override
  void dispose() {
    _dayWatcher?.dispose();
    super.dispose();
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
      brand: true,
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
    final hero = _PredictionCarousel(d: d);

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

    final appointment = _nextAppointmentCard(context, d.nextAppointment);
    final followUp = _nextFollowUpCard(context, d.nextFollowUp);
    final surgery = _nextSurgeryCard(context, d.nextSurgery);

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
        ActionTile(icon: Icons.event_repeat_outlined, label: 'Follow-ups', onTap: () => context.push('/p/follow-ups')),
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
          _RecordLink(icon: Icons.event_repeat_outlined, label: 'Follow-ups', onTap: () => context.push('/p/follow-ups')),
          _RecordLink(icon: Icons.local_hospital_outlined, label: 'Surgeries', onTap: () => context.push('/p/surgeries')),
          _RecordLink(icon: Icons.timeline_outlined, label: 'Health timeline', onTap: () => context.push('/p/timeline')),
          _RecordLink(icon: Icons.summarize_outlined, label: 'Your Health Summary', onTap: () => context.push('/p/health-summary')),
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
        hero, gap, today, gap,
        if (appointment != null) ...[appointment, gap],
        if (followUp != null) ...[followUp, gap],
        if (surgery != null) ...[surgery, gap],
        insight, gap, actions, gap, reports, gap, records, const Disclaimer(),
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
      if (appointment != null) ...[appointment, gap],
      if (followUp != null) ...[followUp, gap],
      if (surgery != null) ...[surgery, gap],
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

  /// Null when there is nothing to show — an empty "Upcoming Appointment" section would just be
  /// clutter, and the full list is always reachable from Quick Actions.
  Widget? _nextAppointmentCard(BuildContext context, AppointmentRecommendation? a) {
    if (a == null) return null;
    final t = Theme.of(context).textTheme;
    final timing = a.timing;
    final tone = switch (timing) {
      AppointmentTiming.upcoming => StatusTone.positive,
      AppointmentTiming.unscheduled => StatusTone.attention,
      AppointmentTiming.past => StatusTone.inactive,
    };
    final subtitle = switch (timing) {
      AppointmentTiming.unscheduled => 'Contact the clinic to schedule a time',
      _ => Fmt.dateTime(a.recommendedFor),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Upcoming Appointment'),
      AppCard(
        onTap: () => context.push('/p/appointments'),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(Icons.event_available_outlined),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(a.reason, style: t.titleSmall)), StatusPill(timing.label, tone: tone)]),
              const SizedBox(height: 2),
              Text('Dr. ${a.doctorName} · $subtitle', style: t.bodySmall),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ]),
      ),
    ]);
  }

  /// Null when there is nothing to show — only a follow-up still scheduled (never a completed
  /// or cancelled one) is worth surfacing on the home screen.
  Widget? _nextFollowUpCard(BuildContext context, FollowUpTask? f) {
    if (f == null) return null;
    final t = Theme.of(context).textTheme;
    final tone = f.isOverdue ? StatusTone.attention : StatusTone.info;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Upcoming Follow-up'),
      AppCard(
        onTap: () => context.push('/p/follow-ups'),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(Icons.event_repeat_outlined),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(f.purpose, style: t.titleSmall)), StatusPill(f.isOverdue ? 'Overdue' : 'Scheduled', tone: tone)]),
              const SizedBox(height: 2),
              Text('Dr. ${f.doctorName} · Due ${Fmt.date(f.dueDate)}', style: t.bodySmall),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ]),
      ),
    ]);
  }

  /// Null when there is nothing to show — only a surgery still scheduled is worth surfacing
  /// on the home screen, and never with internal (doctor-only) information.
  Widget? _nextSurgeryCard(BuildContext context, Surgery? s) {
    if (s == null) return null;
    final t = Theme.of(context).textTheme;
    final tone = s.isOverdue ? StatusTone.attention : StatusTone.info;
    final when = s.scheduledAt == null ? 'Date to be confirmed' : Fmt.dateTime(s.scheduledAt);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Upcoming Surgery'),
      AppCard(
        onTap: () => context.push('/p/surgeries'),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(Icons.local_hospital_outlined),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(s.name, style: t.titleSmall)), StatusPill(s.isOverdue ? 'Overdue' : 'Scheduled', tone: tone)]),
              const SizedBox(height: 2),
              Text('Dr. ${s.doctorName} · $when', style: t.bodySmall),
              if (s.hospital != null && s.hospital!.isNotEmpty) Text(s.hospital!, style: t.bodySmall),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ]),
      ),
    ]);
  }
}

/// Diabetes and Heart prediction cards as one swipeable carousel: same card area, same
/// outer height, horizontal swipe between them. The outer height is content-driven: each slide
/// renders at its natural (unconstrained) height via [_SizedSlide]/[OverflowBox], and that height
/// is reported back to the parent through [_SizeReport]. The [SizedBox] wrapping the [PageView]
/// is set to max(h_diabetes, h_heart) so both slides use an identical, compact outer height with
/// no wasted blank space below the content.
class _PredictionCarousel extends StatefulWidget {
  const _PredictionCarousel({required this.d});
  final PatientDashboard d;

  @override
  State<_PredictionCarousel> createState() => _PredictionCarouselState();
}

class _PredictionCarouselState extends State<_PredictionCarousel> {
  final _controller = PageController();
  int _page = 0;

  /// Natural heights reported by each slide after its first unconstrained render.
  final _slideHeights = <int, double>{};

  /// Outer PageView height: maximum of all reported slide heights. Falls back to a safe
  /// initial estimate on the very first frame (before any slide has reported), which avoids
  /// a layout error while keeping the jump imperceptible.
  double _resolvedHeight(ScreenSize screenSize) {
    if (_slideHeights.isEmpty) return screenSize == ScreenSize.mobile ? 260 : 220;
    return _slideHeights.values.fold(0.0, (a, b) => a > b ? a : b);
  }

  void _onSlideHeight(int index, double h) {
    if (_slideHeights[index] == h) return;
    setState(() => _slideHeights[index] = h);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = _resolvedHeight(context.screenSize);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: height,
        child: ClipRect(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              _SizedSlide(index: 0, onHeight: _onSlideHeight, child: _DiabetesHeroCard(d: widget.d)),
              _SizedSlide(index: 1, onHeight: _onSlideHeight, child: _HeartHeroCard(d: widget.d)),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < 2; i++)
          AnimatedContainer(
            duration: AppDurations.fast,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _page ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(color: i == _page ? AppColors.primary : AppColors.primaryBorder, borderRadius: BorderRadius.circular(3)),
          ),
      ]),
    ]);
  }
}

class _DiabetesHeroCard extends StatelessWidget {
  const _DiabetesHeroCard({required this.d});
  final PatientDashboard d;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final size = context.screenSize;
    final risk = d.risk;
    return HeroPanel(
      onTap: () => context.go('/p/diabetes'),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
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
  }
}

class _HeartHeroCard extends StatelessWidget {
  const _HeartHeroCard({required this.d});
  final PatientDashboard d;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final size = context.screenSize;
    final risk = d.heartRisk;
    return HeroPanel(
      onTap: () => context.go('/p/heart'),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(HeartWording.title, style: t.labelMedium?.copyWith(color: AppColors.primaryDeep)),
            const SizedBox(height: AppSpacing.sm),
            if (risk == null) ...[
              Text('No screening yet', style: t.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Screen your heart disease risk. A short form, already filled in with what SUSTHITI knows.',
                style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: () => context.push('/p/heart/assess'), child: const Text('Start screening')),
            ] else ...[
              Wrap(spacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(risk.percentLabel, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                HeartRiskLevelPill(risk.riskLevel),
              ]),
              Text(HeartWording.estimateLabel, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              Text(risk.reportAvailable ? 'Includes medical report values' : 'Based on symptoms and risk factors only', style: t.bodySmall),
              Text('Updated ${Fmt.relative(risk.assessedAt)}', style: t.bodySmall),
              if (d.heartRiskStale) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Updated health information is available. Refresh your screening to include it.', style: t.bodySmall?.copyWith(color: AppColors.primaryDeep)),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: () => context.go('/p/heart'), child: Text(d.heartRiskStale ? 'Review and refresh' : 'View details')),
            ],
          ]),
        ),
        const SizedBox(width: AppSpacing.lg),
        Container(
          width: size == ScreenSize.mobile ? 72 : 96,
          height: size == ScreenSize.mobile ? 72 : 96,
          decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.primaryBorder, width: 6)),
          child: const Icon(Icons.favorite_border, color: AppColors.primary, size: 32),
        ),
      ]),
    );
  }
}

/// Renders [child] inside an [OverflowBox] so it escapes the [PageView]'s tight height
/// constraint and lays out at its natural size. [_SizeReport] then measures that natural
/// height and forwards it via [onHeight], allowing [_PredictionCarouselState] to size the
/// wrapping [SizedBox] to exactly the tallest slide's content height.
class _SizedSlide extends StatelessWidget {
  const _SizedSlide({required this.index, required this.onHeight, required this.child});
  final int index;
  final void Function(int index, double height) onHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      minHeight: 0,
      maxHeight: double.infinity,
      alignment: Alignment.topCenter,
      child: _SizeReport(
        onChange: (h) => onHeight(index, h),
        child: child,
      ),
    );
  }
}

/// Transparent wrapper that reports its child's rendered height to [onChange] after each
/// frame. Uses a [GlobalKey] to read the [RenderBox] size post-layout, so no rendering-layer
/// imports are needed and there is no extra build pass.
class _SizeReport extends StatefulWidget {
  const _SizeReport({required this.onChange, required this.child});
  final ValueChanged<double> onChange;
  final Widget child;

  @override
  State<_SizeReport> createState() => _SizeReportState();
}

class _SizeReportState extends State<_SizeReport> {
  final _key = GlobalKey();
  double? _lastHeight;

  void _measure() {
    final box = _key.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final h = box.size.height;
      if (h != _lastHeight) {
        _lastHeight = h;
        widget.onChange(h);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(_SizeReport old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
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
