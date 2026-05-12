import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/column_headers_repository.dart';
import '../../../../shared/data/settings_repository.dart';
import '../../../../shared/database/database_helper.dart';
import '../../../../shared/domain/attendance_record.dart';
import '../../../file_processing/application/file_processing_service.dart';
import '../../../reference_data/data/reference_data_repository.dart';
import '../../../reference_data/domain/employee_record.dart';
import 'column_headers_providers.dart';

// ── Type alias ─────────────────────────────────────────────────────────────────

typedef AttendanceRawData = List<(String, DateTime)>;

// ── FileEntry models ───────────────────────────────────────────────────────────

sealed class FileEntry<T> {
  final String path;
  final String name;
  const FileEntry({required this.path, required this.name});

  FileEntryView toView() => FileEntryView(
        name: name,
        isValid: this is FileEntryValid<T>,
        errorMessage: switch (this) {
          FileEntryInvalid(:final errorMessage) => errorMessage,
          _ => null,
        },
      );
}

class FileEntryValid<T> extends FileEntry<T> {
  final T data;
  const FileEntryValid({
    required super.path,
    required super.name,
    required this.data,
  });
}

class FileEntryInvalid<T> extends FileEntry<T> {
  final String errorMessage;
  const FileEntryInvalid({
    required super.path,
    required super.name,
    required this.errorMessage,
  });
}

// ── FileEntryView (UI-facing, type-erased) ─────────────────────────────────────

class FileEntryView {
  final String name;
  final bool isValid;
  final String? errorMessage;
  const FileEntryView({
    required this.name,
    required this.isValid,
    this.errorMessage,
  });
}

// ── Screen state ───────────────────────────────────────────────────────────────

@immutable
class ReportGenerationScreenState {
  final List<FileEntry<AttendanceRawData>> attendanceFiles;
  final DateTime? startDate;
  final DateTime? endDate;
  final int maxDateRange;
  final String? unexpectedError;
  final List<EmployeeRecord> selectedEmployees;

  const ReportGenerationScreenState({
    required this.attendanceFiles,
    required this.startDate,
    required this.endDate,
    required this.maxDateRange,
    required this.selectedEmployees,
    this.unexpectedError,
  });

  factory ReportGenerationScreenState.initial() =>
      const ReportGenerationScreenState(
        attendanceFiles: [],
        startDate: null,
        endDate: null,
        maxDateRange: 31,
        selectedEmployees: [],
        unexpectedError: null,
      );

  // ── Computed ───────────────────────────────────────────────────────────────

  List<AttendanceRecord> get attendanceData {
    final allPairs = attendanceFiles
        .whereType<FileEntryValid<AttendanceRawData>>()
        .expand((e) => e.data)
        .toList();
    return FileProcessingService.combineAttendanceData(allPairs);
  }

  List<FileEntryView> get attendanceViews =>
      attendanceFiles.map((f) => f.toView()).toList();

  bool get _attendanceReady =>
      attendanceFiles.isNotEmpty &&
      attendanceFiles.every((f) => f is FileEntryValid);

  bool get canGenerate =>
      _attendanceReady &&
      selectedEmployees.isNotEmpty &&
      startDate != null &&
      endDate != null &&
      dateRangeError == null;

  String? get dateRangeError {
    if (startDate == null || endDate == null) return null;
    if (endDate!.isBefore(startDate!)) {
      return 'يجب أن يكون تاريخ النهاية بعد تاريخ البداية أو مساوياً له';
    }
    final days = endDate!.difference(startDate!).inDays + 1;
    if (days > maxDateRange) {
      return 'يجب أن لا تتجاوز مدة التقرير $maxDateRange يوماً';
    }
    return null;
  }

