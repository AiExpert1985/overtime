class DailyEmployeeRow {
  const DailyEmployeeRow({
    required this.id,
    required this.employeeName,
    required this.department,
    required this.totalOvertimeMinutes,
    required this.isIncluded,
  });

  final int id;
  final String employeeName;
  final String department;
  final int totalOvertimeMinutes;
  final bool isIncluded;

  DailyEmployeeRow copyWith({bool? isIncluded}) => DailyEmployeeRow(
        id: id,
        employeeName: employeeName,
        department: department,
        totalOvertimeMinutes: totalOvertimeMinutes,
        isIncluded: isIncluded ?? this.isIncluded,
      );

  factory DailyEmployeeRow.fromMap(Map<String, dynamic> map) => DailyEmployeeRow(
        id: map['id'] as int,
        employeeName: map['employee_name'] as String,
        department: map['department'] as String,
        totalOvertimeMinutes: map['total_overtime_minutes'] as int,
        isIncluded: (map['is_included'] as int) == 1,
      );
}
