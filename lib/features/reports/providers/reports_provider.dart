import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../data/reports_repository.dart';
import '../domain/daily_employee_row.dart';
import '../domain/report.dart';
import '../domain/shift_employee_row.dart';
import '../domain/undetected_employee_row.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(dbProvider));
});

class ReportsNotifier extends AsyncNotifier<List<Report>> {
  @override
  Future<List<Report>> build() =>
      ref.read(reportsRepositoryProvider).loadReports();

  Future<void> deleteReport(int id) async {
    await ref.read(reportsRepositoryProvider).deleteReport(id);
    ref.invalidateSelf();
  }
}

final reportsProvider =
    AsyncNotifierProvider<ReportsNotifier, List<Report>>(ReportsNotifier.new);

// ---------------------------------------------------------------------------
// Report screen state
// ---------------------------------------------------------------------------

class ReportState {
  const ReportState({
    required this.report,
    required this.shiftRows,
    required this.dailyRows,
    required this.undetectedRows,
    this.shiftSearch = '',
    this.dailySearch = '',
    this.undetectedSearch = '',
    this.shiftShowIncluded = true,
    this.dailyShowIncluded = true,
    this.shiftOvertimeOnly = false,
    this.dailyOvertimeOnly = false,
  });

  final Report report;
  final List<ShiftEmployeeRow> shiftRows;
  final List<DailyEmployeeRow> dailyRows;
  final List<UndetectedEmployeeRow> undetectedRows;
  final String shiftSearch;
  final String dailySearch;
  final String undetectedSearch;
  final bool shiftShowIncluded;
  final bool dailyShowIncluded;
  final bool shiftOvertimeOnly;
  final bool dailyOvertimeOnly;

  // --- summaries (included employees only) ---

  int get totalShift => shiftRows.length;
  int get includedShift => shiftRows.where((r) => r.isIncluded).length;
  int get totalShiftOvertimeMinutes =>
      shiftRows.where((r) => r.isIncluded).fold(0, (s, r) => s + r.overtimeMinutes);

  int get totalDaily => dailyRows.length;
  int get includedDaily => dailyRows.where((r) => r.isIncluded).length;
  int get totalDailyOvertimeMinutes =>
      dailyRows.where((r) => r.isIncluded).fold(0, (s, r) => s + r.totalOvertimeMinutes);

  int get totalUndetected => undetectedRows.length;

  // --- filtered + sorted views ---

  List<ShiftEmployeeRow> get visibleShiftRows {
    var list = shiftRows.where((r) => r.isIncluded == shiftShowIncluded).toList();
    if (shiftOvertimeOnly) {
      list = list.where((r) => r.overtimeMinutes > 0).toList();
    }
    if (shiftSearch.isNotEmpty) {
      final q = shiftSearch.toLowerCase();
      list = list
          .where((r) =>
              r.employeeName.toLowerCase().contains(q) ||
              r.department.toLowerCase().contains(q))
          .toList();
    }
    list.sort((a, b) => a.employeeName.compareTo(b.employeeName));
    return list;
  }

  List<DailyEmployeeRow> get visibleDailyRows {
    var list = dailyRows.where((r) => r.isIncluded == dailyShowIncluded).toList();
    if (dailyOvertimeOnly) {
      list = list.where((r) => r.totalOvertimeMinutes > 0).toList();
    }
    if (dailySearch.isNotEmpty) {
      final q = dailySearch.toLowerCase();
      list = list
          .where((r) =>
              r.employeeName.toLowerCase().contains(q) ||
              r.department.toLowerCase().contains(q))
          .toList();
    }
    list.sort((a, b) => a.employeeName.compareTo(b.employeeName));
    return list;
  }

  List<UndetectedEmployeeRow> get visibleUndetectedRows {
    var list = List<UndetectedEmployeeRow>.from(undetectedRows);
    if (undetectedSearch.isNotEmpty) {
      final q = undetectedSearch.toLowerCase();
      list = list
          .where((r) =>
              r.employeeName.toLowerCase().contains(q) ||
              r.department.toLowerCase().contains(q))
          .toList();
    }
    list.sort((a, b) => a.employeeName.compareTo(b.employeeName));
    return list;
  }

