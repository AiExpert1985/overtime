import 'package:flutter_test/flutter_test.dart';
import 'package:overtime/features/reference_data/domain/employee_record.dart';
import 'package:overtime/features/reporting/presentation/providers/report_generation_screen_providers.dart';
import 'package:overtime/shared/domain/employee.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

FileEntryValid<AttendanceRawData> _validAtt(String path) => FileEntryValid(
      path: path,
      name: path,
      data: [('أحمد', DateTime(2024, 1, 1, 8, 0))],
    );

FileEntryInvalid<AttendanceRawData> _invalidAtt(String path) =>
    FileEntryInvalid(
      path: path,
      name: path,
      errorMessage: 'الملف لا يتطابق مع القالب المطلوب',
    );

final _oneEmployee = EmployeeRecord(
  id: 1,
  employeeNumber: '001',
  name: 'أحمد',
  employmentType: EmploymentType.daily,
  department: 'IT',
);

ReportGenerationScreenState _allValid({
  int max = 31,
  DateTime? start,
  DateTime? end,
  List<EmployeeRecord>? employees,
}) =>
    ReportGenerationScreenState(
      attendanceFiles: [_validAtt('a.xlsx')],
      selectedEmployees: employees ?? [_oneEmployee],
      startDate: start ?? DateTime(2024, 1, 1),
      endDate: end ?? DateTime(2024, 1, 31),
      maxDateRange: max,
    );

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── canGenerate ─────────────────────────────────────────────────────────────

  group('canGenerate', () {
    test('false on initial state — no files, no employees, no dates', () {
      expect(ReportGenerationScreenState.initial().canGenerate, isFalse);
    });

    test('false when attendance list is empty', () {
      final s = ReportGenerationScreenState(
        attendanceFiles: [],
        selectedEmployees: [_oneEmployee],
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 10),
        maxDateRange: 31,
      );
      expect(s.canGenerate, isFalse);
    });

    test('false when any attendance file is invalid', () {
      final s = ReportGenerationScreenState(
        attendanceFiles: [_validAtt('a1.xlsx'), _invalidAtt('a2.xlsx')],
        selectedEmployees: [_oneEmployee],
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 10),
        maxDateRange: 31,
      );
      expect(s.canGenerate, isFalse);
    });

    test('false when no employees are selected', () {
      final s = ReportGenerationScreenState(
        attendanceFiles: [_validAtt('a.xlsx')],
        selectedEmployees: [],
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 10),
        maxDateRange: 31,
      );
      expect(s.canGenerate, isFalse);
    });

    test('false when start date is null', () {
      final s = _allValid().copyWith(clearStartDate: true);
      expect(s.canGenerate, isFalse);
    });

    test('false when end date is null', () {
      final s = _allValid().copyWith(clearEndDate: true);
      expect(s.canGenerate, isFalse);
    });

    test('false when end date is before start date', () {
      final s =
          _allValid(start: DateTime(2024, 1, 10), end: DateTime(2024, 1, 9));
      expect(s.canGenerate, isFalse);
    });

    test('false when date range exceeds max', () {
      // 32 days > 31-day max
      final s = _allValid(
          max: 31, start: DateTime(2024, 1, 1), end: DateTime(2024, 2, 1));
      expect(s.canGenerate, isFalse);
    });

    test('true when attendance valid, employees selected, dates set, range ok',
        () {
      expect(_allValid().canGenerate, isTrue);
    });

    test('exactly maxDateRange days is permitted — inclusive boundary', () {
      // Jan 1–31 = 31 days, max = 31
      final s = _allValid(
          max: 31, start: DateTime(2024, 1, 1), end: DateTime(2024, 1, 31));
      expect(s.canGenerate, isTrue);
    });

    test('maxDateRange + 1 days is rejected', () {
      // Jan 1 – Feb 1 = 32 days, max = 31
      final s = _allValid(
          max: 31, start: DateTime(2024, 1, 1), end: DateTime(2024, 2, 1));
      expect(s.canGenerate, isFalse);
    });

    test('single-day range (start == end) is valid', () {
      final s =
          _allValid(start: DateTime(2024, 1, 15), end: DateTime(2024, 1, 15));
      expect(s.canGenerate, isTrue);
    });
  });

  // ── dateRangeError ──────────────────────────────────────────────────────────

  group('dateRangeError', () {
    test('null when both dates are null', () {
      expect(ReportGenerationScreenState.initial().dateRangeError, isNull);
    });

    test('null when range is valid', () {
      expect(_allValid().dateRangeError, isNull);
    });

    test('returns message when end is before start', () {
      final s =
          _allValid(start: DateTime(2024, 1, 10), end: DateTime(2024, 1, 9));
      expect(s.dateRangeError, isNotNull);
    });

    test('returns message when range exceeds max', () {
      final s = _allValid(
          max: 10, start: DateTime(2024, 1, 1), end: DateTime(2024, 1, 12));
      expect(s.dateRangeError, isNotNull);
    });

    test('null when start equals end — 1-day range is always valid', () {
      final s =
          _allValid(start: DateTime(2024, 6, 1), end: DateTime(2024, 6, 1));
      expect(s.dateRangeError, isNull);
    });
  });

  // ── attendanceData ──────────────────────────────────────────────────────────

  group('attendanceData', () {
    test(
        'combines raw pairs from multiple valid entries into one AttendanceRecord per name',
        () {
      final s = ReportGenerationScreenState(
        attendanceFiles: [
          FileEntryValid(
            path: 'a1.xlsx',
            name: 'a1.xlsx',
            data: [('أحمد', DateTime(2024, 1, 1, 8, 0))],
          ),
          FileEntryValid(
            path: 'a2.xlsx',
            name: 'a2.xlsx',
            data: [('أحمد', DateTime(2024, 1, 2, 8, 0))],
          ),
        ],
        selectedEmployees: [],
        startDate: null,
        endDate: null,
        maxDateRange: 31,
      );
      final records = s.attendanceData;
      expect(records, hasLength(1));
      expect(records.first.employeeName, 'أحمد');
      expect(records.first.fingerprints, hasLength(2));
    });

    test('excludes data from invalid entries', () {
      final s = ReportGenerationScreenState(
        attendanceFiles: [
          FileEntryValid(
            path: 'a1.xlsx',
            name: 'a1.xlsx',
            data: [('أحمد', DateTime(2024, 1, 1, 8, 0))],
          ),
          _invalidAtt('a2.xlsx'),
        ],
        selectedEmployees: [],
        startDate: null,
        endDate: null,
        maxDateRange: 31,
      );
      final records = s.attendanceData;
      expect(records, hasLength(1));
      expect(records.first.fingerprints, hasLength(1));
    });

    test('returns empty list when all attendance entries are invalid', () {
      final s = ReportGenerationScreenState(
        attendanceFiles: [_invalidAtt('a.xlsx')],
        selectedEmployees: [],
        startDate: null,
        endDate: null,
        maxDateRange: 31,
      );
      expect(s.attendanceData, isEmpty);
    });
  });

  // ── FileEntryView ───────────────────────────────────────────────────────────

  group('FileEntryView', () {
    test('valid entry: isValid true, errorMessage null', () {
      final view = _validAtt('a.xlsx').toView();
      expect(view.isValid, isTrue);
      expect(view.errorMessage, isNull);
    });

    test('invalid entry: isValid false, errorMessage present', () {
      final view = _invalidAtt('a.xlsx').toView();
      expect(view.isValid, isFalse);
      expect(view.errorMessage, isNotNull);
    });
  });
}
