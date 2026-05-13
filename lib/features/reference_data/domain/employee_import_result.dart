import '../../../shared/domain/employee.dart';

sealed class EmployeeImportResult {
  const EmployeeImportResult();
}

class EmployeeImportParsed extends EmployeeImportResult {
  final List<ParsedEmployee> employees;
  const EmployeeImportParsed(this.employees);
}

class EmployeeImportFailure extends EmployeeImportResult {
  final String message;
  const EmployeeImportFailure(this.message);
}

class ParsedEmployee {
  final String employeeNumber;
  final String name;
  final EmploymentType employmentType;
  final String department;

  const ParsedEmployee({
    required this.employeeNumber,
    required this.name,
    required this.employmentType,
    required this.department,
  });
}
