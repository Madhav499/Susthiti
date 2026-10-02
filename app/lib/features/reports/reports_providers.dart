import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ai_summary.dart';
import '../../data/models/report.dart';
import '../../data/providers.dart';

typedef ReportsKey = ({String patientId, ReportQuery query});

class ReportListState {
  const ReportListState({required this.items, required this.total, this.loadingMore = false, this.loadMoreError});
  final List<MedicalReport> items;
  final int total;
  final bool loadingMore;
  final Object? loadMoreError;
  bool get hasMore => items.length < total;
}

/// Paginated metadata list. Files are never downloaded here.
class ReportsController extends AsyncNotifier<ReportListState> {
  ReportsController(this.key);
  final ReportsKey key;

  static const pageSize = 20;

  @override
  Future<ReportListState> build() async {
    final page = await ref.watch(reportRepositoryProvider).list(key.patientId, key.query, limit: pageSize);
    return ReportListState(items: page.items, total: page.total);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(ReportListState(items: current.items, total: current.total, loadingMore: true));
    try {
      final page = await ref.read(reportRepositoryProvider).list(key.patientId, key.query, offset: current.items.length, limit: pageSize);
      state = AsyncData(ReportListState(items: [...current.items, ...page.items], total: page.total));
    } catch (e) {
      state = AsyncData(ReportListState(items: current.items, total: current.total, loadMoreError: e));
    }
  }
}

final reportsControllerProvider = AsyncNotifierProvider.autoDispose.family<ReportsController, ReportListState, ReportsKey>(ReportsController.new);

final reportProvider = FutureProvider.autoDispose.family<MedicalReport, String>((ref, id) => ref.watch(reportRepositoryProvider).get(id));

final individualSummaryProvider = FutureProvider.autoDispose.family<AISummary?, String>((ref, reportId) => ref.watch(aiRepositoryProvider).reports.individualSummary(reportId));

final allReportsSummaryProvider = FutureProvider.autoDispose.family<({AISummary? summary, int reportCount}), String>(
  (ref, patientId) => ref.watch(aiRepositoryProvider).reports.allReportsSummary(patientId),
);
