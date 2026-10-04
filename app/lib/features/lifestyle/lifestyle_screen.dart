import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/day_change_watcher.dart';
import '../../core/utils/formatters.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../data/models/tracking.dart';
import '../../data/providers.dart';
import '../notifications/notifications.dart';
import '../wearables/health_connection.dart';
import 'trend_card.dart';

final lifestyleOverviewProvider = FutureProvider.autoDispose.family<LifestyleOverview, String>((ref, pid) => ref.watch(lifestyleRepositoryProvider).overview(pid));

const _lifestyleRanges = {'today': 'Daily', 'week': 'Weekly', 'month': 'Monthly', 'custom': 'Custom'};

class LifestyleScreen extends StatelessWidget {
  const LifestyleScreen({super.key, required this.patientId, this.initialMetric});
  final String patientId;

  /// Metric to focus the trend chart on when opened from a lifestyle-reminder notification
  /// (e.g. "steps") -- see notificationRoute() in notifications.dart.
  final String? initialMetric;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Lifestyle',
      large: true,
      actions: const [NotificationBell()],
      body: LifestyleView(patientId: patientId, isPatient: true, initialMetric: initialMetric),
    );
  }
}

class LifestyleView extends ConsumerStatefulWidget {
  const LifestyleView({super.key, required this.patientId, this.isPatient = false, this.embedded = false, this.ranges = _lifestyleRanges, this.initialMetric});
  final String patientId;
  final bool isPatient;
  final bool embedded;
  final Map<String, String> ranges;
  final String? initialMetric;

  @override
  ConsumerState<LifestyleView> createState() => _LifestyleViewState();
}

class _LifestyleViewState extends ConsumerState<LifestyleView> {
  late LifestyleMetricType _chartMetric;
  DayChangeWatcher? _dayWatcher;

  /// Falls back to steps on an unrecognized or absent value -- 'glucose'/'food' never reach
  /// here (notificationRoute() sends those straight to their own screens instead).
  static LifestyleMetricType _parseMetric(String? apiValue) {
    for (final m in LifestyleMetricType.values) {
      if (m.apiValue == apiValue) return m;
    }
    return LifestyleMetricType.steps;
  }

  @override
  void initState() {
    super.initState();
    _chartMetric = _parseMetric(widget.initialMetric);
    _dayWatcher = DayChangeWatcher(_refresh);
    // Health data syncs when the dashboard opens (background sync is not relied on).
    if (widget.isPatient) WidgetsBinding.instance.addPostFrameCallback((_) => syncHealthIfDue(ref, onSynced: _refresh));
  }

