enum EmploymentType { shift, daily }

class Employee {
  final String name;
  final EmploymentType employmentType;
  final String department;

  const Employee({
    required this.name,
    required this.employmentType,
    required this.department,
  });
}
