import 'dart:convert';

// Period invalid-reason sets are stored as a JSON array in the `notes` TEXT
// column. A plain string is not used because Arabic reasons contain no safe
// delimiter, and a JSON array round-trips back into a real set.

String encodeNotes(Set<String> notes) => jsonEncode(notes.toList());

List<String> decodeNotes(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final decoded = jsonDecode(raw) as List<dynamic>;
  return decoded.cast<String>();
}
