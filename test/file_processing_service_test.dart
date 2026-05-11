import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overtime/features/file_processing/application/file_processing_service.dart';
import 'package:overtime/shared/domain/attendance_record.dart';
import 'package:overtime/shared/domain/employee.dart';

// ── test helpers ─────────────────────────────────────────────────────────────

/// Writes an xlsx file with one sheet, returns the file path.
Future<String> _makeExcel(
  Directory dir,
  String name,
  List<List<CellValue?>> rowsIncludingHeader,
) async {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  for (final row in rowsIncludingHeader) {
    sheet.appendRow(row);
  }
  final bytes = excel.save()!;
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  return file.path;
}

// ── test setup ────────────────────────────────────────────────────────────────

void main() {
  late FileProcessingService service;
  late Directory tmp;

  const attendanceCols = {
    'employee_name': ['اسم الموظف'],
    'datetime': ['التاريخ والوقت'],
  };

  const employeesCols = {
    'employee_name': ['اسم الموظف'],
    'employment_type': ['نوع التوظيف'],
    'department': ['القسم'],
  };

  const holidaysCols = {
    'date': ['التاريخ'],
    'occasion': ['مناسبة العطلة'],
  };

  setUp(() async {
    service = FileProcessingService();
    tmp = await Directory.systemTemp.createTemp('overtime_test_');
  });

  tearDown(() => tmp.delete(recursive: true));

  // ── parseAttendanceFiles ─────────────────────────────────────────────────

  group('parseAttendanceFiles', () {
    test('returns success with correct employee and sorted fingerprints', () async {
      final path = await _makeExcel(tmp, 'att.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('التاريخ والوقت')],
        [TextCellValue('أحمد علي'), TextCellValue('2024-01-15 08:30:00')],
        [TextCellValue('أحمد علي'), TextCellValue('2024-01-15 07:00:00')],
      ]);

      final result = await service.parseAttendanceFiles([path], attendanceCols);
      expect(result, isA<FileParseSuccess<List<AttendanceRecord>>>());

      final records = (result as FileParseSuccess<List<AttendanceRecord>>).data;
      expect(records, hasLength(1));
      expect(records.first.employeeName, 'أحمد علي');
      // fingerprints must be sorted ascending
      expect(records.first.fingerprints.first, DateTime(2024, 1, 15, 7, 0, 0));
      expect(records.first.fingerprints.last, DateTime(2024, 1, 15, 8, 30, 0));
    });

    test('trims header whitespace before matching column names', () async {
      final path = await _makeExcel(tmp, 'att_spaces.xlsx', [
        [TextCellValue('  اسم الموظف  '), TextCellValue('  التاريخ والوقت  ')],
        [TextCellValue('سارة'), TextCellValue('2024-02-01 09:00:00')],
      ]);

      final result = await service.parseAttendanceFiles([path], attendanceCols);
      expect(result, isA<FileParseSuccess<List<AttendanceRecord>>>());
    });

    test('merges fingerprints across multiple files for the same employee', () async {
      final path1 = await _makeExcel(tmp, 'att1.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('التاريخ والوقت')],
        [TextCellValue('خالد'), TextCellValue('2024-01-10 08:00:00')],
      ]);
      final path2 = await _makeExcel(tmp, 'att2.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('التاريخ والوقت')],
        [TextCellValue('خالد'), TextCellValue('2024-01-11 08:00:00')],
      ]);

      final result = await service.parseAttendanceFiles([path1, path2], attendanceCols);
      final records = (result as FileParseSuccess<List<AttendanceRecord>>).data;
      expect(records.first.fingerprints, hasLength(2));
    });

    test('returns failure when no sheet has matching headers', () async {
      final path = await _makeExcel(tmp, 'att_bad.xlsx', [
        [TextCellValue('col1'), TextCellValue('col2')],
        [TextCellValue('أحمد'), TextCellValue('2024-01-01 08:00:00')],
      ]);

      final result = await service.parseAttendanceFiles([path], attendanceCols);
      expect(result, isA<FileParseFailure<List<AttendanceRecord>>>());
      expect(
        (result as FileParseFailure).errorMessage,
        'الملف لا يتطابق مع القالب المطلوب',
      );
    });

    test('returns failure when file has matching headers but no valid rows', () async {
      final path = await _makeExcel(tmp, 'att_empty.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('التاريخ والوقت')],
        // row with empty name
        [TextCellValue(''), TextCellValue('2024-01-01 08:00:00')],
      ]);

      final result = await service.parseAttendanceFiles([path], attendanceCols);
      expect(result, isA<FileParseFailure<List<AttendanceRecord>>>());
      expect(
        (result as FileParseFailure).errorMessage,
        'الملف لا يحتوي على صفوف صالحة',
      );
    });

    test('first file failure aborts and returns its error message', () async {
      final bad = await _makeExcel(tmp, 'bad.xlsx', [
        [TextCellValue('col1'), TextCellValue('col2')],
      ]);
      final good = await _makeExcel(tmp, 'good.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('التاريخ والوقت')],
        [TextCellValue('علي'), TextCellValue('2024-01-01 08:00:00')],
      ]);

      final result = await service.parseAttendanceFiles([bad, good], attendanceCols);
      expect(result, isA<FileParseFailure>());
    });
  });

  // ── parseEmployeesFiles ──────────────────────────────────────────────────

  group('parseEmployeesFiles', () {
    test('parses shift employee (مناوب) correctly', () async {
      final path = await _makeExcel(tmp, 'emp.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('نوع التوظيف'), TextCellValue('القسم')],
        [TextCellValue('فاطمة'), TextCellValue('مناوب'), TextCellValue('الأمن')],
      ]);

      final result = await service.parseEmployeesFiles([path], employeesCols);
      final employees = (result as FileParseSuccess<List<Employee>>).data;
      expect(employees.first.employmentType, EmploymentType.shift);
      expect(employees.first.department, 'الأمن');
    });

    test('parses daily employee (صباحي) correctly', () async {
      final path = await _makeExcel(tmp, 'emp_daily.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('نوع التوظيف'), TextCellValue('القسم')],
        [TextCellValue('محمد'), TextCellValue('صباحي'), TextCellValue('المالية')],
      ]);

      final result = await service.parseEmployeesFiles([path], employeesCols);
      final employees = (result as FileParseSuccess<List<Employee>>).data;
      expect(employees.first.employmentType, EmploymentType.daily);
    });

    test('returns failure for unrecognized employment type — rejects entire file', () async {
      final path = await _makeExcel(tmp, 'emp_bad_type.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('نوع التوظيف'), TextCellValue('القسم')],
        [TextCellValue('علي'), TextCellValue('نوع_غير_معروف'), TextCellValue('IT')],
      ]);

      final result = await service.parseEmployeesFiles([path], employeesCols);
      expect(result, isA<FileParseFailure<List<Employee>>>());
      expect(
        (result as FileParseFailure).errorMessage,
        'نوع التوظيف غير معروف في ملف الموظفين',
      );
    });

    test('returns failure when no sheet has matching headers', () async {
      final path = await _makeExcel(tmp, 'emp_no_headers.xlsx', [
        [TextCellValue('a'), TextCellValue('b'), TextCellValue('c')],
        [TextCellValue('x'), TextCellValue('y'), TextCellValue('z')],
      ]);

      final result = await service.parseEmployeesFiles([path], employeesCols);
      expect(result, isA<FileParseFailure<List<Employee>>>());
      expect(
        (result as FileParseFailure).errorMessage,
        'الملف لا يتطابق مع القالب المطلوب',
      );
    });

    test('returns failure when file has matching headers but no valid rows', () async {
      final path = await _makeExcel(tmp, 'emp_no_rows.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('نوع التوظيف'), TextCellValue('القسم')],
        // all cells missing
        [TextCellValue(''), TextCellValue(''), TextCellValue('')],
      ]);

      final result = await service.parseEmployeesFiles([path], employeesCols);
      expect(result, isA<FileParseFailure<List<Employee>>>());
      expect(
        (result as FileParseFailure).errorMessage,
        'الملف لا يحتوي على صفوف صالحة',
      );
    });
  });

  // ── parseHolidaysFile ────────────────────────────────────────────────────

  group('parseHolidaysFile', () {
    test('returns success with correct holiday data', () async {
      final path = await _makeExcel(tmp, 'hol.xlsx', [
        [TextCellValue('التاريخ'), TextCellValue('مناسبة العطلة')],
        [TextCellValue('2024-01-01'), TextCellValue('رأس السنة')],
      ]);

      final result = await service.parseHolidaysFile(path, holidaysCols);
      expect(result, isA<FileParseSuccess>());
    });

    test('returns failure when no sheet has matching headers', () async {
      final path = await _makeExcel(tmp, 'hol_bad.xlsx', [
        [TextCellValue('col1'), TextCellValue('col2')],
        [TextCellValue('2024-01-01'), TextCellValue('عطلة')],
      ]);

      final result = await service.parseHolidaysFile(path, holidaysCols);
      expect(result, isA<FileParseFailure>());
      expect(
        (result as FileParseFailure).errorMessage,
        'الملف لا يتطابق مع القالب المطلوب',
      );
    });

    test('returns failure when rows have missing occasion field', () async {
      final path = await _makeExcel(tmp, 'hol_empty.xlsx', [
        [TextCellValue('التاريخ'), TextCellValue('مناسبة العطلة')],
        [TextCellValue('2024-01-01'), TextCellValue('')],
      ]);

      final result = await service.parseHolidaysFile(path, holidaysCols);
      expect(result, isA<FileParseFailure>());
      expect(
        (result as FileParseFailure).errorMessage,
        'الملف لا يحتوي على صفوف صالحة',
      );
    });

    test('parses a single file per call — notifier calls in a loop for multi-file support', () async {
      // parseHolidaysFile is a per-file function. The holidays card now supports
      // multiple files (task 20260509-1500): the notifier calls this once per file.
      final path = await _makeExcel(tmp, 'hol2.xlsx', [
        [TextCellValue('التاريخ'), TextCellValue('مناسبة العطلة')],
        [TextCellValue('2024-03-01'), TextCellValue('عطلة مارس')],
      ]);
      final result = await service.parseHolidaysFile(path, holidaysCols);
      expect(result, isA<FileParseSuccess>());
    });
  });

  // ── timestamp format: M/D/YYYY AM/PM ────────────────────────────────────

  group('timestamp format M/D/yyyy H:mm:ss AM/PM', () {
    test('parses AM timestamp correctly — month is first', () async {
      final path = await _makeExcel(tmp, 'att_ampm.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('التاريخ والوقت')],
        // 10/2/2025 = October 2, 2025 (M/D/yyyy); 7:53 AM
        [TextCellValue('أحمد'), TextCellValue('10/2/2025  7:53:07 AM')],
      ]);

      final result = await service.parseAttendanceSingle(path, attendanceCols);
      final pairs = (result as FileParseSuccess<List<(String, DateTime)>>).data;
      expect(pairs.first.$2, DateTime(2025, 10, 2, 7, 53, 7));
    });

    test('parses PM timestamp — hour shifted to 24-hour', () async {
      final path = await _makeExcel(tmp, 'att_pm.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('التاريخ والوقت')],
        // 3:30 PM → hour 15
        [TextCellValue('سارة'), TextCellValue('10/2/2025  3:30:00 PM')],
      ]);

      final result = await service.parseAttendanceSingle(path, attendanceCols);
      final pairs = (result as FileParseSuccess<List<(String, DateTime)>>).data;
      expect(pairs.first.$2, DateTime(2025, 10, 2, 15, 30, 0));
    });

    test('12:00 PM stays 12 (noon)', () async {
      final path = await _makeExcel(tmp, 'att_noon.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('التاريخ والوقت')],
        [TextCellValue('علي'), TextCellValue('10/2/2025  12:00:00 PM')],
      ]);

      final result = await service.parseAttendanceSingle(path, attendanceCols);
      final pairs = (result as FileParseSuccess<List<(String, DateTime)>>).data;
      expect(pairs.first.$2, DateTime(2025, 10, 2, 12, 0, 0));
    });

    test('12:00 AM converts to midnight (hour 0)', () async {
      final path = await _makeExcel(tmp, 'att_midnight.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('التاريخ والوقت')],
        [TextCellValue('خالد'), TextCellValue('10/2/2025  12:00:00 AM')],
      ]);

      final result = await service.parseAttendanceSingle(path, attendanceCols);
      final pairs = (result as FileParseSuccess<List<(String, DateTime)>>).data;
      expect(pairs.first.$2, DateTime(2025, 10, 2, 0, 0, 0));
    });

    test('unrecognized datetime text returns failure immediately', () async {
      final path = await _makeExcel(tmp, 'att_bad_dt.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('التاريخ والوقت')],
        [TextCellValue('محمد'), TextCellValue('not-a-date')],
      ]);

      final result = await service.parseAttendanceSingle(path, attendanceCols);
      expect(result, isA<FileParseFailure>());
      expect(
        (result as FileParseFailure).errorMessage,
        'تعذّر تحليل تاريخ الحضور في أحد الصفوف',
      );
    });
  });

  // ── invisible character stripping ─────────────────────────────────────────

  group('invisible character stripping', () {
    test('RTL mark appended to column header still matches accepted value', () async {
      final path = await _makeExcel(tmp, 'att_rtl_hdr.xlsx', [
        // ‏ = right-to-left mark, embedded by Excel in Arabic cells
        [TextCellValue('اسم الموظف‏'), TextCellValue('التاريخ والوقت')],
        [TextCellValue('أحمد'), TextCellValue('2024-01-01 08:00:00')],
      ]);

      final result = await service.parseAttendanceSingle(path, attendanceCols);
      expect(result, isA<FileParseSuccess>());
    });

    test('BOM prepended to column header still matches accepted value', () async {
      final path = await _makeExcel(tmp, 'att_bom_hdr.xlsx', [
        // ﻿ = byte-order mark, sometimes prepended by Excel
        [TextCellValue('اسم الموظف'), TextCellValue('﻿التاريخ والوقت')],
        [TextCellValue('سارة'), TextCellValue('2024-02-01 09:00:00')],
      ]);

      final result = await service.parseAttendanceSingle(path, attendanceCols);
      expect(result, isA<FileParseSuccess>());
    });

    test('RTL/LTR marks wrapping employee name are stripped — visible name preserved', () async {
      final path = await _makeExcel(tmp, 'att_rtl_name.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('التاريخ والوقت')],
        // ‎ = LTR mark, ‏ = RTL mark
        [TextCellValue('‎أحمد علي‏'), TextCellValue('2024-01-15 08:00:00')],
      ]);

      final result = await service.parseAttendanceSingle(path, attendanceCols);
      final pairs = (result as FileParseSuccess<List<(String, DateTime)>>).data;
      expect(pairs.first.$1, 'أحمد علي');
    });

    test('zero-width space inside employee name is stripped', () async {
      final path = await _makeExcel(tmp, 'att_zwsp.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('التاريخ والوقت')],
        // ​ = zero-width space between name parts
        [TextCellValue('محمد​علي'), TextCellValue('2024-01-01 09:00:00')],
      ]);

      final result = await service.parseAttendanceSingle(path, attendanceCols);
      final pairs = (result as FileParseSuccess<List<(String, DateTime)>>).data;
      expect(pairs.first.$1, 'محمدعلي');
    });

    test('name cell containing only invisible characters is treated as empty — row skipped', () async {
      final path = await _makeExcel(tmp, 'att_invisible_only.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('التاريخ والوقت')],
        // zero-width space + BOM + LTR mark — all invisible, cleaned to empty string
        [TextCellValue('​﻿‎'), TextCellValue('2024-01-01 08:00:00')],
      ]);

      final result = await service.parseAttendanceSingle(path, attendanceCols);
      expect(result, isA<FileParseFailure>());
      expect(
        (result as FileParseFailure).errorMessage,
        'الملف لا يحتوي على صفوف صالحة',
      );
    });

    test('invisible chars stripped from employment type cell — shift type recognized', () async {
      final path = await _makeExcel(tmp, 'emp_rtl_type.xlsx', [
        [TextCellValue('اسم الموظف'), TextCellValue('نوع التوظيف'), TextCellValue('القسم')],
        // ‏ appended to employment type value by Excel
        [TextCellValue('فاطمة'), TextCellValue('مناوب‏'), TextCellValue('الأمن')],
      ]);

      final result = await service.parseEmployeesSingle(path, employeesCols);
      final employees = (result as FileParseSuccess<List<Employee>>).data;
      expect(employees.first.employmentType, EmploymentType.shift);
    });

    test('invisible chars stripped from employees column headers', () async {
      final path = await _makeExcel(tmp, 'emp_inv_hdr.xlsx', [
        [
          // \u202B = RTL embedding, \u202C = pop directional formatting
          TextCellValue('\u202Bاسم الموظف\u202C'),
          TextCellValue('نوع التوظيف'),
          TextCellValue('القسم'),
        ],
        [TextCellValue('علي'), TextCellValue('صباحي'), TextCellValue('المالية')],
      ]);

      final result = await service.parseEmployeesSingle(path, employeesCols);
      expect(result, isA<FileParseSuccess>());
    });
  });
}
