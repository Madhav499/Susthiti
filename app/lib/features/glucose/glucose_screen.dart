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
import '../../l10n/app_localizations.dart';
import '../lifestyle/trend_card.dart';

final glucoseOverviewProvider = FutureProvider.autoDispose.family<GlucoseOverview, String>((ref, pid) => ref.watch(glucoseRepositoryProvider).overview(pid));
final glucoseHistoryProvider = FutureProvider.autoDispose.family<List<GlucoseReading>, String>((ref, pid) => ref.watch(glucoseRepositoryProvider).list(pid));

class GlucoseScreen extends ConsumerWidget {
  const GlucoseScreen({super.key, required this.patientId, this.canRecord = true});
  final String patientId;
  final bool canRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: l10n.navGlucose,
      floatingActionButton: canRecord
          ? FloatingActionButton.extended(
              onPressed: () => showRecordGlucoseSheet(context, ref, patientId),
              icon: const Icon(Icons.add),
              label: Text(l10n.glucoseRecordReadingButton),
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
    final l10n = AppLocalizations.of(context);
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
                title: l10n.glucoseEmptyTitle,
                message: canRecord ? l10n.glucoseEmptyMessageCanRecord : l10n.glucoseEmptyMessageViewOnly,
                actionLabel: canRecord ? l10n.glucoseRecordFirstButton : null,
                onAction: canRecord ? () => showRecordGlucoseSheet(context, ref, patientId) : null,
              );
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              overview.when(
                loading: () => const Skeleton(height: 110, radius: 16),
                error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(glucoseOverviewProvider(patientId))),
                data: (o) => ResponsiveGrid(minItemWidth: 180, children: [
                  MetricTile(icon: Icons.today_outlined, label: l10n.glucoseTodaysReadingsLabel, value: '${o.todayCount}', caption: o.todayCount == 0 ? l10n.glucoseNoneRecordedToday : l10n.glucoseLatestReading('${o.latestValue?.round()}')),
                  MetricTile(icon: Icons.functions, label: l10n.glucoseRecentAverageLabel, value: o.average7d == null ? '—' : '${o.average7d!.round()} mg/dL', caption: l10n.glucoseLast7DaysCaption('${o.readings7d}')),
                  MetricTile(icon: Icons.trending_flat, label: l10n.glucoseTrendLabel, value: switch (o.trend) { 'higher' => l10n.glucoseTrendHigher, 'lower' => l10n.glucoseTrendLower, 'stable' => l10n.glucoseTrendStable, _ => l10n.glucoseTrendNotEnoughData }, caption: l10n.glucoseTrendCaption),
                ]),
              ),
              const SizedBox(height: AppSpacing.lg),
              TrendCard(patientId: patientId, metric: 'glucose', title: l10n.navGlucose, ranges: ranges),
              const SizedBox(height: AppSpacing.section),
              SectionHeader(l10n.navHistory),
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
  final l10n = AppLocalizations.of(context);
  final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _RecordGlucoseSheet(patientId: patientId));
  if (saved == true) {
    ref.invalidate(glucoseOverviewProvider(patientId));
    ref.invalidate(glucoseHistoryProvider(patientId));
    ref.invalidate(trendProvider);
    if (context.mounted) showToast(context, l10n.glucoseReadingRecordedToast);
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
    final l10n = AppLocalizations.of(context);
    return SheetForm(
      title: l10n.glucoseRecordTitle,
      form: _form,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: AppTextField(label: l10n.glucoseValueLabel, controller: _value, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.glucose(l10n, v, _unit))),
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
        ChoiceField<GlucoseReadingType>(label: l10n.glucoseReadingTypeLabel, options: GlucoseReadingType.values, value: _type, labelOf: (t) => t.label, onChanged: (t) => setState(() => _type = t), requiredMessage: l10n.choiceRequiredMessage),
        DateTimeField(label: l10n.glucoseDateTimeLabel, value: _at, includeTime: true, onChanged: (d) => setState(() => _at = d), validator: (d) => Validators.notFuture(l10n, d, l10n.validatorDateLabel)),
        AppTextField(label: l10n.glucoseContextLabel, controller: _context, optional: true, helper: l10n.glucoseContextHelper),
        BusyButton(label: l10n.glucoseSaveReadingButton, onPressed: _save, expand: true),
      ],
    );
  }
}
