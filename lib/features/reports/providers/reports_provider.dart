import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../data/reports_repository.dart';
import '../domain/daily_employee_row.dart';
import '../domain/report.dart';
import '../domain/shift_employee_row.dart';
import '../domain/undetected_employee_row.dart';
import '../domain/unified_employee_row.dart';

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

  Future<void> updateNotes(int id, String notes) async {
    await ref.read(reportsRepositoryProvider).updateNotes(id, notes);
    ref.invalidateSelf();
  }
}

final reportsProvider = AsyncNotifierProvider<ReportsNotifier, List<Report>>(
  ReportsNotifier.new,
);

// ---------------------------------------------------------------------------
// Report screen state
// ---------------------------------------------------------------------------

class ReportState {
  const ReportState({
    required this.report,
    required this.shiftRows,
    required this.dailyRows,
    required this.undetectedRows,
    this.search = '',
    this.deptFilter,
    this.showShiftType = true,
    this.showDailyType = true,
    this.showUndetectedType = true,
    this.showIncluded = true,
    this.showExcluded = true,
    this.hasOvertime = true,
    this.noOvertime = true,
  });

  final Report report;
  final List<ShiftEmployeeRow> shiftRows;
  final List<DailyEmployeeRow> dailyRows;
  final List<UndetectedEmployeeRow> undetectedRows;

  // Single filter surface shared by all three employee types.
  final String search;
  final String? deptFilter;

  // Type filter: which categories are currently visible in the merged list.
  // Paired-boolean convention below applies here too — all false → show none.
  final bool showShiftType;
  final bool showDailyType;
  final bool showUndetectedType;

  // Paired booleans: both true → show all; one true → filter to that category;
  // both false → show none.
  final bool showIncluded;
  final bool showExcluded;

  final bool hasOvertime;
  final bool noOvertime;

  // --- per-type summaries (used to build the type-aware aggregate cards) ---

  int get includedShift => shiftRows.where((r) => r.isIncluded).length;
  // A shift employee's overtime is definitionally working-day overtime —
  // shift has no off-day concept of its own.
  int get includedShiftOvertimeMinutes => shiftRows
      .where((r) => r.isIncluded)
      .fold(0, (s, r) => s + r.overtimeMinutes);

  int get includedDaily => dailyRows.where((r) => r.isIncluded).length;
  int get includedDailyOffOvertimeMinutes => dailyRows
      .where((r) => r.isIncluded)
      .fold(0, (s, r) => s + r.offOvertimeMinutes);
  int get includedDailyRegularOvertimeMinutes => dailyRows
      .where((r) => r.isIncluded)
      .fold(0, (s, r) => s + r.regularOvertimeMinutes);

  // --- aggregate cards (included employees only, driven by which types are
  // toggled visible) ---

  int get includedEmployees =>
      (showShiftType ? includedShift : 0) + (showDailyType ? includedDaily : 0);

  // Off-day overtime — daily only; shift has no off-day concept.
  int get includedOffOvertimeMinutes =>
      showDailyType ? includedDailyOffOvertimeMinutes : 0;

  // Working-day overtime — daily's regular-day overtime plus shift's
  // overtime, since both are earned on a working day.
  int get includedRegularOvertimeMinutes =>
      (showDailyType ? includedDailyRegularOvertimeMinutes : 0) +
      (showShiftType ? includedShiftOvertimeMinutes : 0);

  int get includedTotalOvertimeMinutes =>
      includedOffOvertimeMinutes + includedRegularOvertimeMinutes;

  // --- merged, filtered + sorted view ---

