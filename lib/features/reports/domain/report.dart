class Report {
  const Report({
    required this.id,
    required this.generationDatetime,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final int id;
  final DateTime generationDatetime;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id'] as int,
      generationDatetime: DateTime.parse(map['generation_datetime'] as String),
      rangeStart: DateTime.parse(map['range_start'] as String),
      rangeEnd: DateTime.parse(map['range_end'] as String),
    );
  }
}
