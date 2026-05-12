import '../../../shared/domain/employee.dart';

class EmployeeRecord {
  final int id;
  final String employeeNumber;
  final String name;
  final EmploymentType employmentType;
  final String department;

  const EmployeeRecord({
    required this.id,
    required this.employeeNumber,
    required this.name,
    required this.employmentType,
    required this.department,
  });
}
