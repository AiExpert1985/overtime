import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/settings_provider.dart';
import '../domain/picked_file.dart';
import '../services/file_validation_service.dart';

final fileValidationServiceProvider = Provider<FileValidationService>((ref) {
  return FileValidationService();
});

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

  Future<void> addFiles(List<String> paths) async {
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

    final pending = newPaths.map((p) {
      final name = p.replaceAll('\\', '/').split('/').last;
      return PickedFile(name: name, path: p, isValidating: true);
    }).toList();

    state = ReportGenerateState(
      files: [...state.files, ...pending],
      startDate: state.startDate,
      endDate: state.endDate,
      dateError: state.dateError,
    );

    final service = ref.read(fileValidationServiceProvider);
    final headersMap = await ref.read(columnHeadersProvider.future);
    final headers = headersMap.values.expand((list) => list).toList();

    for (final pendingFile in pending) {
      final validated = await service.validate(
        pendingFile.path,
        pendingFile.name,
        headers,
      );
      state = ReportGenerateState(
        files: state.files
            .map((f) => f.path == pendingFile.path ? validated : f)
            .toList(),
        startDate: state.startDate,
        endDate: state.endDate,
        dateError: state.dateError,
      );
    }
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
