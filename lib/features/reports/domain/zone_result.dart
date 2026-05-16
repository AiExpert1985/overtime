class ZoneResult {
  ZoneResult({
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
}
