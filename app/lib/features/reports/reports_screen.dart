import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/debouncer.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/report.dart';
import '../../data/models/user.dart';
import '../authentication/auth_controller.dart';
import '../notifications/notifications.dart';
import 'report_detail_screen.dart';
import 'reports_providers.dart';

/// Patient's Reports tab.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key, required this.patientId});
  final String patientId;

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final patientId = widget.patientId;
    // Admin uploads go through the admin route so the admin is recorded as the uploader.
    final uploadRoute = ref.watch(currentUserProvider)?.role == UserRole.admin ? '/a/patients/$patientId/upload' : '/r/$patientId/reports/upload';
    final desktop = context.screenSize == ScreenSize.desktop;
    return AppPage(
      title: 'Reports',
      large: true,
      actions: const [NotificationBell()],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(uploadRoute),
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Upload Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: !desktop
          ? ReportsView(patientId: patientId, uploadRoute: uploadRoute)
          : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                flex: 5,
                child: ReportsView(patientId: patientId, uploadRoute: uploadRoute, selectedId: _selected, onSelect: (r) => setState(() => _selected = r.id)),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 6,
                child: _selected == null
                    ? const Center(child: EmptyState(icon: Icons.description_outlined, title: 'Select a report', message: 'Its details, original file and AI summary appear here.'))
                    : ReportDetailBody(key: ValueKey(_selected), reportId: _selected!, showTitle: true),
              ),
            ]),
    );
  }
}

