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
import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: name == null ? l10n.navHome : '${birthday ? l10n.dashHappyBirthday : Fmt.greeting(l10n)}, ${Fmt.firstName(name)}',
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
    final l10n = AppLocalizations.of(context);
    final hero = _PredictionCarousel(d: d);

    final today = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l10n.dashTodaysOverview),
      ResponsiveGrid(minItemWidth: 150, maxColumns: size == ScreenSize.desktop ? 2 : 4, children: [
        MetricTile(
          icon: Icons.water_drop_outlined,
          label: l10n.navGlucose,
          value: d.glucose.latestValue == null ? l10n.commonNoData : '${d.glucose.latestValue!.round()} mg/dL',
          caption: d.glucose.latestAt == null ? l10n.dashNoReadingsYet : Fmt.relative(l10n, d.glucose.latestAt),
          onTap: () => context.push('/p/glucose'),
        ),
        for (final m in [LifestyleMetricType.steps, LifestyleMetricType.sleep, LifestyleMetricType.heartRate]) _metric(d.metrics[m], m, context, l10n),
      ]),
    ]);

    final appointment = _nextAppointmentCard(context, d.nextAppointment, l10n);
    final followUp = _nextFollowUpCard(context, d.nextFollowUp, l10n);
    final surgery = _nextSurgeryCard(context, d.nextSurgery, l10n);

    final actions = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l10n.dashQuickActions),
      ResponsiveGrid(minItemWidth: 100, maxColumns: 5, children: [
        ActionTile(icon: Icons.upload_file_outlined, label: l10n.dashUploadReport, onTap: () => context.push('/r/$patientId/reports/upload')),
        ActionTile(
          icon: Icons.water_drop_outlined,
          label: l10n.dashRecordGlucose,
          onTap: () => showRecordGlucoseSheet(context, ref, patientId).then((_) => ref.invalidate(patientDashboardProvider(patientId))),
        ),
        ActionTile(icon: Icons.restaurant_outlined, label: l10n.dashLogFood, onTap: () => context.push('/p/food')),
        ActionTile(icon: Icons.insights_outlined, label: l10n.dashDiabetesRisk, onTap: () => context.go('/p/diabetes')),
        ActionTile(icon: Icons.healing_outlined, label: l10n.dashReportSideEffect, onTap: () => context.push('/p/side-effects/new')),
        ActionTile(icon: Icons.event_repeat_outlined, label: l10n.navFollowUps, onTap: () => context.push('/p/follow-ups')),
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
              Text(l10n.dashAiLifestyleInsight, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const AiLabel(),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text(
              d.insightHeadline ?? l10n.dashInsightPlaceholder,
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            if (d.insightGeneratedAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.dashGenerated(Fmt.relative(l10n, d.insightGeneratedAt)), style: t.labelSmall),
            ],
          ]),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Icon(Icons.chevron_right, color: AppColors.primary),
      ]),
    );

    final reports = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l10n.dashRecentReports, action: TextButton(onPressed: () => context.go('/p/reports'), child: Text(l10n.commonViewAll))),
      if (d.recentReports.isEmpty)
        AppCard(
          child: EmptyState(
            icon: Icons.description_outlined,
            title: l10n.dashNoReportsAvailable,
            compact: true,
            actionLabel: l10n.dashUploadReport,
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
      SectionHeader(l10n.dashMyRecords),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(children: [
          _RecordLink(icon: Icons.medication_outlined, label: l10n.navPrescriptions, onTap: () => context.push('/r/$patientId/prescriptions')),
          _RecordLink(icon: Icons.event_note_outlined, label: l10n.dashDoctorVisits, onTap: () => context.push('/r/$patientId/visits')),
          _RecordLink(icon: Icons.healing_outlined, label: l10n.navSideEffects, onTap: () => context.push('/r/$patientId/side-effects')),
          _RecordLink(icon: Icons.event_available_outlined, label: l10n.dashAppointmentRecommendations, onTap: () => context.push('/p/appointments')),
          _RecordLink(icon: Icons.event_repeat_outlined, label: l10n.navFollowUps, onTap: () => context.push('/p/follow-ups')),
          _RecordLink(icon: Icons.local_hospital_outlined, label: l10n.navSurgeries, onTap: () => context.push('/p/surgeries')),
          _RecordLink(icon: Icons.timeline_outlined, label: l10n.dashHealthTimeline, onTap: () => context.push('/p/timeline')),
          _RecordLink(icon: Icons.summarize_outlined, label: l10n.dashHealthSummary, onTap: () => context.push('/p/health-summary')),
          _RecordLink(icon: Icons.verified_user_outlined, label: l10n.settingsDoctorAccess, onTap: () => context.push('/p/access'), last: true),
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
              Expanded(child: Text(l10n.dashHappyBirthdayMessage(Fmt.firstName(d.patientName)), style: t.titleSmall)),
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
        Expanded(flex: 6, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SectionHeader(l10n.dashYourHealth), hero])),
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

  Widget _metric(MetricOverview? o, LifestyleMetricType m, BuildContext context, AppLocalizations l10n) {
    final icon = switch (m) {
      LifestyleMetricType.steps => Icons.directions_walk_outlined,
      LifestyleMetricType.sleep => Icons.bedtime_outlined,
      _ => Icons.favorite_border,
    };
    final latest = o?.latest;
    return MetricTile(
      icon: icon,
      label: m.label,
      value: latest == null ? l10n.commonNoData : m.format(latest.value, latest.value2),
      caption: latest == null ? l10n.dashNoReadingsYet : (o!.isToday ? l10n.commonToday : l10n.dashLastRecorded(Fmt.shortDate(latest.date))),
      isDemo: latest?.isDemo ?? false,
      onTap: () => context.go('/p/lifestyle'),
    );
  }

  /// Null when there is nothing to show — an empty "Upcoming Appointment" section would just be
  /// clutter, and the full list is always reachable from Quick Actions.
  Widget? _nextAppointmentCard(BuildContext context, AppointmentRecommendation? a, AppLocalizations l10n) {
    if (a == null) return null;
    final t = Theme.of(context).textTheme;
    final timing = a.timing;
    final tone = switch (timing) {
      AppointmentTiming.upcoming => StatusTone.positive,
      AppointmentTiming.unscheduled => StatusTone.attention,
      AppointmentTiming.past => StatusTone.inactive,
    };
    final subtitle = switch (timing) {
      AppointmentTiming.unscheduled => l10n.dashContactClinic,
      _ => Fmt.dateTime(a.recommendedFor),
    };
    final doctorLine = l10n.dashAppointmentDoctorLine(a.doctorName, subtitle);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l10n.dashUpcomingAppointment),
      AppCard(
        onTap: () => context.push('/p/appointments'),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(Icons.event_available_outlined),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(a.reason, style: t.titleSmall)), StatusPill(timing.label, tone: tone)]),
              const SizedBox(height: 2),
              Text(doctorLine, style: t.bodySmall),
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
  Widget? _nextFollowUpCard(BuildContext context, FollowUpTask? f, AppLocalizations l10n) {
    if (f == null) return null;
    final t = Theme.of(context).textTheme;
    final tone = f.isOverdue ? StatusTone.attention : StatusTone.info;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l10n.dashUpcomingFollowUp),
      AppCard(
        onTap: () => context.push('/p/follow-ups'),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(Icons.event_repeat_outlined),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(f.purpose, style: t.titleSmall)), StatusPill(f.isOverdue ? l10n.dashOverdue : l10n.dashScheduled, tone: tone)]),
              const SizedBox(height: 2),
              Text(l10n.dashFollowUpDoctorLine(f.doctorName, Fmt.date(f.dueDate)), style: t.bodySmall),
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
  Widget? _nextSurgeryCard(BuildContext context, Surgery? s, AppLocalizations l10n) {
    if (s == null) return null;
    final t = Theme.of(context).textTheme;
    final tone = s.isOverdue ? StatusTone.attention : StatusTone.info;
    final when = s.scheduledAt == null ? l10n.dashDateTbc : Fmt.dateTime(s.scheduledAt);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l10n.dashUpcomingSurgery),
      AppCard(
        onTap: () => context.push('/p/surgeries'),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(Icons.local_hospital_outlined),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(s.name, style: t.titleSmall)), StatusPill(s.isOverdue ? l10n.dashOverdue : l10n.dashScheduled, tone: tone)]),
              const SizedBox(height: 2),
              Text(l10n.dashSurgeryDoctorLine(s.doctorName, when), style: t.bodySmall),
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
    final l10n = AppLocalizations.of(context);
    final risk = d.risk;
    return HeroPanel(
      onTap: () => context.go('/p/diabetes'),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(RiskWording.title(l10n), style: t.labelMedium?.copyWith(color: AppColors.primaryDeep)),
            const SizedBox(height: AppSpacing.sm),
            if (risk == null) ...[
              Text(l10n.dashNoEstimateYet, style: t.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.dashEstimateFutureRisk,
                style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: () => context.push('/p/diabetes/assess'), child: Text(l10n.dashStartAssessment)),
            ] else ...[
              Wrap(spacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(risk.percentLabel, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                RiskCategoryPill(risk.riskCategory),
              ]),
              Text(RiskWording.estimateLabel(l10n), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              Text(risk.reportAvailable ? l10n.dashIncludesReportValues : l10n.dashBasedOnSymptomsOnly, style: t.bodySmall),
              Text(l10n.dashRiskUpdated(Fmt.relative(l10n, risk.assessedAt)), style: t.bodySmall),
              if (d.riskStale) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.dashUpdatedRiskInfo, style: t.bodySmall?.copyWith(color: AppColors.primaryDeep)),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: () => context.go('/p/diabetes'), child: Text(d.riskStale ? l10n.dashReviewAndRefresh : l10n.dashViewDetails)),
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
    final l10n = AppLocalizations.of(context);
    final risk = d.heartRisk;
    return HeroPanel(
      onTap: () => context.go('/p/heart'),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(HeartWording.title(l10n), style: t.labelMedium?.copyWith(color: AppColors.primaryDeep)),
            const SizedBox(height: AppSpacing.sm),
            if (risk == null) ...[
              Text(l10n.dashNoScreeningYet, style: t.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.dashScreenHeartRisk,
                style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: () => context.push('/p/heart/assess'), child: Text(l10n.dashStartScreening)),
            ] else ...[
              Wrap(spacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(risk.percentLabel, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                HeartRiskLevelPill(risk.riskLevel),
              ]),
              Text(HeartWording.estimateLabel(l10n), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              Text(risk.reportAvailable ? l10n.dashIncludesReportValues : l10n.dashBasedOnSymptomsOnly, style: t.bodySmall),
              Text(l10n.dashRiskUpdated(Fmt.relative(l10n, risk.assessedAt)), style: t.bodySmall),
              if (d.heartRiskStale) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.dashUpdatedScreeningInfo, style: t.bodySmall?.copyWith(color: AppColors.primaryDeep)),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: () => context.go('/p/heart'), child: Text(d.heartRiskStale ? l10n.dashReviewAndRefresh : l10n.dashViewDetails)),
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