  @override
  void didUpdateWidget(LifestyleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMetric != null && widget.initialMetric != oldWidget.initialMetric) {
      setState(() => _chartMetric = _parseMetric(widget.initialMetric));
    }
  }

  @override
  void dispose() {
    _dayWatcher?.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(lifestyleOverviewProvider(widget.patientId));
    ref.invalidate(trendProvider);
    ref.invalidate(devicesProvider);
  }

  Future<void> _syncNow(List<WearableConnection> devices) async {
    final service = ref.read(wearableServiceProvider);
    final connection = healthConnections(devices).where(service.canSync).firstOrNull;
    if (connection == null) return _refresh(); // web / tablet without the platform: re-read synced data
    try {
      final outcome = await service.sync(connection);
      _refresh();
      if (mounted) showToast(context, outcome.upToDate ? 'Already up to date' : 'Synced just now');
    } catch (_) {
      if (mounted) showToast(context, "Sync didn't complete. Check your connection and try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(lifestyleOverviewProvider(widget.patientId));
    return PageBody(
      maxWidth: 1000,
      padding: widget.embedded ? const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xxl) : null,
      onRefresh: () async => _refresh(),
      children: [
        AsyncBody(
          value: value,
          onRetry: _refresh,
          keepDataOnError: true,
          data: (o) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // A failed refresh keeps the last values on screen, clearly marked as not current.
            if (value.hasError) ...[
              _OfflineNotice(lastSynced: healthConnections(o.devices).firstOrNull?.lastSyncedAt, onRetry: _refresh),
              const SizedBox(height: AppSpacing.md),
            ],
            if (widget.isPatient) ...[
              HealthConnectionCard(devices: o.devices, onChanged: _refresh),
              const SizedBox(height: AppSpacing.section),
            ] else ...[
              HealthSourceSummary(devices: o.devices),
              const SizedBox(height: AppSpacing.lg),
            ],
            SectionHeader(
              'Today',
              subtitle: 'Recorded values only. Comparisons appear once there is enough history.',
              action: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                SyncIndicator(devices: o.devices, offline: value.hasError, onTap: () => _syncNow(o.devices)),
                if (widget.isPatient) TextButton.icon(onPressed: () => _addManual(context), icon: const Icon(Icons.add), label: const Text('Add')),
              ]),
            ),
            ResponsiveGrid(minItemWidth: 170, children: [
              for (final m in [LifestyleMetricType.steps, LifestyleMetricType.heartRate, LifestyleMetricType.sleep, LifestyleMetricType.activity, LifestyleMetricType.bloodPressure, LifestyleMetricType.spo2])
                _metricTile(o.metrics[m], m, connected: healthConnections(o.devices).isNotEmpty),
              MetricTile(
                icon: Icons.water_drop_outlined,
                label: 'Glucose',
                value: o.glucose.latestValue == null ? 'No data' : '${o.glucose.latestValue!.round()} mg/dL',
                caption: o.glucose.latestAt == null ? 'No readings yet' : Fmt.relative(o.glucose.latestAt),
                onTap: widget.isPatient ? () => context.push('/p/glucose') : null,
              ),
              MetricTile(
                icon: Icons.restaurant_outlined,
                label: 'Food',
                value: '${o.foodEntriesToday}',
                caption: o.foodEntriesToday == 1 ? 'meal logged today' : 'meals logged today',
                onTap: widget.isPatient ? () => context.push('/p/food') : null,
              ),
            ]),
            const SizedBox(height: AppSpacing.section),
            const SectionHeader('Trends'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final m in [LifestyleMetricType.steps, LifestyleMetricType.sleep, LifestyleMetricType.activity, LifestyleMetricType.heartRate, LifestyleMetricType.bloodPressure, LifestyleMetricType.spo2])
                  Padding(padding: const EdgeInsets.only(right: AppSpacing.sm), child: ChoiceChip(label: Text(m.label), selected: _chartMetric == m, onSelected: (_) => setState(() => _chartMetric = m))),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),
            TrendCard(
              key: ValueKey(_chartMetric),
              patientId: widget.patientId,
              metric: _chartMetric.apiValue,
              title: _chartMetric.label,
              ranges: widget.ranges,
              bars: _chartMetric == LifestyleMetricType.steps || _chartMetric == LifestyleMetricType.sleep || _chartMetric == LifestyleMetricType.activity,
            ),
            if (widget.isPatient) ...[
              const SizedBox(height: AppSpacing.section),
              AppCard(
                tinted: true,
                onTap: () => context.push('/p/lifestyle/insight'),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_outlined, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Lifestyle Insight', style: Theme.of(context).textTheme.titleSmall),
                      Text('AI suggestions based on your activity, sleep, food and glucose', style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.primary),
                ]),
              ),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _metricTile(MetricOverview? o, LifestyleMetricType m, {required bool connected}) {
    final icon = switch (m) {
      LifestyleMetricType.steps => Icons.directions_walk_outlined,
      LifestyleMetricType.heartRate => Icons.favorite_border,
      LifestyleMetricType.sleep => Icons.bedtime_outlined,
      LifestyleMetricType.activity => Icons.bolt_outlined,
      LifestyleMetricType.bloodPressure => Icons.speed_outlined,
      LifestyleMetricType.spo2 => Icons.air_outlined,
      LifestyleMetricType.calories => Icons.local_fire_department_outlined,
    };
    final latest = o?.latest;
    if (latest == null) {
      // Never a placeholder value: say plainly that nothing was recorded or provided. Many watches
      // don't measure blood pressure or SpO2, so with a source connected say where the gap is.
      final notFromDevice = connected && (m == LifestyleMetricType.bloodPressure || m == LifestyleMetricType.spo2);
      return MetricTile(icon: icon, label: m.label, value: 'No data', caption: notFromDevice ? 'Not available from connected device' : 'Not recorded yet');
    }
    final today = o!.isToday;
    String? caption;
    if (today && o.changePercent != null) {
      final sign = o.changePercent! >= 0 ? '+' : '';
      caption = '$sign${o.changePercent}% vs your recent average';
    } else if (!today) {
      caption = 'Last recorded ${Fmt.shortDate(latest.date)}';
    } else {
      caption = 'today';
    }
    caption = '$caption · ${latest.sourceLabel}';
    return MetricTile(
      icon: icon,
      label: m.label,
      value: m.format(latest.value, latest.value2),
      caption: caption,
      isDemo: latest.isDemo,
      spark: o.last7Days.length >= 3 ? [for (final d in o.last7Days) d.value] : null,
    );
  }

  Future<void> _addManual(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _ManualMetricSheet(patientId: widget.patientId));
    if (saved == true) {
      _refresh();
      if (context.mounted) showToast(context, 'Measurement added');
    }
  }
}

