import 'package:flutter_test/flutter_test.dart';
import 'package:overtime/features/file_processing/presentation/providers/input_screen_providers.dart';
import 'package:overtime/shared/domain/employee.dart';
import 'package:overtime/shared/domain/holiday.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

FileEntryValid<AttendanceRawData> _validAtt(String path) => FileEntryValid(
      path: path,
      name: path,
      data: [('أحمد', DateTime(2024, 1, 1, 8, 0))],
    );

FileEntryInvalid<AttendanceRawData> _invalidAtt(String path) => FileEntryInvalid(
      path: path,
      name: path,
      errorMessage: 'الملف لا يتطابق مع القالب المطلوب',
    );

FileEntryValid<List<Employee>> _validEmp(String path) => FileEntryValid(
      path: path,
      name: path,
      data: [
        Employee(name: 'أحمد', employmentType: EmploymentType.daily, department: 'IT'),
      ],
    );

FileEntryInvalid<List<Employee>> _invalidEmp(String path) => FileEntryInvalid(
      path: path,
      name: path,
      errorMessage: 'الملف لا يتطابق مع القالب المطلوب',
    );

FileEntryValid<List<Holiday>> _validHol(String path) => FileEntryValid(
      path: path,
      name: path,
      data: [Holiday(date: DateTime(2024, 1, 1), occasion: 'رأس السنة')],
    );

FileEntryInvalid<List<Holiday>> _invalidHol(String path) => FileEntryInvalid(
      path: path,
      name: path,
      errorMessage: 'الملف لا يتطابق مع القالب المطلوب',
    );

