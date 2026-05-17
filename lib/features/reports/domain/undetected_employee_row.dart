class UndetectedEmployeeRow {
  const UndetectedEmployeeRow({
    required this.id,
    required this.employeeName,
    required this.department,
    required this.failureReason,
  });

  final int id;
  final String employeeName;
  final String department;
  final String failureReason;

  factory UndetectedEmployeeRow.fromMap(Map<String, dynamic> map) =>
      UndetectedEmployeeRow(
        id: map['id'] as int,
        employeeName: map['employee_name'] as String,
        department: map['department'] as String,
        failureReason: map['failure_reason'] as String,
      );
}
