import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/column_headers_repository.dart';
import '../../../../shared/data/settings_repository.dart';
import '../../../../shared/database/database_helper.dart';
import '../../../../shared/domain/attendance_record.dart';
import '../../../../shared/domain/employee.dart';
import '../../../../shared/domain/holiday.dart';
import '../../application/file_processing_service.dart';
import '../../../reporting/presentation/providers/column_headers_providers.dart';

// ── Type alias ────────────────────────────────────────────────────────────────

typedef AttendanceRawData = List<(String, DateTime)>;

// ── FileEntry models ──────────────────────────────────────────────────────────

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

// ── FileEntryView (UI-facing, type-erased) ────────────────────────────────────

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

// ── Card type enum (used by dialog to know which list to watch) ───────────────

enum FileCardType { attendance, employees, holidays }

// ── Screen state ──────────────────────────────────────────────────────────────

@immutable
class InputScreenState {
  final List<FileEntry<AttendanceRawData>> attendanceFiles;
  final List<FileEntry<List<Employee>>> employeesFiles;
  final List<FileEntry<List<Holiday>>> holidaysFiles;
  final DateTime? startDate;
  final DateTime? endDate;
  final int maxDateRange;
  final String? unexpectedError;

  const InputScreenState({
    required this.attendanceFiles,
    required this.employeesFiles,
    required this.holidaysFiles,
    required this.startDate,
    required this.endDate,
    required this.maxDateRange,
    this.unexpectedError,
  });

  factory InputScreenState.initial() => const InputScreenState(
        attendanceFiles: [],
        employeesFiles: [],
        holidaysFiles: [],
        startDate: null,
        endDate: null,
        maxDateRange: 31,
        unexpectedError: null,
      );

  // ── Computed: combined data passed to generation pipeline ─────────────────

  List<AttendanceRecord> get attendanceData {
    final allPairs = attendanceFiles
        .whereType<FileEntryValid<AttendanceRawData>>()
        .expand((e) => e.data)
        .toList();
    return FileProcessingService.combineAttendanceData(allPairs);
  }

  List<Employee> get employeesData => employeesFiles
      .whereType<FileEntryValid<List<Employee>>>()
      .expand((e) => e.data)
      .toList();

  List<Holiday> get holidaysData => holidaysFiles
      .whereType<FileEntryValid<List<Holiday>>>()
      .expand((e) => e.data)
      .toList();

  // ── Computed: UI view models ───────────────────────────────────────────────

  List<FileEntryView> get attendanceViews =>
      attendanceFiles.map((f) => f.toView()).toList();

  List<FileEntryView> get employeesViews =>
      employeesFiles.map((f) => f.toView()).toList();

  List<FileEntryView> get holidaysViews =>
      holidaysFiles.map((f) => f.toView()).toList();

  // ── Generate readiness ────────────────────────────────────────────────────

  bool get _attendanceReady =>
      attendanceFiles.isNotEmpty &&
      attendanceFiles.every((f) => f is FileEntryValid);

  bool get _employeesReady =>
      employeesFiles.isNotEmpty &&
      employeesFiles.every((f) => f is FileEntryValid);

  bool get _holidaysReady =>
      holidaysFiles.isNotEmpty &&
      holidaysFiles.every((f) => f is FileEntryValid);

  bool get canGenerate =>
      _attendanceReady &&
      _employeesReady &&
      _holidaysReady &&
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