InputScreenState _allValid({
  int max = 31,
  DateTime? start,
  DateTime? end,
}) =>
    InputScreenState(
      attendanceFiles: [_validAtt('a.xlsx')],
      employeesFiles: [_validEmp('e.xlsx')],
      holidaysFiles: [_validHol('h.xlsx')],
      startDate: start ?? DateTime(2024, 1, 1),
      endDate: end ?? DateTime(2024, 1, 31),
      maxDateRange: max,
    );

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── canGenerate ─────────────────────────────────────────────────────────────

  group('canGenerate', () {
    test('false on initial state — all lists empty, no dates', () {
      expect(InputScreenState.initial().canGenerate, isFalse);
    });

    test('false when attendance list is empty', () {
      final s = InputScreenState(
        attendanceFiles: [],
        employeesFiles: [_validEmp('e.xlsx')],
        holidaysFiles: [_validHol('h.xlsx')],
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 10),
        maxDateRange: 31,
      );
      expect(s.canGenerate, isFalse);
    });

    test('false when any attendance file is invalid', () {
      final s = InputScreenState(
        attendanceFiles: [_validAtt('a1.xlsx'), _invalidAtt('a2.xlsx')],
        employeesFiles: [_validEmp('e.xlsx')],
        holidaysFiles: [_validHol('h.xlsx')],
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 10),
        maxDateRange: 31,
      );
      expect(s.canGenerate, isFalse);
    });

    test('false when employees list is empty', () {
      final s = InputScreenState(
        attendanceFiles: [_validAtt('a.xlsx')],
        employeesFiles: [],
        holidaysFiles: [_validHol('h.xlsx')],
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 10),
        maxDateRange: 31,
      );
      expect(s.canGenerate, isFalse);
    });

    test('false when any employees file is invalid', () {
      final s = InputScreenState(
        attendanceFiles: [_validAtt('a.xlsx')],
        employeesFiles: [_invalidEmp('e.xlsx')],
        holidaysFiles: [_validHol('h.xlsx')],
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 10),
        maxDateRange: 31,
      );
      expect(s.canGenerate, isFalse);
    });

    test('false when holidays list is empty', () {
      final s = InputScreenState(
        attendanceFiles: [_validAtt('a.xlsx')],
        employeesFiles: [_validEmp('e.xlsx')],
        holidaysFiles: [],
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 10),
        maxDateRange: 31,
      );
      expect(s.canGenerate, isFalse);
    });

    test('false when any holidays file is invalid', () {
      final s = InputScreenState(
        attendanceFiles: [_validAtt('a.xlsx')],
        employeesFiles: [_validEmp('e.xlsx')],
        holidaysFiles: [_invalidHol('h.xlsx')],
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
      final s = _allValid(start: DateTime(2024, 1, 10), end: DateTime(2024, 1, 9));
      expect(s.canGenerate, isFalse);
    });

    test('false when date range exceeds max', () {
      // 32 days > 31-day max
      final s = _allValid(max: 31, start: DateTime(2024, 1, 1), end: DateTime(2024, 2, 1));
      expect(s.canGenerate, isFalse);
    });

    test('true when all files valid, dates set, range within max', () {
      expect(_allValid().canGenerate, isTrue);
    });

    test('exactly maxDateRange days is permitted — inclusive boundary', () {
      // Jan 1–31 = 31 days, max = 31
      final s = _allValid(max: 31, start: DateTime(2024, 1, 1), end: DateTime(2024, 1, 31));
      expect(s.canGenerate, isTrue);
    });

    test('maxDateRange + 1 days is rejected', () {
      // Jan 1 – Feb 1 = 32 days, max = 31
      final s = _allValid(max: 31, start: DateTime(2024, 1, 1), end: DateTime(2024, 2, 1));
      expect(s.canGenerate, isFalse);
    });

    test('single-day range (start == end) is valid', () {
      final s = _allValid(start: DateTime(2024, 1, 15), end: DateTime(2024, 1, 15));
      expect(s.canGenerate, isTrue);
    });
  });

  // ── dateRangeError ──────────────────────────────────────────────────────────

  group('dateRangeError', () {
    test('null when both dates are null', () {
      expect(InputScreenState.initial().dateRangeError, isNull);
    });

    test('null when range is valid', () {
      expect(_allValid().dateRangeError, isNull);
    });

    test('returns message when end is before start', () {
      final s = _allValid(start: DateTime(2024, 1, 10), end: DateTime(2024, 1, 9));
      expect(s.dateRangeError, isNotNull);
    });

    test('returns message when range exceeds max', () {
      final s = _allValid(max: 10, start: DateTime(2024, 1, 1), end: DateTime(2024, 1, 12));
      expect(s.dateRangeError, isNotNull);
    });

    test('null when start equals end — 1-day range is always valid', () {
      final s = _allValid(start: DateTime(2024, 6, 1), end: DateTime(2024, 6, 1));
      expect(s.dateRangeError, isNull);
    });
  });

  // ── attendanceData ──────────────────────────────────────────────────────────

  group('attendanceData', () {
    test('combines raw pairs from multiple valid entries into one AttendanceRecord per name', () {
      final s = InputScreenState(
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
        employeesFiles: [],
        holidaysFiles: [],
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
      final s = InputScreenState(
        attendanceFiles: [
          FileEntryValid(
            path: 'a1.xlsx',
            name: 'a1.xlsx',
            data: [('أحمد', DateTime(2024, 1, 1, 8, 0))],
          ),
          _invalidAtt('a2.xlsx'),
        ],
        employeesFiles: [],
        holidaysFiles: [],
        startDate: null,
        endDate: null,
        maxDateRange: 31,
      );
      final records = s.attendanceData;
      expect(records, hasLength(1));
      expect(records.first.fingerprints, hasLength(1));
    });

    test('returns empty list when all attendance entries are invalid', () {
      final s = InputScreenState(
        attendanceFiles: [_invalidAtt('a.xlsx')],
        employeesFiles: [],
        holidaysFiles: [],
        startDate: null,
        endDate: null,
        maxDateRange: 31,
      );
      expect(s.attendanceData, isEmpty);
    });
  });

  // ── employeesData ───────────────────────────────────────────────────────────

  group('employeesData', () {
    test('combines employees from multiple valid entries', () {
      final s = InputScreenState(
        attendanceFiles: [],
        employeesFiles: [
          FileEntryValid(
            path: 'e1.xlsx',
            name: 'e1.xlsx',
            data: [Employee(name: 'أحمد', employmentType: EmploymentType.daily, department: 'IT')],
          ),
          FileEntryValid(
            path: 'e2.xlsx',
            name: 'e2.xlsx',
            data: [Employee(name: 'فاطمة', employmentType: EmploymentType.shift, department: 'HR')],
          ),
        ],
        holidaysFiles: [],
        startDate: null,
        endDate: null,
        maxDateRange: 31,
      );
      expect(s.employeesData, hasLength(2));
    });

    test('excludes data from invalid entries', () {
      final s = InputScreenState(
        attendanceFiles: [],
        employeesFiles: [_validEmp('e1.xlsx'), _invalidEmp('e2.xlsx')],
        holidaysFiles: [],
        startDate: null,
        endDate: null,
        maxDateRange: 31,
      );
      expect(s.employeesData, hasLength(1));
    });
  });

  // ── holidaysData (multi-file — upgraded in task 20260509-1500) ──────────────

  group('holidaysData', () {
    test('combines holidays from multiple valid entries', () {
      final s = InputScreenState(
        attendanceFiles: [],
        employeesFiles: [],
        holidaysFiles: [
          FileEntryValid(
            path: 'h1.xlsx',
            name: 'h1.xlsx',
            data: [Holiday(date: DateTime(2024, 1, 1), occasion: 'رأس السنة')],
          ),
          FileEntryValid(
            path: 'h2.xlsx',
            name: 'h2.xlsx',
            data: [Holiday(date: DateTime(2024, 3, 1), occasion: 'عطلة مارس')],
          ),
        ],
        startDate: null,
        endDate: null,
        maxDateRange: 31,
      );
      expect(s.holidaysData, hasLength(2));
    });

    test('excludes data from invalid entries', () {
      final s = InputScreenState(
        attendanceFiles: [],
        employeesFiles: [],
        holidaysFiles: [_validHol('h1.xlsx'), _invalidHol('h2.xlsx')],
        startDate: null,
        endDate: null,
        maxDateRange: 31,
      );
      expect(s.holidaysData, hasLength(1));
    });

    test('accepts more than one holidays file — multi-file upgrade', () {
      final s = InputScreenState(
        attendanceFiles: [],
        employeesFiles: [],
        holidaysFiles: [
          _validHol('h1.xlsx'),
          _validHol('h2.xlsx'),
          _validHol('h3.xlsx'),
        ],
        startDate: null,
        endDate: null,
        maxDateRange: 31,
      );
      // 1 holiday each × 3 files
      expect(s.holidaysData, hasLength(3));
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
