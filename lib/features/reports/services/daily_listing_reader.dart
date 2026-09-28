import 'package:excel_plus/excel_plus.dart';

// Reader for the second attendance export format — the attendance software's
// "Daily Attendance Listing" report. Unlike the raw punch log (one timestamp
// per row, with name/department/datetime columns), each file is one printed
// page of one day: the date sits once at the top of the sheet and every
// employee row carries an In time and an Out time as 12-hour text.
//
// The reader converts a sheet into the same (name, department, timestamp)
// records the raw punch log produces — In and Out each become their own
// record — so everything downstream of the dictionary build is unaware which
// format a timestamp came from.
//
// Why a separate reader rather than extending the raw punch log path: that
// path assumes one timestamp per row and a header on the first row, matched
// against user-configurable header values (column_headers table, Settings
// screen). This format breaks all three assumptions — the date lives outside
// the rows, each row holds two times, and the header sits below a title
// block. Keeping it apart leaves the existing path untouched.
//
// Used by FileValidationService (upload) and GenerationService (dictionary
// build); both call isDailyListingSheet first and route matching sheets here.

// All files of this format come from a single building, and the export has no
// department column.
const dailyListingDepartment = 'مبنى المديرية';

// Fixed labels printed by the attendance software — intentionally NOT read
// from the column_headers settings. Those settings apply only to the raw
// punch log format; this export's labels are part of the software's report
// template, so they are hardcoded here. If the software ever changes them,
// update these constants.
const _title = 'Daily Attendance Listing';
const _nameHeader = 'Name';
const _inHeader = 'In';
const _outHeader = 'Out';

// The title is on the first row in every sample; a few rows of slack keep
// detection robust to a blank line being added above it.
const _titleSearchRows = 5;

// "04-05-2026  Sun" — month-day-year, then the English weekday abbreviation.
final _datePattern = RegExp(r'^(\d{2})-(\d{2})-(\d{4})\s+([A-Za-z]{3})$');
// "07:54 AM"
final _timePattern = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$');
final _digitsPattern = RegExp(r'^\d+$');

const _weekdayAbbreviations = {
  'Mon': DateTime.monday,
  'Tue': DateTime.tuesday,
  'Wed': DateTime.wednesday,
  'Thu': DateTime.thursday,
  'Fri': DateTime.friday,
  'Sat': DateTime.saturday,
  'Sun': DateTime.sunday,
};

typedef DailyListingRecord = ({String name, DateTime timestamp});

class DailyListingSheet {
  DailyListingSheet({
    required this.records,
    required this.unparseableTimes,
  });

  final List<DailyListingRecord> records;

  // In/Out cells holding text that is not a recognisable time — surfaced as
  // the same skipped-rows warning the raw punch log format produces.
  final int unparseableTimes;
}

bool isDailyListingSheet(List<List<Data?>> rows) {
  final limit = rows.length < _titleSearchRows ? rows.length : _titleSearchRows;
  for (var r = 0; r < limit; r++) {
    if (rows[r].any((cell) => _text(cell) == _title)) return true;
  }
  return false;
}

// Returns null when the sheet cannot be trusted as a whole — no readable
// date, or no header row naming the Name/In/Out columns. A sheet whose
// date is unknown must be rejected outright: guessing it would silently
// misplace every timestamp on the page.
DailyListingSheet? readDailyListingSheet(List<List<Data?>> rows) {
  final headerIndex = _findHeaderRow(rows);
  if (headerIndex == null) return null;

  final date = _findDate(rows, headerIndex);
  if (date == null) return null;

  final header = rows[headerIndex];
  // Column positions differ between exports of the same report, so they are
  // located by header label rather than fixed index.
  final nameCol = _columnOf(header, _nameHeader)!;
  final inCol = _columnOf(header, _inHeader)!;
  final outCol = _columnOf(header, _outHeader)!;

  final records = <DailyListingRecord>[];
  var unparseable = 0;

  for (var r = headerIndex + 1; r < rows.length; r++) {
    final row = rows[r];
    if (!_isEmployeeRow(row, nameCol)) continue;

    final name = _cellText(row, nameCol);
    for (final col in [inCol, outCol]) {
      final text = _cellText(row, col);
      if (text.isEmpty) continue;

      final timestamp = _combine(date, text);
      if (timestamp == null) {
        unparseable++;
        continue;
      }
      records.add((name: name, timestamp: timestamp));
    }
  }

  return DailyListingSheet(records: records, unparseableTimes: unparseable);
}

int? _findHeaderRow(List<List<Data?>> rows) {
  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    final hasAll = [_nameHeader, _inHeader, _outHeader]
        .every((label) => _columnOf(row, label) != null);
    if (hasAll) return r;
  }
  return null;
}

DateTime? _findDate(List<List<Data?>> rows, int headerIndex) {
  for (var r = 0; r < headerIndex; r++) {
    for (final cell in rows[r]) {
      final date = _parseDate(_text(cell));
      if (date != null) return date;
    }
  }
  return null;
}

DateTime? _parseDate(String text) {
  final m = _datePattern.firstMatch(text);
  if (m == null) return null;

  final month = int.parse(m.group(1)!);
  final day = int.parse(m.group(2)!);
  final year = int.parse(m.group(3)!);
  final weekday = _weekdayAbbreviations[m.group(4)!];
  if (weekday == null) return null;

  final date = DateTime(year, month, day);
  // DateTime rolls invalid days over instead of throwing, so check the
  // fields round-trip. The printed weekday must also agree — it is the only
  // guard against a day/month order ever flipping in the export.
  if (date.month != month || date.day != day) return null;
  if (date.weekday != weekday) return null;

  return date;
}

// The summary block at the bottom of a day's last page also has text under
// the Name column position in some layouts; employee rows are the ones that
// start with a numeric sequence / user-id cell before the name.
bool _isEmployeeRow(List<Data?> row, int nameCol) {
  final name = _cellText(row, nameCol);
  if (name.isEmpty || _digitsPattern.hasMatch(name)) return false;

  for (var col = 0; col < nameCol && col < row.length; col++) {
    final text = _text(row[col]);
    if (text.isEmpty) continue;
    return _digitsPattern.hasMatch(text);
  }
  return false;
}

DateTime? _combine(DateTime date, String timeText) {
  final m = _timePattern.firstMatch(timeText);
  if (m == null) return null;

  var hour = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2)!);
  final isPm = m.group(3)!.toUpperCase() == 'PM';

  if (hour < 1 || hour > 12 || minute > 59) return null;

  if (hour == 12) hour = 0;
  if (isPm) hour += 12;

  return DateTime(date.year, date.month, date.day, hour, minute);
}

int? _columnOf(List<Data?> row, String label) {
  for (var col = 0; col < row.length; col++) {
    if (_text(row[col]) == label) return col;
  }
  return null;
}

String _cellText(List<Data?> row, int col) {
  if (col >= row.length) return '';
  return _text(row[col]);
}

String _text(Data? cell) => cell?.value?.toString().trim() ?? '';
