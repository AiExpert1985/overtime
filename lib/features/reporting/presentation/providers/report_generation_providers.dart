import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/attendance_record.dart';
import '../../../../shared/domain/employee.dart';
import '../../../../shared/domain/holiday.dart';
import '../../application/report_generation_service.dart';
import 'settings_providers.dart';

// ── Generation state ──────────────────────────────────────────────────────────

sealed class GenerationState {
  const GenerationState();
}

class GenerationIdle extends GenerationState {
  const GenerationIdle();
}

class GenerationLoading extends GenerationState {
  const GenerationLoading();
}

class GenerationUnmatchedReview extends GenerationState {
  final List<String> unmatchedNames;
  const GenerationUnmatchedReview(this.unmatchedNames);
}

class GenerationSuccess extends GenerationState {
  final int reportId;
  const GenerationSuccess(this.reportId);
}

class GenerationError extends GenerationState {
  final String message;
  const GenerationError(this.message);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ReportGenerationNotifier extends Notifier<GenerationState> {
  final _service = ReportGenerationService();

  // Held while waiting for unmatched-review decision
  DictionaryBuildResult? _pendingDict;
  List<Holiday>? _pendingHolidays;
  DateTime? _pendingStart;
  DateTime? _pendingEnd;
  SettingsState? _pendingSettings;

  @override
  GenerationState build() => const GenerationIdle();

  Future<void> generate({
    required List<AttendanceRecord> attendance,
    required List<Employee> employees,
    required List<Holiday> holidays,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final settings = ref.read(settingsProvider).value;
    if (settings == null) {
      state = const GenerationError('لم يتم تحميل الإعدادات بعد، حاول مجدداً');
      return;
    }

    state = const GenerationLoading();

    try {
      final dictResult = _service.buildDictionary(
        employees: employees,
        attendance: attendance,
        startDate: startDate,
        endDate: endDate,
      );

      if (dictResult.unmatched.isNotEmpty) {
        _pendingDict = dictResult;
        _pendingHolidays = holidays;
        _pendingStart = startDate;
        _pendingEnd = endDate;
        _pendingSettings = settings;
        state = GenerationUnmatchedReview(
            dictResult.unmatched.map((e) => e.name).toList());
        return;
      }

      final reportId = await _service.runPipeline(
        dictResult: dictResult,
        holidays: holidays,
        startDate: startDate,
        endDate: endDate,
        settings: settings,
      );
      state = GenerationSuccess(reportId);
    } catch (e) {
      state = GenerationError('حدث خطأ أثناء توليد التقرير');
    }
  }

  Future<void> continueWithUnmatched() async {
    final dict = _pendingDict;
    final holidays = _pendingHolidays;
    final start = _pendingStart;
    final end = _pendingEnd;
    final settings = _pendingSettings;

    if (dict == null ||
        holidays == null ||
        start == null ||
        end == null ||
        settings == null) {
      state = const GenerationIdle();
      return;
    }

    state = const GenerationLoading();
    _clearPending();

    try {
      final reportId = await _service.runPipeline(
        dictResult: dict,
        holidays: holidays,
        startDate: start,
        endDate: end,
        settings: settings,
      );
      state = GenerationSuccess(reportId);
    } catch (e) {
      state = GenerationError('حدث خطأ أثناء توليد التقرير');
    }
  }

  void abort() {
    _clearPending();
    state = const GenerationIdle();
  }

  void reset() {
    _clearPending();
    state = const GenerationIdle();
  }

  Future<String?> exportUnmatchedNames(List<String> names) =>
      _service.exportUnmatchedNames(names);

  void _clearPending() {
    _pendingDict = null;
    _pendingHolidays = null;
    _pendingStart = null;
    _pendingEnd = null;
    _pendingSettings = null;
  }
}

final generationProvider =
    NotifierProvider<ReportGenerationNotifier, GenerationState>(
  ReportGenerationNotifier.new,
);
