import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/picked_file.dart';

class ReportGenerateState {
  const ReportGenerateState({
    this.files = const [],
    this.startDate,
    this.endDate,
    this.dateError,
    this.filesError,
  });

  final List<PickedFile> files;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? dateError;
  final String? filesError;

  bool get isGenerateEnabled =>
      files.any((f) => f.isValid) &&
      startDate != null &&
      endDate != null &&
      dateError == null;
}

class ReportGenerateNotifier extends Notifier<ReportGenerateState> {
  @override
  ReportGenerateState build() => const ReportGenerateState();

  void addFiles(List<String> paths) {
    final existing = {for (final f in state.files) f.path};
    final newPaths = paths.where((p) => !existing.contains(p)).toList();

    if (state.files.length + newPaths.length > 10) {
      state = ReportGenerateState(
        files: state.files,
        startDate: state.startDate,
        endDate: state.endDate,
        dateError: state.dateError,
        filesError: 'يُسمح بحد أقصى 10 ملفات فقط',
      );
      return;
    }

    final added = newPaths.map((p) {
      final name = p.replaceAll('\\', '/').split('/').last;
      return PickedFile(name: name, path: p);
    }).toList();

    state = ReportGenerateState(
      files: [...state.files, ...added],
      startDate: state.startDate,
      endDate: state.endDate,
      dateError: state.dateError,
    );
  }

  void removeFile(String path) {
    state = ReportGenerateState(
      files: state.files.where((f) => f.path != path).toList(),
      startDate: state.startDate,
      endDate: state.endDate,
      dateError: state.dateError,
    );
  }

  void setStartDate(DateTime date, int maxRange) {
    state = ReportGenerateState(
      files: state.files,
      startDate: date,
      endDate: state.endDate,
      filesError: state.filesError,
      dateError: _validateDates(date, state.endDate, maxRange),
    );
  }

  void setEndDate(DateTime date, int maxRange) {
    state = ReportGenerateState(
      files: state.files,
      startDate: state.startDate,
      endDate: date,
      filesError: state.filesError,
      dateError: _validateDates(state.startDate, date, maxRange),
    );
  }

  void reset() => state = const ReportGenerateState();
}

String? _validateDates(DateTime? start, DateTime? end, int maxRange) {
  if (start == null || end == null) return null;
  if (end.isBefore(start)) return 'تاريخ النهاية لا يمكن أن يكون قبل تاريخ البداية';
  final days = end.difference(start).inDays + 1;
  if (days > maxRange) return 'نطاق التاريخ يتجاوز الحد المسموح به ($maxRange يوم)';
  return null;
}

final reportGenerateProvider =
    NotifierProvider<ReportGenerateNotifier, ReportGenerateState>(
  ReportGenerateNotifier.new,
);