  InputScreenState copyWith({
    List<FileEntry<AttendanceRawData>>? attendanceFiles,
    List<FileEntry<List<Employee>>>? employeesFiles,
    List<FileEntry<List<Holiday>>>? holidaysFiles,
    DateTime? startDate,
    DateTime? endDate,
    int? maxDateRange,
    String? unexpectedError,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearUnexpectedError = false,
  }) {
    return InputScreenState(
      attendanceFiles: attendanceFiles ?? this.attendanceFiles,
      employeesFiles: employeesFiles ?? this.employeesFiles,
      holidaysFiles: holidaysFiles ?? this.holidaysFiles,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      maxDateRange: maxDateRange ?? this.maxDateRange,
      unexpectedError: clearUnexpectedError
          ? null
          : (unexpectedError ?? this.unexpectedError),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class InputScreenNotifier extends Notifier<InputScreenState> {
  late final FileProcessingService _service;
  late final ColumnHeadersRepository _headersRepo;
  late final SettingsRepository _settingsRepo;

  @override
  InputScreenState build() {
    _service = FileProcessingService();
    _headersRepo = ColumnHeadersRepository(DatabaseHelper.instance);
    _settingsRepo = SettingsRepository(DatabaseHelper.instance);
    Future.microtask(_loadMaxDateRange);

    // Reset file lists whenever column headers change in Settings.
    ref.listen<int>(headersVersionProvider, (prev, next) {
      if (prev != null && next != prev) {
        state = state.copyWith(
          attendanceFiles: [],
          employeesFiles: [],
          holidaysFiles: [],
        );
      }
    });

    return InputScreenState.initial();
  }

  Future<void> _loadMaxDateRange() async {
    final max =
        await _settingsRepo.getInt('max_report_date_range', defaultValue: 31);
    state = state.copyWith(maxDateRange: max);
  }

  // ── Add files ──────────────────────────────────────────────────────────────

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
      final headers =
          await _headersRepo.getHeadersForFileType('attendance');

      final newEntries = <FileEntry<AttendanceRawData>>[];
      for (final file in result.files) {
        final path = file.path!;
        if (existingPaths.contains(path.toLowerCase())) continue;
        final parsed = await _service.parseAttendanceSingle(path, headers);
        newEntries.add(switch (parsed) {
          FileParseSuccess(:final data) =>
            FileEntryValid(path: path, name: file.name, data: data),
          FileParseFailure(:final errorMessage) =>
            FileEntryInvalid(path: path, name: file.name, errorMessage: errorMessage),
        });
      }

      if (newEntries.isEmpty) return;
      state = state.copyWith(
        attendanceFiles: [...state.attendanceFiles, ...newEntries],
      );
    } catch (e) {
      debugPrint('addAttendanceFiles error: $e');
      state = state.copyWith(
        unexpectedError: 'خطأ غير متوقع في ملف الحضور',
      );
    }
  }

  Future<void> addEmployeesFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null) return;

      final existingPaths = {
        for (final f in state.employeesFiles) f.path.toLowerCase(),
      };
      final headers =
          await _headersRepo.getHeadersForFileType('employees');

      final newEntries = <FileEntry<List<Employee>>>[];
      for (final file in result.files) {
        final path = file.path!;
        if (existingPaths.contains(path.toLowerCase())) continue;
        final parsed = await _service.parseEmployeesSingle(path, headers);
        newEntries.add(switch (parsed) {
          FileParseSuccess(:final data) =>
            FileEntryValid(path: path, name: file.name, data: data),
          FileParseFailure(:final errorMessage) =>
            FileEntryInvalid(path: path, name: file.name, errorMessage: errorMessage),
        });
      }

      if (newEntries.isEmpty) return;
      state = state.copyWith(
        employeesFiles: [...state.employeesFiles, ...newEntries],
      );
    } catch (e) {
      debugPrint('addEmployeesFiles error: $e');
      state = state.copyWith(
        unexpectedError: 'خطأ غير متوقع في ملف الموظفين',
      );
    }
  }

  Future<void> addHolidaysFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null) return;

      final existingPaths = {
        for (final f in state.holidaysFiles) f.path.toLowerCase(),
      };
      final headers =
          await _headersRepo.getHeadersForFileType('holidays');

      final newEntries = <FileEntry<List<Holiday>>>[];
      for (final file in result.files) {
        final path = file.path!;
        if (existingPaths.contains(path.toLowerCase())) continue;
        final parsed = await _service.parseHolidaysFile(path, headers);
        newEntries.add(switch (parsed) {
          FileParseSuccess(:final data) =>
            FileEntryValid(path: path, name: file.name, data: data),
          FileParseFailure(:final errorMessage) =>
            FileEntryInvalid(path: path, name: file.name, errorMessage: errorMessage),
        });
      }

      if (newEntries.isEmpty) return;
      state = state.copyWith(
        holidaysFiles: [...state.holidaysFiles, ...newEntries],
      );
    } catch (e) {
      debugPrint('addHolidaysFiles error: $e');
      state = state.copyWith(
        unexpectedError: 'خطأ غير متوقع في ملف العطل',
      );
    }
  }

  // ── Remove individual files ────────────────────────────────────────────────

  void removeAttendanceFile(int index) {
    final updated = List.of(state.attendanceFiles)..removeAt(index);
    state = state.copyWith(attendanceFiles: updated);
  }

  void removeEmployeesFile(int index) {
    final updated = List.of(state.employeesFiles)..removeAt(index);
    state = state.copyWith(employeesFiles: updated);
  }

  void removeHolidaysFile(int index) {
    final updated = List.of(state.holidaysFiles)..removeAt(index);
    state = state.copyWith(holidaysFiles: updated);
  }

  // ── Other ─────────────────────────────────────────────────────────────────

  void setStartDate(DateTime date) => state = state.copyWith(startDate: date);
  void setEndDate(DateTime date) => state = state.copyWith(endDate: date);
  void clearError() => state = state.copyWith(clearUnexpectedError: true);
  void reset() => state = InputScreenState.initial();
}

final inputScreenProvider =
    NotifierProvider<InputScreenNotifier, InputScreenState>(
  InputScreenNotifier.new,
);