  ReportState copyWith({
    List<ShiftEmployeeRow>? shiftRows,
    List<DailyEmployeeRow>? dailyRows,
    String? shiftSearch,
    String? dailySearch,
    String? undetectedSearch,
    bool? shiftShowIncluded,
    bool? dailyShowIncluded,
    bool? shiftOvertimeOnly,
    bool? dailyOvertimeOnly,
  }) =>
      ReportState(
        report: report,
        shiftRows: shiftRows ?? this.shiftRows,
        dailyRows: dailyRows ?? this.dailyRows,
        undetectedRows: undetectedRows,
        shiftSearch: shiftSearch ?? this.shiftSearch,
        dailySearch: dailySearch ?? this.dailySearch,
        undetectedSearch: undetectedSearch ?? this.undetectedSearch,
        shiftShowIncluded: shiftShowIncluded ?? this.shiftShowIncluded,
        dailyShowIncluded: dailyShowIncluded ?? this.dailyShowIncluded,
        shiftOvertimeOnly: shiftOvertimeOnly ?? this.shiftOvertimeOnly,
        dailyOvertimeOnly: dailyOvertimeOnly ?? this.dailyOvertimeOnly,
      );
}

class ReportNotifier extends AsyncNotifier<ReportState> {
  ReportNotifier(this._reportId);

  final int _reportId;

  @override
  Future<ReportState> build() async {
    final repo = ref.read(reportsRepositoryProvider);
    final reportFuture = repo.loadReport(_reportId);
    final shiftFuture = repo.loadShiftResults(_reportId);
    final dailyFuture = repo.loadDailyResults(_reportId);
    final undetectedFuture = repo.loadUndetectedResults(_reportId);
    return ReportState(
      report: await reportFuture,
      shiftRows: await shiftFuture,
      dailyRows: await dailyFuture,
      undetectedRows: await undetectedFuture,
    );
  }

  ReportState? get _current =>
      switch (state) { AsyncData(:final value) => value, _ => null };

  Future<void> toggleShiftIncluded(int rowId, bool included) async {
    final current = _current;
    if (current == null) return;
    await ref
        .read(reportsRepositoryProvider)
        .setIsIncluded(rowId, 'shift_employee_results', included);
    state = AsyncData(current.copyWith(
      shiftRows: current.shiftRows
          .map((r) => r.id == rowId ? r.copyWith(isIncluded: included) : r)
          .toList(),
    ));
  }

  Future<void> toggleDailyIncluded(int rowId, bool included) async {
    final current = _current;
    if (current == null) return;
    await ref
        .read(reportsRepositoryProvider)
        .setIsIncluded(rowId, 'daily_employee_results', included);
    state = AsyncData(current.copyWith(
      dailyRows: current.dailyRows
          .map((r) => r.id == rowId ? r.copyWith(isIncluded: included) : r)
          .toList(),
    ));
  }

  void setShiftSearch(String q) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(shiftSearch: q));
  }

  void setDailySearch(String q) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(dailySearch: q));
  }

  void setUndetectedSearch(String q) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(undetectedSearch: q));
  }

  void setShiftFilter(bool showIncluded) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(shiftShowIncluded: showIncluded));
  }

  void setDailyFilter(bool showIncluded) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(dailyShowIncluded: showIncluded));
  }

  void setShiftOvertimeFilter(bool overtimeOnly) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(shiftOvertimeOnly: overtimeOnly));
  }

  void setDailyOvertimeFilter(bool overtimeOnly) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(dailyOvertimeOnly: overtimeOnly));
  }
}

final reportProvider =
    AsyncNotifierProvider.family<ReportNotifier, ReportState, int>(
  ReportNotifier.new,
);
