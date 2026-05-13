import '../../../shared/utils/excel_utils.dart' as xu;
import '../domain/employee_import_result.dart';

class EmployeeImportService {
  static const _numberHeader = 'الرقم الوظيفي';
  static const _nameHeader = 'الاسم';
  static const _typeHeader = 'نوع التوظيف';
  static const _deptHeader = 'القسم';

  Future<EmployeeImportResult> parseFile(String path) async {
    final excel = await xu.openExcel(path);
    if (excel == null) {
      return const EmployeeImportFailure('تعذّر فتح الملف أو قراءته');
    }

    final List<ParsedEmployee> employees = [];
    bool anySheetMatched = false;

    for (final table in excel.tables.values) {
      if (table.rows.isEmpty) continue;

      final headers = xu.headerRow(table.rows.first);
      final numberCol = xu.findColumn(headers, [_numberHeader]);
      final nameCol = xu.findColumn(headers, [_nameHeader]);
      final typeCol = xu.findColumn(headers, [_typeHeader]);
      final deptCol = xu.findColumn(headers, [_deptHeader]);

      if (numberCol == null || nameCol == null || typeCol == null || deptCol == null) {
        continue;
      }
      anySheetMatched = true;

      for (final row in table.rows.skip(1)) {
        final number = xu.cellText(row.elementAtOrNull(numberCol));
        final name = xu.cellText(row.elementAtOrNull(nameCol));
        final typeStr = xu.cellText(row.elementAtOrNull(typeCol));
        final dept = xu.cellText(row.elementAtOrNull(deptCol));

        if (number == null || name == null || dept == null) continue;
        if (typeStr == null) continue;

        final employmentType = xu.parseEmploymentType(typeStr);
        if (employmentType == null) {
          return EmployeeImportFailure(
            'نوع التوظيف "$typeStr" غير معروف — القيم المقبولة: مناوب، صباحي',
          );
        }

        employees.add(ParsedEmployee(
          employeeNumber: number,
          name: name,
          employmentType: employmentType,
          department: dept,
        ));
      }
    }

    if (!anySheetMatched) {
      return const EmployeeImportFailure(
        'لم يُعثر على أعمدة مطابقة — تأكد من وجود: الرقم الوظيفي، الاسم، نوع التوظيف، القسم',
      );
    }
    if (employees.isEmpty) {
      return const EmployeeImportFailure('الملف لا يحتوي على صفوف صالحة');
    }

    return EmployeeImportParsed(employees);
  }
}

