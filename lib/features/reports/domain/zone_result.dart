class ZoneResult {
  ZoneResult({
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

  // Validity window (zone center +/- its tolerance). Stored so display never
  // re-derives it from settings, which may change after generation.
  final DateTime windowStart;
  final DateTime windowEnd;

  final List<DateTime> timestamps;
  final bool isSatisfied;
}
