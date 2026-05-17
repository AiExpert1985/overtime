class ShiftEmployeeRow {
  const ShiftEmployeeRow({
    required this.id,
    required this.employeeName,
    required this.department,
    required this.overtimeMinutes,
    required this.isIncluded,
  });

  final int id;
  final String employeeName;
  final String department;
  // Column is named overtime_hours in DB but stores minutes for consistency with daily employees.
  final int overtimeMinutes;
  final bool isIncluded;

  ShiftEmployeeRow copyWith({bool? isIncluded}) => ShiftEmployeeRow(
        id: id,
        employeeName: employeeName,
        department: department,
        overtimeMinutes: overtimeMinutes,
        isIncluded: isIncluded ?? this.isIncluded,
      );

  factory ShiftEmployeeRow.fromMap(Map<String, dynamic> map) => ShiftEmployeeRow(
        id: map['id'] as int,
        employeeName: map['employee_name'] as String,
        department: map['department'] as String,
        overtimeMinutes: map['overtime_hours'] as int,
        isIncluded: (map['is_included'] as int) == 1,
      );
}
