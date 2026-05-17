import 'dart:convert';

class ZoneRow {
  const ZoneRow({
    required this.zoneIndex,
    required this.startTime,
    required this.endTime,
    required this.timestamps,
    required this.isSatisfied,
  });

  final int zoneIndex;
  final DateTime startTime;
  final DateTime endTime;
  final List<DateTime> timestamps;
  final bool isSatisfied;

  static List<ZoneRow> listFromJson(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((m) {
      final map = m as Map<String, dynamic>;
      return ZoneRow(
        zoneIndex: map['zoneIndex'] as int,
        startTime: DateTime.parse(map['startTime'] as String),
        endTime: DateTime.parse(map['endTime'] as String),
        timestamps: (map['timestamps'] as List<dynamic>)
            .map((ts) => DateTime.parse(ts as String))
            .toList(),
        isSatisfied: map['isSatisfied'] as bool,
      );
    }).toList();
  }
}