  ReportGenerationScreenState copyWith({
    List<FileEntry<AttendanceRawData>>? attendanceFiles,
    DateTime? startDate,
    DateTime? endDate,
    int? maxDateRange,
    String? unexpectedError,
    List<EmployeeRecord>? selectedEmployees,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearUnexpectedError = false,
  }) {
    return ReportGenerationScreenState(
      attendanceFiles: attendanceFiles ?? this.attendanceFiles,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      maxDateRange: maxDateRange ?? this.maxDateRange,
      selectedEmployees: selectedEmployees ?? this.selectedEmployees,
      unexpectedError: clearUnexpectedError
          ? null
          : (unexpectedError ?? this.unexpectedError),
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class ReportGenerationScreenNotifier
    extends Notifier<ReportGenerationScreenState> {
  late final FileProcessingService _service;
  late final ColumnHeadersRepository _headersRepo;
  late final SettingsRepository _settingsRepo;
  late final ReferenceDataRepository _refRepo;

  @override
  ReportGenerationScreenState build() {
    _service = FileProcessingService();
    _headersRepo = ColumnHeadersRepository(DatabaseHelper.instance);
    _settingsRepo = SettingsRepository(DatabaseHelper.instance);
    _refRepo = ReferenceDataRepository(DatabaseHelper.instance);

    Future.microtask(_init);

    ref.listen<int>(headersVersionProvider, (prev, next) {
      if (prev != null && next != prev) {
        state = state.copyWith(attendanceFiles: []);
      }
    });

    return ReportGenerationScreenState.initial();
  }

  Future<void> _init() async {
    final max =
        await _settingsRepo.getInt('max_report_date_range', defaultValue: 31);
    state = state.copyWith(maxDateRange: max);

    final savedIds = await _refRepo.getSelectedEmployeeIds();
    if (savedIds.isEmpty) return;

    final allEmployees = await _refRepo.getAllEmployees();
    final savedSet = savedIds.toSet();
    final selected =
        allEmployees.where((e) => savedSet.contains(e.id)).toList();
    if (selected.isNotEmpty) {
      state = state.copyWith(selectedEmployees: selected);
    }
  }

  Future<void> addAttendanceFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null) return;

      final existingPaths = {
        for (final f in state.attendanceFiles) f.path.toLowerCase(),
      };
      final headers = await _headersRepo.getHeadersForFileType('attendance');

      final newEntries = <FileEntry<AttendanceRawData>>[];
      for (final file in result.files) {
        final path = file.path!;
        if (existingPaths.contains(path.toLowerCase())) continue;
        final parsed = await _service.parseAttendanceSingle(path, headers);
        newEntries.add(switch (parsed) {
          FileParseSuccess(:final data) =>
            FileEntryValid(path: path, name: file.name, data: data),
          FileParseFailure(:final errorMessage) =>
            FileEntryInvalid(
                path: path, name: file.name, errorMessage: errorMessage),
        });
      }

      if (newEntries.isEmpty) return;
      state = state.copyWith(
        attendanceFiles: [...state.attendanceFiles, ...newEntries],
      );
    } catch (e) {
      debugPrint('addAttendanceFiles error: $e');
      state = state.copyWith(unexpectedError: 'خطأ غير متوقع في ملف الحضور');
    }
  }

  void removeAttendanceFile(int index) {
    final updated = List.of(state.attendanceFiles)..removeAt(index);
    state = state.copyWith(attendanceFiles: updated);
  }

  void setStartDate(DateTime date) => state = state.copyWith(startDate: date);
  void setEndDate(DateTime date) => state = state.copyWith(endDate: date);
  void clearError() => state = state.copyWith(clearUnexpectedError: true);

  void setSelectedEmployees(List<EmployeeRecord> employees) =>
      state = state.copyWith(selectedEmployees: employees);

  void clearSelectedEmployees() =>
      state = state.copyWith(selectedEmployees: []);

  Future<void> saveSelectionToDb() async {
    await _refRepo.saveSelectedEmployeeIds(
      state.selectedEmployees.map((e) => e.id).toList(),
    );
  }
}

final reportGenerationScreenProvider = NotifierProvider<
    ReportGenerationScreenNotifier, ReportGenerationScreenState>(
  ReportGenerationScreenNotifier.new,
);
