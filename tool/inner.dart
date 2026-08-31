import 'package:overtime/features/reports/services/generation_service.dart';
import 'package:overtime/features/settings/domain/app_settings.dart';
import 'package:overtime/features/settings/domain/column_header.dart';

final headers = [
  ColumnHeader(id: 1, fileType: 'attendance', fieldKey: 'employee_name', headerValue: 'Name', isDefault: true),
  ColumnHeader(id: 2, fileType: 'attendance', fieldKey: 'department', headerValue: 'Department', isDefault: true),
  ColumnHeader(id: 3, fileType: 'attendance', fieldKey: 'datetime', headerValue: 'Date/Time', isDefault: true),
];
AppSettings cfg() => AppSettings(
  dailyStartTime: '08:00', dailyWorkDuration: 7, dailyMaxOvertime: 3,
  dailyDelayAllowance: 30, shiftStartTimes: ['08:00', '23:00'],
  shiftDuration: 24, shiftZoneInterval: 6, shiftEdgeTolerance: 30,
  shiftInnerTolerance: 120, shiftDurationTolerance: 60,
  shiftBaselineHours: 154, shiftCeilingHours: 192,
  roundingMode: 'quarter', maxReportDateRange: 32);

Future<void> month(String f, String label, DateTime s, DateTime e) async {
  final svc = GenerationService();
  final dict = await svc.buildDictionary([f], s, e, headers);
  final res = svc.detectSchedules(dict, s, e, cfg());
  for (final allow in [0, 1]) {
    GenerationService.expInnerAllowance = allow;
    svc.calculateShiftOvertime(res.shiftTable, cfg());
    var v = 0, t = 0;
    final hours = <int>[];
    for (final x in res.shiftTable.values) {
      t += x.periods.length;
      v += x.periods.where((p) => p.isValid!).length;
      hours.add(x.periods.where((p) => p.isValid!).length * 24);
    }
    final paid = res.shiftTable.values.where((x) => x.overtimeMinutes! > 0).length;
    final totalOt = res.shiftTable.values.fold<int>(0, (a, x) => a + x.overtimeMinutes!);
    hours.sort();
    print('  $label allow=$allow  valid=$v/$t (${(v * 100 / t).toStringAsFixed(0)}%)  '
        'paid=$paid/${res.shiftTable.length}  '
        'totalOvertime=${(totalOt / 60).toStringAsFixed(0)}h  '
        'medianCountedHours=${hours.isEmpty ? 0 : hours[hours.length ~/ 2]}');
  }
  GenerationService.expInnerAllowance = 0;
}

Future<void> main() async {
  const f1 = 'data sample/three months data sample.xlsx';
  const f2 = 'data sample/three months data sample 2.xlsx';
  await month(f1, 'F1 JAN', DateTime(2026, 1, 1), DateTime(2026, 1, 31));
  await month(f1, 'F1 FEB', DateTime(2026, 2, 1), DateTime(2026, 2, 28));
  await month(f1, 'F1 MAR', DateTime(2026, 3, 1), DateTime(2026, 3, 31));
  await month(f2, 'F2 JAN', DateTime(2026, 1, 1), DateTime(2026, 1, 31));
  await month('data sample/بصمة شهر 10.xlsx', 'OCT   ', DateTime(2025, 10, 1), DateTime(2025, 10, 31));
}