  List<UnifiedEmployeeRow> get visibleRows {
    if (!showShiftType && !showDailyType && !showUndetectedType) return [];
    if (!showIncluded && !showExcluded) return [];
    if (!hasOvertime && !noOvertime) return [];

    var list = <UnifiedEmployeeRow>[
      if (showShiftType) ...shiftRows.map(UnifiedEmployeeRow.shift),
      if (showDailyType) ...dailyRows.map(UnifiedEmployeeRow.daily),
      if (showUndetectedType)
        ...undetectedRows.map(UnifiedEmployeeRow.undetected),
    ];

    if (showIncluded && !showExcluded) {
      list = list.where((r) => r.isIncluded).toList();
    } else if (!showIncluded) {
      list = list.where((r) => !r.isIncluded).toList();
    }

    if (hasOvertime && !noOvertime) {
      list = list.where((r) => r.overtimeMinutes > 0).toList();
    } else if (!hasOvertime) {
      list = list.where((r) => r.overtimeMinutes == 0).toList();
    }

    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      list = list
          .where((r) => r.employeeName.toLowerCase().contains(q))
          .toList();
    }

    if (deptFilter != null) {
      list = list.where((r) => r.department == deptFilter).toList();
    }

    list.sort((a, b) => a.employeeName.compareTo(b.employeeName));
    return list;
  }

  static const Object _omit = Object();

  ReportState copyWith({
    List<ShiftEmployeeRow>? shiftRows,
    List<DailyEmployeeRow>? dailyRows,
    String? search,
    Object? deptFilter = _omit,
    bool? showShiftType,
    bool? showDailyType,
    bool? showUndetectedType,
    bool? showIncluded,
    bool? showExcluded,
    bool? hasOvertime,
    bool? noOvertime,
  }) => ReportState(
    report: report,
    shiftRows: shiftRows ?? this.shiftRows,
    dailyRows: dailyRows ?? this.dailyRows,
    undetectedRows: undetectedRows,
    search: search ?? this.search,
    deptFilter: deptFilter == _omit ? this.deptFilter : deptFilter as String?,
    showShiftType: showShiftType ?? this.showShiftType,
    showDailyType: showDailyType ?? this.showDailyType,
    showUndetectedType: showUndetectedType ?? this.showUndetectedType,
    showIncluded: showIncluded ?? this.showIncluded,
    showExcluded: showExcluded ?? this.showExcluded,
    hasOvertime: hasOvertime ?? this.hasOvertime,
    noOvertime: noOvertime ?? this.noOvertime,
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

  ReportState? get _current => switch (state) {
    AsyncData(:final value) => value,
    _ => null,
  };

  Future<void> toggleShiftIncluded(int rowId, bool included) async {
    final current = _current;
    if (current == null) return;
    await ref
        .read(reportsRepositoryProvider)
        .setIsIncluded(rowId, 'shift_employee_results', included);
    state = AsyncData(
      current.copyWith(
        shiftRows: current.shiftRows
            .map((r) => r.id == rowId ? r.copyWith(isIncluded: included) : r)
            .toList(),
      ),
    );
  }

  Future<void> toggleDailyIncluded(int rowId, bool included) async {
    final current = _current;
    if (current == null) return;
    await ref
        .read(reportsRepositoryProvider)
        .setIsIncluded(rowId, 'daily_employee_results', included);
    state = AsyncData(
      current.copyWith(
        dailyRows: current.dailyRows
            .map((r) => r.id == rowId ? r.copyWith(isIncluded: included) : r)
            .toList(),
      ),
    );
  }

  void setSearch(String q) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(search: q));
  }

  void setDeptFilter(String? v) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(deptFilter: v));
  }

  void setShowShiftType(bool v) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(showShiftType: v));
  }

  void setShowDailyType(bool v) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(showDailyType: v));
  }

  void setShowUndetectedType(bool v) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(showUndetectedType: v));
  }

  void setShowIncluded(bool v) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(showIncluded: v));
  }

  void setShowExcluded(bool v) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(showExcluded: v));
  }

  void setHasOvertime(bool v) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(hasOvertime: v));
  }

  void setNoOvertime(bool v) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(current.copyWith(noOvertime: v));
  }
}

final reportProvider = AsyncNotifierProvider.autoDispose
    .family<ReportNotifier, ReportState, int>(ReportNotifier.new);
