import 'dart:convert';

class UndetectedPeriodRow {
  const UndetectedPeriodRow({
    required this.periodIndex,
    required this.date,
    required this.weekday,
    required this.timestamps,
  });

  final int periodIndex;
  final String date;
  final String weekday;
  final List<DateTime> timestamps;

  factory UndetectedPeriodRow.fromMap(Map<String, dynamic> map) {
    final tsJson =
        jsonDecode(map['all_timestamps'] as String) as List<dynamic>;
    return UndetectedPeriodRow(
      periodIndex: map['period_index'] as int,
      date: map['date'] as String,
      weekday: map['weekday'] as String,
      timestamps:
          tsJson.map((ts) => DateTime.parse(ts as String)).toList(),
    );
  }
}
