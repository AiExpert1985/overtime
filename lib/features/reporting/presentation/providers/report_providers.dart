import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/report_repository.dart';
import '../../../../shared/database/database_helper.dart';
import '../../../../shared/domain/report_data.dart';
import '../../application/report_export_service.dart';
import 'settings_providers.dart';

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

// ── Report export ─────────────────────────────────────────────────────────────

class ReportExportState {
  final bool isExporting;
  final String? successPath;
  final String? errorMessage;

  const ReportExportState({
    this.isExporting = false,
    this.successPath,
    this.errorMessage,
  });
}

class ReportExportNotifier extends Notifier<ReportExportState> {
  @override
  ReportExportState build() => const ReportExportState();

  Future<void> export({
    required ReportData report,
    required SettingsState settings,
  }) async {
    state = const ReportExportState(isExporting: true);
    try {
      final path = await ReportExportService().exportReport(
        report: report,
        roundingMode: settings.roundingMode,
        baselineHours: settings.shiftBaselineHours,
        ceilingHours: settings.shiftCeilingHours,
      );
      state = ReportExportState(successPath: path);
    } catch (_) {
      state = const ReportExportState(errorMessage: 'فشل تصدير التقرير');
    }
  }

  void clearResult() => state = const ReportExportState();
}

final reportExportProvider =
    NotifierProvider.autoDispose<ReportExportNotifier, ReportExportState>(
  ReportExportNotifier.new,
);
