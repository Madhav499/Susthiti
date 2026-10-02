import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/tracking.dart';
import '../../data/providers.dart';
import '../lifestyle/trend_card.dart';

final glucoseOverviewProvider = FutureProvider.autoDispose.family<GlucoseOverview, String>((ref, pid) => ref.watch(glucoseRepositoryProvider).overview(pid));
final glucoseHistoryProvider = FutureProvider.autoDispose.family<List<GlucoseReading>, String>((ref, pid) => ref.watch(glucoseRepositoryProvider).list(pid));

class GlucoseScreen extends ConsumerWidget {
  const GlucoseScreen({super.key, required this.patientId, this.canRecord = true});
  final String patientId;
  final bool canRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      title: 'Glucose',
      floatingActionButton: canRecord
          ? FloatingActionButton.extended(
              onPressed: () => showRecordGlucoseSheet(context, ref, patientId),
              icon: const Icon(Icons.add),
              label: const Text('Record Reading'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 1,
            )
          : null,
      body: GlucoseView(patientId: patientId, canRecord: canRecord),
    );
  }
}

class GlucoseView extends ConsumerWidget {
  const GlucoseView({super.key, required this.patientId, this.canRecord = false, this.embedded = false, this.ranges = TrendCard.shortRanges});
  final String patientId;
  final bool canRecord;
  final bool embedded;
  final Map<String, String> ranges;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(glucoseOverviewProvider(patientId));
    final history = ref.watch(glucoseHistoryProvider(patientId));
    return PageBody(
      maxWidth: 900,
      padding: embedded ? const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xxl) : null,
      onRefresh: () async {
        ref.invalidate(glucoseOverviewProvider(patientId));
        ref.invalidate(glucoseHistoryProvider(patientId));
        ref.invalidate(trendProvider);
      },
      children: [
        AsyncBody(
          value: history,
          onRetry: () => ref.invalidate(glucoseHistoryProvider(patientId)),
          data: (readings) {
            if (readings.isEmpty) {
              return EmptyState(
                icon: Icons.water_drop_outlined,
                title: 'No glucose readings yet.',
                message: canRecord ? 'Record readings to see your averages and trends here.' : 'The patient has not recorded any glucose readings.',
                actionLabel: canRecord ? 'Record First Reading' : null,
                onAction: canRecord ? () => showRecordGlucoseSheet(context, ref, patientId) : null,
              );
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              overview.when(
                loading: () => const Skeleton(height: 110, radius: 16),
                error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(glucoseOverviewProvider(patientId))),
                data: (o) => ResponsiveGrid(minItemWidth: 180, children: [
                  MetricTile(icon: Icons.today_outlined, label: "Today's readings", value: '${o.todayCount}', caption: o.todayCount == 0 ? 'None recorded today' : 'Latest ${o.latestValue?.round()} mg/dL'),
                  MetricTile(icon: Icons.functions, label: 'Recent average', value: o.average7d == null ? '—' : '${o.average7d!.round()} mg/dL', caption: 'Last 7 days · ${o.readings7d} readings'),
                  MetricTile(icon: Icons.trending_flat, label: 'Trend', value: switch (o.trend) { 'higher' => 'Higher', 'lower' => 'Lower', 'stable' => 'Stable', _ => 'Not enough data' }, caption: 'This week vs previous weeks'),
                ]),
              ),
              const SizedBox(height: AppSpacing.lg),
              TrendCard(patientId: patientId, metric: 'glucose', title: 'Glucose', ranges: ranges),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader('History'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < readings.length; i++) ...[
                    if (i > 0) const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                    _ReadingRow(readings[i]),
                  ],
                ]),
              ),
            ]);
          },
        ),
      ],
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow(this.r);
  final GlucoseReading r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(children: [
        SizedBox(
          width: 88,
          child: Text('${r.value % 1 == 0 ? r.value.toInt() : r.value}', style: t.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.unit} · ${r.readingType.label}', style: t.bodyMedium),
            Text(Fmt.dateTime(r.measuredAt), style: t.bodySmall),
            if (r.context != null) Text(r.context!, style: t.bodySmall),
          ]),
        ),
        if (r.isDemo) const DemoBadge(),
        const SizedBox(width: AppSpacing.sm),
        SourceLabel(r.source),
      ]),
    );
  }
}

Future<void> showRecordGlucoseSheet(BuildContext context, WidgetRef ref, String patientId) async {
  final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _RecordGlucoseSheet(patientId: patientId));
  if (saved == true) {
    ref.invalidate(glucoseOverviewProvider(patientId));
    ref.invalidate(glucoseHistoryProvider(patientId));
    ref.invalidate(trendProvider);
    if (context.mounted) showToast(context, 'Reading recorded');
  }
}

class _RecordGlucoseSheet extends ConsumerStatefulWidget {
  const _RecordGlucoseSheet({required this.patientId});
  final String patientId;

  @override
  ConsumerState<_RecordGlucoseSheet> createState() => _RecordGlucoseSheetState();
}

class _RecordGlucoseSheetState extends ConsumerState<_RecordGlucoseSheet> {
  final _form = GlobalKey<FormState>();
  final _value = TextEditingController();
  final _context = TextEditingController();
  String _unit = 'mg/dL';
  GlucoseReadingType? _type;
  DateTime? _at = DateTime.now();

  @override
  void dispose() {
    _value.dispose();
    _context.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      await ref.read(glucoseRepositoryProvider).add(widget.patientId, value: double.parse(_value.text.trim()), unit: _unit, type: _type!, measuredAt: _at!, context: _context.text);
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetForm(
      title: 'Record Glucose',
      form: _form,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: AppTextField(label: 'Value', controller: _value, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.glucose(v, _unit))),
          const SizedBox(width: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 'mg/dL', label: Text('mg/dL')), ButtonSegment(value: 'mmol/L', label: Text('mmol/L'))],
              selected: {_unit},
              onSelectionChanged: (s) => setState(() => _unit = s.first),
            ),
          ),
        ]),
        ChoiceField<GlucoseReadingType>(label: 'Reading type', options: GlucoseReadingType.values, value: _type, labelOf: (t) => t.label, onChanged: (t) => setState(() => _type = t)),
        DateTimeField(label: 'Date and time', value: _at, includeTime: true, onChanged: (d) => setState(() => _at = d), validator: (d) => Validators.notFuture(d, 'Time')),
        AppTextField(label: 'Context', controller: _context, optional: true, helper: 'For example "after a walk" or "felt dizzy".'),
        BusyButton(label: 'Save reading', onPressed: _save, expand: true),
      ],
    );
  }
}
