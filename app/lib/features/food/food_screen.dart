import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../data/models/tracking.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

typedef FoodKey = ({String patientId, DateTime start, DateTime end});

final foodEntriesProvider = FutureProvider.autoDispose.family<List<FoodEntry>, FoodKey>(
  (ref, k) => ref.watch(foodRepositoryProvider).list(k.patientId, start: k.start, end: k.end),
);

enum FoodPeriod { today, yesterday, week, custom }

class FoodScreen extends ConsumerStatefulWidget {
  const FoodScreen({super.key, required this.patientId, this.canLog = true});
  final String patientId;
  final bool canLog;

  @override
  ConsumerState<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends ConsumerState<FoodScreen> {
  FoodPeriod _period = FoodPeriod.today;
  DateTimeRange? _custom;

  FoodKey get _key {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      FoodPeriod.today => (patientId: widget.patientId, start: today, end: today),
      FoodPeriod.yesterday => (patientId: widget.patientId, start: today.subtract(const Duration(days: 1)), end: today.subtract(const Duration(days: 1))),
      FoodPeriod.week => (patientId: widget.patientId, start: today.subtract(const Duration(days: 6)), end: today),
      FoodPeriod.custom => (patientId: widget.patientId, start: _custom?.start ?? today, end: _custom?.end ?? today),
    };
  }

  Future<void> _selectPeriod(FoodPeriod p) async {
    if (p == FoodPeriod.custom) {
      final picked = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now(), initialDateRange: _custom);
      if (picked == null) return;
      _custom = picked;
    }
    setState(() => _period = p);
  }

  Future<void> _openForm(AppLocalizations l10n, [FoodEntry? entry]) async {
    final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _FoodForm(patientId: widget.patientId, entry: entry));
    if (saved == true) {
      ref.invalidate(foodEntriesProvider);
      if (mounted) showToast(context, entry == null ? l10n.foodMealLoggedToast : l10n.foodEntryUpdatedToast);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(foodEntriesProvider(_key));
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: l10n.foodLogTitle,
      floatingActionButton: widget.canLog
          ? FloatingActionButton.extended(onPressed: () => _openForm(l10n), icon: const Icon(Icons.add), label: Text(l10n.foodLogButton), backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 1)
          : null,
      body: PageBody(
        maxWidth: 760,
        onRefresh: () async => ref.invalidate(foodEntriesProvider(_key)),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final p in FoodPeriod.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(switch (p) { FoodPeriod.today => l10n.commonToday, FoodPeriod.yesterday => l10n.foodPeriodYesterday, FoodPeriod.week => l10n.foodPeriodThisWeek, FoodPeriod.custom => _custom == null ? l10n.foodPeriodCustomDate : '${Fmt.shortDate(_custom!.start)} – ${Fmt.shortDate(_custom!.end)}' }),
                    selected: _period == p,
                    onSelected: (_) => _selectPeriod(p),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          AsyncBody(
            value: value,
            onRetry: () => ref.invalidate(foodEntriesProvider(_key)),
            data: (entries) {
              if (entries.isEmpty) {
                return EmptyState(
                  icon: Icons.restaurant_outlined,
                  title: _period == FoodPeriod.today ? l10n.foodEmptyToday : l10n.foodEmptyPeriod,
                  actionLabel: widget.canLog ? l10n.foodLogButton : null,
                  onAction: widget.canLog ? () => _openForm(l10n) : null,
                );
              }
              final byDay = <DateTime, List<FoodEntry>>{};
              for (final e in entries) {
                final local = e.eatenAt.toLocal();
                byDay.putIfAbsent(DateTime(local.year, local.month, local.day), () => []).add(e);
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final day in byDay.keys) ...[
                  Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.sm), child: Text(Fmt.date(day), style: t.labelLarge)),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (var i = 0; i < byDay[day]!.length; i++) ...[
                        if (i > 0) const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                        ListTile(
                          title: Text(byDay[day]![i].foodName),
                          subtitle: Text(
                            '${l10n.foodEntrySubtitle(byDay[day]![i].quantity, byDay[day]![i].mealType.label, Fmt.time(byDay[day]![i].eatenAt))}${byDay[day]![i].isEdited ? ' · ${l10n.commonEditedTag}' : ''}',
                          ),
                          trailing: widget.canLog ? const Icon(Icons.edit_outlined, size: 20) : null,
                          onTap: widget.canLog ? () => _openForm(l10n, byDay[day]![i]) : null,
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ]);
            },
          ),
        ],
      ),
    );
  }
}

class _FoodForm extends ConsumerStatefulWidget {
  const _FoodForm({required this.patientId, this.entry});
  final String patientId;
  final FoodEntry? entry;

  @override
  ConsumerState<_FoodForm> createState() => _FoodFormState();
}

class _FoodFormState extends ConsumerState<_FoodForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.entry?.foodName);
  late final _quantity = TextEditingController(text: widget.entry?.quantity);
  late MealType? _meal = widget.entry?.mealType;
  late DateTime? _at = widget.entry?.eatenAt.toLocal() ?? DateTime.now();

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(foodRepositoryProvider);
    try {
      if (widget.entry == null) {
        await repo.add(widget.patientId, name: _name.text, quantity: _quantity.text, meal: _meal!, eatenAt: _at!);
      } else {
        await repo.edit(widget.entry!.id, name: _name.text, quantity: _quantity.text, meal: _meal!, eatenAt: _at!);
      }
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SheetForm(
      title: widget.entry == null ? l10n.foodLogButton : l10n.foodEditEntryTitle,
      form: _form,
      children: [
        AppTextField(label: l10n.foodNameLabel, controller: _name, hint: l10n.foodNameHint, validator: (v) => Validators.required(l10n, v, l10n.foodNameLabel), textCapitalization: TextCapitalization.sentences),
        AppTextField(label: l10n.foodQuantityLabel, controller: _quantity, hint: l10n.foodQuantityHint, validator: (v) => Validators.required(l10n, v, l10n.foodQuantityLabel)),
        ChoiceField<MealType>(label: l10n.foodMealLabel, options: MealType.values, value: _meal, labelOf: (m) => m.label, onChanged: (m) => setState(() => _meal = m), requiredMessage: l10n.choiceRequiredMessage),
        DateTimeField(label: l10n.foodTimeLabel, value: _at, includeTime: true, onChanged: (d) => setState(() => _at = d), validator: (d) => Validators.notFuture(l10n, d, l10n.foodTimeLabel)),
        BusyButton(label: l10n.commonSave, onPressed: _save, expand: true),
      ],
    );
  }
}
