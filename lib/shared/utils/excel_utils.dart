import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../domain/employee.dart';

// Strips invisible Unicode chars that Excel embeds in Arabic text cells.
final _invisiblePattern = RegExp(
  '[\u{00A0}\u{200B}\u{200C}\u{200D}\u{200E}\u{200F}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2060}\u{FEFF}]',
);

Future<Excel?> openExcel(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    return Excel.decodeBytes(fixNumFmtIds(bytes));
  } catch (e, st) {
    debugPrint('[ExcelUtils] Failed to open "$path": $e\n$st');
    return null;
  }
}

// xlsx files sometimes declare built-in numFmt IDs (< 164) in their custom
// numFmts section. The excel package rejects these. Strip them before parsing.
Uint8List fixNumFmtIds(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    const stylesPath = 'xl/styles.xml';
    final stylesFile = archive.findFile(stylesPath);
    if (stylesFile == null) return bytes;

    var xml = utf8.decode(stylesFile.content as List<int>);

    final numFmtTag = RegExp(r'<numFmt\b[^>]*/\s*>', dotAll: true);
    xml = xml.replaceAllMapped(numFmtTag, (m) {
      final tag = m.group(0)!;
      final idStr = RegExp(r'numFmtId="(\d+)"').firstMatch(tag)?.group(1);
      final id = int.tryParse(idStr ?? '') ?? 164;
      return id < 164 ? '' : tag;
    });

    final remaining = RegExp(r'<numFmt\b').allMatches(xml).length;
    xml = xml.replaceAllMapped(
      RegExp(r'(<numFmts\b[^>]*\bcount=")[^"]*(")', dotAll: true),
      (m) => '${m.group(1)}$remaining${m.group(2)}',
    );

    final fixed = utf8.encode(xml);
    final newFile = ArchiveFile(stylesPath, fixed.length, fixed);
    archive.files.removeWhere((f) => f.name == stylesPath);
    archive.files.add(newFile);

    final reencoded = ZipEncoder().encode(archive);
    if (reencoded == null) return bytes;
    return Uint8List.fromList(reencoded);
  } catch (_) {
    return bytes;
  }
}

List<String> headerRow(List<Data?> row) => row.map((c) {
      final raw = c?.value?.toString().trim() ?? '';
      return raw.replaceAll(_invisiblePattern, '').trim();
    }).toList();

int? findColumn(List<String> headers, List<String> acceptable) {
  for (int i = 0; i < headers.length; i++) {
    if (acceptable.contains(headers[i])) return i;
  }
  return null;
}

String? cellText(Data? cell) {
  final raw = cell?.value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  final cleaned = raw.replaceAll(_invisiblePattern, '').trim();
  return cleaned.isEmpty ? null : cleaned;
}

EmploymentType? parseEmploymentType(String value) {
  if (value == 'مناوب') return EmploymentType.shift;
  if (value == 'صباحي') return EmploymentType.daily;
  return null;
}
