import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/tracking.dart';
import '../../data/providers.dart';

typedef TrendKey = ({String patientId, String metric, String range, DateTime? start, DateTime? end});

final trendProvider = FutureProvider.autoDispose.family<TrendSeries, TrendKey>(
  (ref, k) => ref.watch(patientRepositoryProvider).trend(k.patientId, k.metric, k.range, start: k.start, end: k.end),
);

/// Chart card with a range selector. Plots only recorded values.
class TrendCard extends ConsumerStatefulWidget {
  const TrendCard({super.key, required this.patientId, required this.metric, required this.title, required this.ranges, this.bars = false, this.initialRange});

  final String patientId;
  final String metric;
  final String title;
  final Map<String, String> ranges;
  final bool bars;
  final String? initialRange;

  static const shortRanges = {'7d': '7 days', '30d': '30 days', '3m': '3 months', 'custom': 'Custom'};
  static const lifestyleRanges = {'7d': 'Weekly', '30d': 'Monthly', '3m': '3 months', 'custom': 'Custom'};
  static const clinicalRanges = {'1m': '1 Month', '3m': '3 Months', '6m': '6 Months', '1y': '1 Year', 'custom': 'Custom'};

  @override
  ConsumerState<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends ConsumerState<TrendCard> {
  late String _range = widget.initialRange ?? widget.ranges.keys.first;
  DateTimeRange? _custom;

  Future<void> _select(String range) async {
    if (range == 'custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime.now().subtract(const Duration(days: 3 * 365)),
        lastDate: DateTime.now(),
        initialDateRange: _custom,
      );
      if (picked == null) return;
      setState(() {
        _custom = picked;
        _range = 'custom';
      });
    } else {
      setState(() => _range = range);
    }
  }

  /// Null for metrics that aren't a lifestyle metric at all (glucose, or a report-derived
  /// analyte like HbA1c) — those fall back to the plain `value unit` formatting below.
  static LifestyleMetricType? _lifestyleMetric(String apiValue) {
    for (final m in LifestyleMetricType.values) {
      if (m.apiValue == apiValue) return m;
    }
    return null;
  }

  static String _plainValue(double v, String unit) => '${v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} $unit'.trim();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final key = (patientId: widget.patientId, metric: widget.metric, range: _range, start: _range == 'custom' ? _custom?.start : null, end: _range == 'custom' ? _custom?.end : null);
    final value = ref.watch(trendProvider(key));
    final metricType = _lifestyleMetric(widget.metric);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.title, style: t.titleMedium)),
          if (value.value?.points.any((p) => p.isDemo) ?? false) const DemoBadge(),
        ]),
        const SizedBox(height: AppSpacing.md),
        RangeSelector(options: widget.ranges, selected: _range, onChanged: _select),
        if (_range == 'custom' && _custom != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('${Fmt.date(_custom!.start)} – ${Fmt.date(_custom!.end)}', style: t.bodySmall)),
        const SizedBox(height: AppSpacing.md),
        value.when(
          skipLoadingOnReload: true,
          loading: () => const Skeleton(height: 200, radius: 12),
          error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(trendProvider(key))),
          data: (series) {
            if (series.points.isEmpty) {
              return SizedBox(height: 120, child: Center(child: Text('No ${widget.title.toLowerCase()} recorded in this period.', style: t.bodySmall)));
            }
            if (series.points.length == 1) {
              // One point is a fact, not a trend — showing a line chart here would imply a
              // historical direction that doesn't exist yet.
              final p = series.points.first;
              final valueText = metricType == null ? _plainValue(p.value, series.unit) : metricType.format(p.value, p.value2);
              return SizedBox(
                height: 120,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Single recorded result', style: t.titleSmall),
                    const SizedBox(height: 4),
                    Text('$valueText on ${Fmt.date(p.date)}', style: t.bodyMedium),
                    const SizedBox(height: 4),
                    Text('More results are needed to show a trend.', style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ]),
                ),
              );
            }
            final points = [for (final p in series.points) ChartPoint(p.date, p.value, value2: p.value2, isDemo: p.isDemo)];
            final values = series.points.map((p) => p.value).toList();
            final avg = values.reduce((a, b) => a + b) / values.length;
            final avgText = metricType == null ? _plainValue(avg, series.unit) : metricType.format(avg);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TrendLineChart(points: points, unit: series.unit, bars: widget.bars),
              const SizedBox(height: AppSpacing.sm),
              Text('Average $avgText across ${values.length} recorded ${widget.metric == 'glucose' ? 'readings' : 'days'}', style: t.bodySmall),
            ]);
          },
        ),
      ]),
    );
  }
}
