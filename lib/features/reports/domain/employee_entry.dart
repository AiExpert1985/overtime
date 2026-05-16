class EmployeeEntry {
  EmployeeEntry({
    required this.name,
    required this.department,
  }) : timestamps = [];

  final String name;
  final String department;
  final List<DateTime> timestamps;
}
