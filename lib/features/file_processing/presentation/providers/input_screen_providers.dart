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

// ── File card state ───────────────────────────────────────────────────────────

sealed class FileCardState {
  const FileCardState();
}

class FileCardEmpty extends FileCardState {
  const FileCardEmpty();
}

class FileCardValid extends FileCardState {
  final List<String> fileNames;
  const FileCardValid(this.fileNames);
}

class FileCardInvalid extends FileCardState {
  final List<String> fileNames;
  final String errorMessage;
  const FileCardInvalid({required this.fileNames, required this.errorMessage});
}

// ── Screen state ─────────────────────────────────────────────────────────────

@immutable
class InputScreenState {
  final FileCardState attendanceState;
  final List<AttendanceRecord> attendanceData;
  final FileCardState employeesState;
  final List<Employee> employeesData;
  final FileCardState holidaysState;
  final List<Holiday> holidaysData;
  final DateTime? startDate;
  final DateTime? endDate;
  final int maxDateRange;
  final String? unexpectedError;

  const InputScreenState({
    required this.attendanceState,
    required this.attendanceData,
    required this.employeesState,
    required this.employeesData,
    required this.holidaysState,
    required this.holidaysData,
    required this.startDate,
    required this.endDate,
    required this.maxDateRange,
    this.unexpectedError,
  });

  factory InputScreenState.initial() => const InputScreenState(
        attendanceState: FileCardEmpty(),
        attendanceData: [],
        employeesState: FileCardEmpty(),
        employeesData: [],
        holidaysState: FileCardEmpty(),
        holidaysData: [],
        startDate: null,
        endDate: null,
        maxDateRange: 31,
        unexpectedError: null,
      );

  bool get canGenerate =>
      attendanceState is FileCardValid &&
      employeesState is FileCardValid &&
      holidaysState is FileCardValid &&
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
    FileCardState? attendanceState,
    List<AttendanceRecord>? attendanceData,
    FileCardState? employeesState,
    List<Employee>? employeesData,
    FileCardState? holidaysState,
    List<Holiday>? holidaysData,
    DateTime? startDate,
    DateTime? endDate,
    int? maxDateRange,
    String? unexpectedError,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearUnexpectedError = false,
  }) {
    return InputScreenState(
      attendanceState: attendanceState ?? this.attendanceState,
      attendanceData: attendanceData ?? this.attendanceData,
      employeesState: employeesState ?? this.employeesState,
      employeesData: employeesData ?? this.employeesData,
      holidaysState: holidaysState ?? this.holidaysState,
      holidaysData: holidaysData ?? this.holidaysData,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      maxDateRange: maxDateRange ?? this.maxDateRange,
      unexpectedError:
          clearUnexpectedError ? null : (unexpectedError ?? this.unexpectedError),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

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

    // Reset file cards whenever column headers are changed in Settings.
    ref.listen<int>(headersVersionProvider, (prev, next) {
      if (prev != null && next != prev) {
        state = state.copyWith(
          attendanceState: const FileCardEmpty(),
          attendanceData: [],
          employeesState: const FileCardEmpty(),
          employeesData: [],
          holidaysState: const FileCardEmpty(),
          holidaysData: [],
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

  Future<void> pickAttendanceFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null) return;

      final paths = result.files.map((f) => f.path!).toList();
      final names = result.files.map((f) => f.name).toList();

      final headers = await _headersRepo.getHeadersForFileType('attendance');
      final parsed = await _service.parseAttendanceFiles(paths, headers);

      switch (parsed) {
        case FileParseSuccess(:final data):
          state = state.copyWith(
            attendanceState: FileCardValid(names),
            attendanceData: data,
          );
        case FileParseFailure(:final errorMessage):
          state = state.copyWith(
            attendanceState:
                FileCardInvalid(fileNames: names, errorMessage: errorMessage),
            attendanceData: [],
          );
      }
    } catch (e) {
      debugPrint('pickAttendanceFiles error: $e');
      state = state.copyWith(
        attendanceState: FileCardInvalid(
          fileNames: [],
          errorMessage: 'تعذّرت قراءة الملف، تأكد من أنه غير مفتوح في برنامج آخر',
        ),
        attendanceData: [],
        unexpectedError: 'خطأ غير متوقع في ملف الحضور',
      );
    }
  }

  Future<void> pickEmployeesFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null) return;

      final paths = result.files.map((f) => f.path!).toList();
      final names = result.files.map((f) => f.name).toList();

      final headers = await _headersRepo.getHeadersForFileType('employees');
      final parsed = await _service.parseEmployeesFiles(paths, headers);

      switch (parsed) {
        case FileParseSuccess(:final data):
          state = state.copyWith(
            employeesState: FileCardValid(names),
            employeesData: data,
          );
        case FileParseFailure(:final errorMessage):
          state = state.copyWith(
            employeesState:
                FileCardInvalid(fileNames: names, errorMessage: errorMessage),
            employeesData: [],
          );
      }
    } catch (e) {
      debugPrint('pickEmployeesFiles error: $e');
      state = state.copyWith(
        employeesState: FileCardInvalid(
          fileNames: [],
          errorMessage: 'تعذّرت قراءة الملف، تأكد من أنه غير مفتوح في برنامج آخر',
        ),
        employeesData: [],
        unexpectedError: 'خطأ غير متوقع في ملف الموظفين',
      );
    }
  }

  Future<void> pickHolidaysFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null) return;

      final path = result.files.single.path!;
      final name = result.files.single.name;

      final headers = await _headersRepo.getHeadersForFileType('holidays');
      final parsed = await _service.parseHolidaysFile(path, headers);

      switch (parsed) {
        case FileParseSuccess(:final data):
          state = state.copyWith(
            holidaysState: FileCardValid([name]),
            holidaysData: data,
          );
        case FileParseFailure(:final errorMessage):
          state = state.copyWith(
            holidaysState:
                FileCardInvalid(fileNames: [name], errorMessage: errorMessage),
            holidaysData: [],
          );
      }
    } catch (e) {
      debugPrint('pickHolidaysFile error: $e');
      state = state.copyWith(
        holidaysState: FileCardInvalid(
          fileNames: [],
          errorMessage: 'تعذّرت قراءة الملف، تأكد من أنه غير مفتوح في برنامج آخر',
        ),
        holidaysData: [],
        unexpectedError: 'خطأ غير متوقع في ملف العطل',
      );
    }
  }

  void setStartDate(DateTime date) => state = state.copyWith(startDate: date);

  void setEndDate(DateTime date) => state = state.copyWith(endDate: date);

  void clearError() => state = state.copyWith(clearUnexpectedError: true);

  void reset() => state = InputScreenState.initial();
}

final inputScreenProvider =
    NotifierProvider<InputScreenNotifier, InputScreenState>(
  InputScreenNotifier.new,
);
