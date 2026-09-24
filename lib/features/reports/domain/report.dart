import 'dart:convert';

class Report {
  const Report({
    required this.id,
    required this.generationDatetime,
    required this.rangeStart,
    required this.rangeEnd,
    this.settingsSnapshot,
    this.notes,
  });

  final int id;
  final DateTime generationDatetime;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  // JSON map of the AppSettings in effect at generation time. Null for
  // reports generated before this field existed. Write-once, never edited.
  final Map<String, String>? settingsSnapshot;

  // Free-text, editable at any time after generation.
  final String? notes;

  factory Report.fromMap(Map<String, dynamic> map) {
    final rawSnapshot = map['settings_snapshot'] as String?;
    return Report(
      id: map['id'] as int,
      generationDatetime: DateTime.parse(map['generation_datetime'] as String),
      rangeStart: DateTime.parse(map['range_start'] as String),
      rangeEnd: DateTime.parse(map['range_end'] as String),
      settingsSnapshot: rawSnapshot == null
          ? null
          : Map<String, String>.from(jsonDecode(rawSnapshot) as Map),
      notes: map['notes'] as String?,
    );
  }
}
