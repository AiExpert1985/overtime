import 'dart:convert';

class ZoneRow {
  const ZoneRow({
    required this.zoneIndex,
    required this.startTime,
    required this.endTime,
    required this.windowStart,
    required this.windowEnd,
    required this.timestamps,
    required this.isSatisfied,
  });

  final int zoneIndex;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<DateTime> timestamps;
  final bool isSatisfied;

  /// The checkpoint's true center is the midpoint of its validity window
  /// (windowStart/windowEnd are always center +/- tolerance, symmetric).
  DateTime get center =>
      windowStart.add(windowEnd.difference(windowStart) ~/ 2);

  /// Timestamps inside the validity window (center +/- tolerance).
  List<DateTime> get inWindowTimestamps => timestamps
      .where((ts) => !ts.isBefore(windowStart) && !ts.isAfter(windowEnd))
      .toList();

  /// The approximate window shown in the UI: the zone's bucket boundary
  /// (startTime/endTime) for the side facing a neighbouring zone — a pure
  /// midpoint-between-centers, unaffected by any tolerance. The two outermost
  /// edges of the whole period (first zone's start, last zone's end) are NOT
  /// bucket midpoints — bounds there use the internal, wider
  /// detection_edge_tolerance rather than the configured shift_edge_tolerance,
  /// so they are instead derived as center +/- this zone's own real tolerance,
  /// recovered exactly from its stored validity window. Rounded to the nearest
  /// 10 minutes for display only; windowStart/windowEnd govern validity.
  (DateTime, DateTime) approxWindow(int totalZones) {
    final tolerance = windowEnd.difference(windowStart) ~/ 2;
    final start = zoneIndex == 0 ? center.subtract(tolerance) : startTime;
    final end = zoneIndex == totalZones - 1 ? center.add(tolerance) : endTime;
    return (_roundToNearest10(start), _roundToNearest10(end));
  }

  static DateTime _roundToNearest10(DateTime dt) {
    final truncated = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
    final remainder = truncated.minute % 10;
    final delta = remainder < 5 ? -remainder : (10 - remainder);
    return truncated.add(Duration(minutes: delta));
  }

  static List<ZoneRow> listFromJson(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((m) {
      final map = m as Map<String, dynamic>;
      return ZoneRow(
        zoneIndex: map['zoneIndex'] as int,
        startTime: DateTime.parse(map['startTime'] as String),
        endTime: DateTime.parse(map['endTime'] as String),
        windowStart: DateTime.parse(map['windowStart'] as String),
        windowEnd: DateTime.parse(map['windowEnd'] as String),
        timestamps: (map['timestamps'] as List<dynamic>)
            .map((ts) => DateTime.parse(ts as String))
            .toList(),
        isSatisfied: map['isSatisfied'] as bool,
      );
    }).toList();
  }
}
