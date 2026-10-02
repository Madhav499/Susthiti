import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import 'labels.dart';

class ChartPoint {
  const ChartPoint(this.date, this.value, {this.value2, this.isDemo = false});
  final DateTime date;
  final double value;
  final double? value2;
  final bool isDemo;
}

/// Calm single-series line chart (teal), optional second series (sage) e.g. diastolic BP.
/// Only plots recorded points; gaps are not interpolated into invented values.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({super.key, required this.points, this.unit = '', this.height = 200, this.bars = false, this.semanticsLabel});

  final List<ChartPoint> points;
  final String unit;
  final double height;
  final bool bars;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return SizedBox(height: height);
    final t = Theme.of(context).textTheme;
    final start = points.first.date;
    double x(DateTime d) => d.difference(start).inMinutes / 1440.0;
    final values = [for (final p in points) ...[p.value, ?p.value2]];
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final pad = (maxV - minV).abs() < 1 ? (maxV.abs() * 0.1 + 1) : (maxV - minV) * 0.15;
    final minY = bars ? 0.0 : (minV - pad).floorToDouble().clamp(0, double.infinity).toDouble();
    final maxY = (maxV + pad).ceilToDouble();
    final spanDays = math.max(1.0, x(points.last.date));

    Widget bottomTitle(double value, TitleMeta meta) {
      if (value == meta.min || value == meta.max) return const SizedBox.shrink();
      final d = start.add(Duration(minutes: (value * 1440).round()));
      return Padding(padding: const EdgeInsets.only(top: 6), child: Text(Fmt.shortDate(d), style: t.labelSmall));
    }

    final titles = FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, meta) => Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(v % 1 == 0 ? 0 : 1), style: t.labelSmall))),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, interval: math.max(1, (spanDays / 4).ceilToDouble()), getTitlesWidget: bottomTitle)),
    );
    final grid = FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]));

    final chart = bars
        ? BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              gridData: grid,
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: titles.leftTitles,
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length || (points.length > 8 && i % (points.length ~/ 4) != 0)) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(Fmt.shortDate(points[i].date), style: t.labelSmall));
                })),
              ),
              barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.textPrimary,
                getTooltipItem: (group, _, rod, _) => BarTooltipItem('${Fmt.number(rod.toY.round())} $unit\n${Fmt.shortDate(points[group.x].date)}', const TextStyle(color: Colors.white, fontSize: 12)),
              )),
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: points[i].value,
                      width: points.length > 20 ? 6 : 14,
                      color: points[i].isDemo ? AppColors.warning.withValues(alpha: 0.6) : (i == points.length - 1 ? AppColors.primary : AppColors.secondary),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ]),
              ],
            ),
            duration: AppDurations.chart,
          )
        : LineChart(
            LineChartData(
              minX: 0,
              maxX: spanDays,
              minY: minY,
              maxY: maxY,
              gridData: grid,
              borderData: FlBorderData(show: false),
              titlesData: titles,
              lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.textPrimary,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem('${s.y.toStringAsFixed(s.y % 1 == 0 ? 0 : 1)} $unit\n${Fmt.shortDate(start.add(Duration(minutes: (s.x * 1440).round())))}', const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              )),
              lineBarsData: [
                _line([for (final p in points) FlSpot(x(p.date), p.value)], AppColors.primary, fill: true),
                if (points.any((p) => p.value2 != null))
                  _line([for (final p in points) if (p.value2 != null) FlSpot(x(p.date), p.value2!)], AppColors.secondary),
              ],
            ),
            duration: AppDurations.chart,
          );

    return Semantics(
      label: semanticsLabel ?? 'Chart with ${points.length} recorded values from ${Fmt.date(points.first.date)} to ${Fmt.date(points.last.date)}',
      child: SizedBox(height: height, child: Padding(padding: const EdgeInsets.only(right: 8, top: 8), child: chart)),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color, {bool fill = false}) => LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.25,
        preventCurveOverShooting: true,
        color: color,
        barWidth: 2.4,
        dotData: FlDotData(show: spots.length <= 14, getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 3, color: AppColors.surface, strokeWidth: 2, strokeColor: color)),
        belowBarData: BarAreaData(show: fill, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.14), color.withValues(alpha: 0.0)])),
      );
}

/// Small metric summary tile used on dashboards.
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.icon, required this.label, required this.value, this.caption, this.isDemo = false, this.onTap, this.spark});

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final bool isDemo;
  final VoidCallback? onTap;
  final List<double>? spark;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value${caption != null ? ', $caption' : ''}${isDemo ? ', demo data' : ''}',
      button: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder, side: const BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(label, style: t.labelMedium, overflow: TextOverflow.ellipsis)),
                if (isDemo) const DemoBadge(),
              ]),
              const SizedBox(height: AppSpacing.md),
              Text(value, style: t.headlineSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(caption!, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (spark != null && spark!.length >= 2) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(height: 28, child: _Sparkline(spark!)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline(this.values);
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return LineChart(LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
          isCurved: true,
          preventCurveOverShooting: true,
          color: AppColors.secondary,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
    ));
  }
}

/// Range selector used by trend views (7 days / 30 days / 3 months / Custom...).
class RangeSelector extends StatelessWidget {
  const RangeSelector({super.key, required this.options, required this.selected, required this.onChanged});

  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [for (final e in options.entries) ButtonSegment(value: e.key, label: Text(e.value))],
        selected: {selected},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

/// Horizontal share-of-total bar with a legend. Counts only; zero segments are omitted.
class DistributionBar extends StatelessWidget {
  const DistributionBar({super.key, required this.segments});
  final List<({String label, int value, Color color})> segments;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final shown = [for (final s in segments) if (s.value > 0) s];
    final total = shown.fold<int>(0, (a, s) => a + s.value);
    return Semantics(
      label: shown.map((s) => '${s.label}: ${s.value}').join(', '),
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: total == 0
                ? const ColoredBox(color: AppColors.surfaceSecondary)
                : Row(children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(flex: shown[i].value, child: ColoredBox(color: shown[i].color)),
                    ],
                  ]),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: AppSpacing.lg, runSpacing: AppSpacing.xs, children: [
          for (final s in segments)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${s.label} ${s.value}', style: t.labelMedium),
            ]),
        ]),
      ]),
    );
  }
}
