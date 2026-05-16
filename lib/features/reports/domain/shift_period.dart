import 'zone_result.dart';

class ShiftPeriod {
  ShiftPeriod({
    required this.periodIndex,
    required this.periodDate,
    required this.allTimestamps,
    required this.zoneResults,
  });

  final int periodIndex;
  final String periodDate;
  final List<DateTime> allTimestamps;
  final List<ZoneResult> zoneResults;

  // Set by Stage 8 calculator
  String? endDate;
  int? totalAttendanceDuration;
  int? hoursCounted;
  bool? isValid;
  String? notes;
}
