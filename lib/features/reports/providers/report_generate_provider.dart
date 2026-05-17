import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../settings/providers/settings_provider.dart';
import '../data/reports_repository.dart';
import '../domain/picked_file.dart';
import '../services/file_validation_service.dart';
import '../services/generation_service.dart';
import 'reports_provider.dart';

final fileValidationServiceProvider = Provider<FileValidationService>((ref) {
  return FileValidationService();
});

final generationServiceProvider = Provider<GenerationService>((ref) {
  return GenerationService();
});

class ReportGenerateState {
  const ReportGenerateState({
    this.files = const [],
    this.startDate,
    this.endDate,
    this.dateError,
    this.filesError,
    this.isGenerating = false,
    this.generationError,
  });

  final List<PickedFile> files;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? dateError;
  final String? filesError;
  final bool isGenerating;
  final String? generationError;

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

  void dismissError() {
    state = ReportGenerateState(
      files: state.files,
      startDate: state.startDate,
      endDate: state.endDate,
      dateError: state.dateError,
      filesError: state.filesError,
    );
  }

  void reset() => state = const ReportGenerateState();

  Future<int?> generate() async {
    final saved = state;
    final validPaths =
        saved.files.where((f) => f.isValid).map((f) => f.path).toList();

    state = ReportGenerateState(
      files: saved.files,
      startDate: saved.startDate,
      endDate: saved.endDate,
      dateError: saved.dateError,
      isGenerating: true,
    );

    try {
      final settings = await ref.read(settingsProvider.future);
      final headersMap = await ref.read(columnHeadersProvider.future);
      final headers = headersMap.values.expand((list) => list).toList();
      final service = ref.read(generationServiceProvider);
      final repo = ReportsRepository(ref.read(dbProvider));

      final dictionary = await service.buildDictionary(
        validPaths,
        saved.startDate!,
        saved.endDate!,
        headers,
      );

      final schedules = service.detectSchedules(
        dictionary,
        saved.startDate!,
        saved.endDate!,
        settings,
      );

      final offDays = service.detectOffDays(
        schedules.dailyTable,
        saved.startDate!,
        saved.endDate!,
      );

      final shiftEntries = service.extractShiftPeriods(
        schedules.shiftTable,
        saved.startDate!,
        saved.endDate!,
        settings,
      );

      final dailyEntries = service.extractDailyPeriods(
        schedules.dailyTable,
        offDays,
      );

      service.calculateShiftOvertime(shiftEntries, settings);
      service.calculateDailyOvertime(dailyEntries, settings);

      final reportId = await repo.storeReport(
        rangeStart: saved.startDate!,
        rangeEnd: saved.endDate!,
        shiftEntries: shiftEntries,
        dailyEntries: dailyEntries,
        undetectedList: schedules.undetectedList,
      );

      ref.invalidate(reportsProvider);
      state = const ReportGenerateState();
      return reportId;
    } on GenerationException catch (e) {
      state = ReportGenerateState(
        files: saved.files,
        startDate: saved.startDate,
        endDate: saved.endDate,
        dateError: saved.dateError,
        generationError: e.arabicMessage,
      );
      return null;
    } catch (_) {
      state = ReportGenerateState(
        files: saved.files,
        startDate: saved.startDate,
        endDate: saved.endDate,
        dateError: saved.dateError,
        generationError: 'حدث خطأ غير متوقع أثناء توليد التقرير',
      );
      return null;
    }
  }
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