class _ManualMetricSheet extends ConsumerStatefulWidget {
  const _ManualMetricSheet({required this.patientId});
  final String patientId;

  @override
  ConsumerState<_ManualMetricSheet> createState() => _ManualMetricSheetState();
}

class _ManualMetricSheetState extends ConsumerState<_ManualMetricSheet> {
  final _form = GlobalKey<FormState>();
  final _value = TextEditingController();
  final _value2 = TextEditingController();
  LifestyleMetricType? _metric;
  DateTime? _at = DateTime.now();

  static const _limits = {
    LifestyleMetricType.steps: (0, 100000, 'Steps'),
    LifestyleMetricType.heartRate: (20, 250, 'Heart rate (bpm)'),
    LifestyleMetricType.sleep: (0, 1440, 'Sleep (minutes)'),
    LifestyleMetricType.activity: (0, 1440, 'Active minutes'),
    LifestyleMetricType.bloodPressure: (50, 260, 'Systolic (mmHg)'),
    LifestyleMetricType.spo2: (50, 100, 'SpO₂ (%)'),
  };

  @override
  void dispose() {
    _value.dispose();
    _value2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      await ref.read(lifestyleRepositoryProvider).addManual(
            widget.patientId,
            metric: _metric!,
            value: double.parse(_value.text.trim()),
            value2: _metric == LifestyleMetricType.bloodPressure ? double.parse(_value2.text.trim()) : null,
            recordedAt: _at!,
          );
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final limit = _metric == null ? null : _limits[_metric];
    return SheetForm(
      title: 'Add measurement',
      form: _form,
      children: [
        ChoiceField<LifestyleMetricType>(label: 'Measurement', options: _limits.keys.toList(), value: _metric, labelOf: (m) => m.label, onChanged: (m) => setState(() => _metric = m)),
        if (limit != null) ...[
          AppTextField(label: limit.$3, controller: _value, keyboardType: TextInputType.number, validator: (v) => Validators.numberInRange(v, limit.$1, limit.$2)),
          if (_metric == LifestyleMetricType.bloodPressure)
            AppTextField(
              label: 'Diastolic (mmHg)',
              controller: _value2,
              keyboardType: TextInputType.number,
              validator: (v) {
                final base = Validators.numberInRange(v, 30, 200);
                if (base != null) return base;
                final sys = double.tryParse(_value.text.trim());
                return sys != null && double.parse(v!.trim()) >= sys ? 'Diastolic must be lower than systolic.' : null;
              },
            ),
        ],
        DateTimeField(label: 'Date and time', value: _at, includeTime: true, onChanged: (d) => setState(() => _at = d), validator: (d) => Validators.notFuture(d, 'Time')),
        Text('Recorded as a manual entry.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        BusyButton(label: 'Save', onPressed: _save, expand: true),
      ],
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.lastSynced, required this.onRetry});
  final DateTime? lastSynced;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: AppRadius.cardBorder),
      child: Row(children: [
        const Icon(Icons.cloud_off_outlined, size: 18, color: AppColors.warningText),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text('Offline. Showing the last values received${lastSynced == null ? '' : ' (${lastSyncedText(lastSynced).toLowerCase()})'}.', style: Theme.of(context).textTheme.bodySmall)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}