/// Reusable report history (patient tab and doctor's patient detail).
class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key, required this.patientId, required this.uploadRoute, this.embedded = false, this.onSelect, this.selectedId});
  final String patientId;
  final String uploadRoute;
  final bool embedded;

  /// Desktop list | details: selecting shows the report beside the list instead of opening it.
  final ValueChanged<MedicalReport>? onSelect;
  final String? selectedId;

  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  final _debouncer = Debouncer();
  final _search = TextEditingController();
  ReportQuery _query = const ReportQuery();

  @override
  void dispose() {
    _debouncer.dispose();
    _search.dispose();
    super.dispose();
  }

  ReportsKey get _key => (patientId: widget.patientId, query: _query);

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<ReportQuery>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(initial: _query),
    );
    if (result != null) setState(() => _query = result);
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(reportsControllerProvider(_key));
    final t = Theme.of(context).textTheme;
    return PageBody(
      maxWidth: 860,
      onRefresh: () async => ref.invalidate(reportsControllerProvider(_key)),
      padding: widget.embedded ? const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xxl) : null,
      children: [
        _AllReportsSummaryLink(patientId: widget.patientId),
        const SizedBox(height: AppSpacing.lg),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(hintText: 'Search reports...', prefixIcon: Icon(Icons.search), isDense: true),
              onChanged: (v) => _debouncer(() => setState(() => _query = _query.copyWith(search: v))),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Badge(
            isLabelVisible: _query.hasFilters,
            backgroundColor: AppColors.primary,
            smallSize: 8,
            child: IconButton.outlined(tooltip: 'Filter reports', onPressed: _openFilters, icon: const Icon(Icons.tune)),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final g in ReportFilterGroup.values)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  label: Text(g.label),
                  selected: _query.group == g,
                  onSelected: (_) => setState(() => _query = _query.copyWith(group: g)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AsyncBody(
          value: value,
          onRetry: () => ref.invalidate(reportsControllerProvider(_key)),
          errorTitle: 'Unable to load your reports.',
          data: (state) {
            if (state.items.isEmpty) {
              final filtered = _query.search.isNotEmpty || _query.hasFilters;
              return filtered
                  ? const EmptyState(icon: Icons.search_off_outlined, title: 'No matching reports', message: 'Try a different search or filter.')
                  : EmptyState(
                      icon: Icons.description_outlined,
                      title: 'No reports yet.',
                      message: 'Upload your first medical report to begin building your health history.',
                      actionLabel: 'Upload Report',
                      onAction: () => context.push(widget.uploadRoute),
                    );
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${state.total} report${state.total == 1 ? '' : 's'}', style: t.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              for (final r in state.items) ...[
                ReportTile(
                  report: r,
                  selected: r.id == widget.selectedId,
                  onTap: widget.onSelect != null ? () => widget.onSelect!(r) : () => context.push('/r/${widget.patientId}/reports/${r.id}'),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (state.loadMoreError != null) ErrorState(error: state.loadMoreError!, compact: true, onRetry: () => ref.read(reportsControllerProvider(_key).notifier).loadMore()),
              if (state.hasMore)
                Center(
                  child: state.loadingMore
                      ? const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: CircularProgressIndicator())
                      : TextButton(onPressed: () => ref.read(reportsControllerProvider(_key).notifier).loadMore(), child: const Text('Load more')),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

class _AllReportsSummaryLink extends StatelessWidget {
  const _AllReportsSummaryLink({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      tinted: true,
      onTap: () => context.push('/r/$patientId/reports-summary'),
      child: Row(children: [
        const Icon(Icons.auto_awesome_outlined, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('All Reports Summary', style: t.titleSmall),
            Text('What your collection of reports shows over time', style: t.bodySmall),
          ]),
        ),
        const Icon(Icons.chevron_right, color: AppColors.primary),
      ]),
    );
  }
}

/// Clean list item: title, report date, upload date, uploader. Nothing more.
class ReportTile extends StatelessWidget {
  const ReportTile({super.key, required this.report, required this.onTap, this.selected = false});
  final MedicalReport report;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      tinted: selected,
      semanticLabel: '${report.title}, report date ${Fmt.date(report.reportDate)}, uploaded ${Fmt.date(report.uploadedAt)} by ${report.uploadedBy.roleLabel}',
      child: Row(children: [
        IconBadge(report.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(report.title, style: t.titleSmall),
            const SizedBox(height: 2),
            Text(Fmt.date(report.reportDate), style: t.bodyMedium),
            const SizedBox(height: 2),
            Text('Uploaded ${Fmt.date(report.uploadedAt)} · by ${report.uploadedBy.roleLabel}', style: t.bodySmall),
          ]),
        ),
        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ]),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final ReportQuery initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ReportQuery _q = widget.initial;

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDateRange: _q.start != null && _q.end != null ? DateTimeRange(start: _q.start!, end: _q.end!) : null,
    );
    if (range != null) setState(() => _q = _q.copyWith(start: range.start, end: range.end));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Filter Reports', style: t.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          Text('Category', style: t.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, children: [
            for (final g in ReportFilterGroup.values)
              ChoiceChip(label: Text(g.label), selected: _q.group == g, onSelected: (_) => setState(() => _q = _q.copyWith(group: g))),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Text('Report date', style: t.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(_q.start == null ? 'Any' : '${Fmt.date(_q.start)} – ${Fmt.date(_q.end)}'),
              ),
            ),
            if (_q.start != null) IconButton(tooltip: 'Clear dates', onPressed: () => setState(() => _q = _q.copyWith(clearDates: true)), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Text('Sort', style: t.labelLarge),
          RadioGroup<bool>(
            groupValue: _q.newestFirst,
            onChanged: (v) => setState(() => _q = _q.copyWith(newestFirst: v)),
            child: const Column(children: [
              RadioListTile<bool>(value: true, title: Text('Newest'), contentPadding: EdgeInsets.zero),
              RadioListTile<bool>(value: false, title: Text('Oldest'), contentPadding: EdgeInsets.zero),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            TextButton(onPressed: () => Navigator.pop(context, ReportQuery(search: _q.search)), child: const Text('Reset')),
            const Spacer(),
            FilledButton(onPressed: () => Navigator.pop(context, _q), child: const Text('Apply')),
          ]),
        ]),
      ),
    );
  }
}
