import 'package:excel_plus/excel_plus.dart';

// Shared by FileValidationService and GenerationService so both agree on
// what counts as a parseable datetime cell — a file that validates as
// having usable rows must parse identically at generation time.
DateTime? parseAttendanceDateTimeCell(Data? cell) {
  final value = cell?.value;
  if (value == null) return null;
  if (value is DateTimeCellValue) return value.asDateTimeLocal();
  if (value is DateCellValue) return value.asDateTimeLocal();

  final text = value.toString().trim();
  final iso = DateTime.tryParse(text);
  if (iso != null) return iso;

  return _parseArabicAmPmText(text);
}

// Some attendance devices export the datetime column as plain text in the
// shape "05/04/2026 08:01:39 ص" (day/month/year, 12-hour clock, Arabic
// AM/PM marker) rather than a native Excel date cell.
final _arabicAmPmPattern = RegExp(
  r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})\s*([صم])$',
);

DateTime? _parseArabicAmPmText(String text) {
  final m = _arabicAmPmPattern.firstMatch(text);
  if (m == null) return null;

  final day = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  final year = int.parse(m.group(3)!);
  var hour = int.parse(m.group(4)!);
  final minute = int.parse(m.group(5)!);
  final second = int.parse(m.group(6)!);
  final isPm = m.group(7)! == 'م';

  if (month < 1 || month > 12) return null;
  if (hour < 1 || hour > 12) return null;
  if (minute > 59 || second > 59) return null;

  if (hour == 12) hour = 0;
  if (isPm) hour += 12;

  final dt = DateTime(year, month, day, hour, minute, second);
  // DateTime silently rolls invalid days (e.g. 31/02) into the next month
  // instead of throwing — catch that by checking the fields round-trip.
  if (dt.month != month || dt.day != day) return null;

  return dt;
}
