import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/report_repository.dart';
import '../../../../shared/database/database_helper.dart';
import '../../../../shared/domain/report_data.dart';

// ── Reports version — incremented to trigger list refresh ────────────────────

class _ReportsVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state = state + 1;
}

final reportsVersionProvider =
    NotifierProvider<_ReportsVersionNotifier, int>(_ReportsVersionNotifier.new);

// ── Reports list ─────────────────────────────────────────────────────────────

class ReportsListNotifier extends AsyncNotifier<List<ReportListItem>> {
  late final ReportRepository _repo;

  @override
  Future<List<ReportListItem>> build() async {
    ref.watch(reportsVersionProvider);
    _repo = ReportRepository(DatabaseHelper.instance);
    return _repo.getReportList();
  }

  Future<void> deleteReport(int id) async {
    await _repo.deleteReport(id);
    ref.read(reportsVersionProvider.notifier).increment();
  }
}

final reportsListProvider =
    AsyncNotifierProvider<ReportsListNotifier, List<ReportListItem>>(
  ReportsListNotifier.new,
);

// ── Single report ─────────────────────────────────────────────────────────────

final reportProvider =
    FutureProvider.family<ReportData?, int>((ref, reportId) async {
  final repo = ReportRepository(DatabaseHelper.instance);
  return repo.getReport(reportId);
});
