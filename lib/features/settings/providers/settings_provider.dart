import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';
import '../domain/column_header.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(dbProvider));
});

// --- Settings ---

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() =>
      ref.read(settingsRepositoryProvider).loadSettings();

  Future<void> updateDailyStartTime(String v) =>
      _save('daily_start_time', v, (s) => s.copyWith(dailyStartTime: v));

  Future<void> updateDailyWorkDuration(int v) =>
      _save('daily_work_duration', '$v', (s) => s.copyWith(dailyWorkDuration: v));

  Future<void> updateDailyMaxOvertime(int v) =>
      _save('daily_max_overtime', '$v', (s) => s.copyWith(dailyMaxOvertime: v));

  Future<void> updateDailyDelayAllowance(int v) =>
      _save('daily_delay_allowance', '$v', (s) => s.copyWith(dailyDelayAllowance: v));

  Future<void> updateShiftStartTimes(List<String> v) =>
      _save('shift_start_times', jsonEncode(v), (s) => s.copyWith(shiftStartTimes: v));

  Future<void> updateShiftDuration(int v) =>
      _save('shift_duration', '$v', (s) => s.copyWith(shiftDuration: v));

  Future<void> updateShiftZoneInterval(int v) =>
      _save('shift_zone_interval', '$v', (s) => s.copyWith(shiftZoneInterval: v));

  Future<void> updateShiftTolerance(int v) =>
      _save('shift_tolerance', '$v', (s) => s.copyWith(shiftTolerance: v));

  Future<void> updateShiftBaselineHours(int v) =>
      _save('shift_baseline_hours', '$v', (s) => s.copyWith(shiftBaselineHours: v));

  Future<void> updateShiftCeilingHours(int v) =>
      _save('shift_ceiling_hours', '$v', (s) => s.copyWith(shiftCeilingHours: v));

  Future<void> updateRoundingMode(String v) =>
      _save('rounding_mode', v, (s) => s.copyWith(roundingMode: v));

  Future<void> _save(
    String key,
    String dbValue,
    AppSettings Function(AppSettings) apply,
  ) async {
    await ref.read(settingsRepositoryProvider).updateSetting(key, dbValue);
    final current = switch (state) { AsyncData(:final value) => value, _ => null };
    if (current != null) state = AsyncData(apply(current));
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// --- Column Headers ---

class ColumnHeadersNotifier
    extends AsyncNotifier<Map<String, List<ColumnHeader>>> {
  @override
  Future<Map<String, List<ColumnHeader>>> build() =>
      ref.read(settingsRepositoryProvider).loadColumnHeaders();

  Future<void> add(String fieldKey, String headerValue) async {
    await ref.read(settingsRepositoryProvider).addColumnHeader(fieldKey, headerValue);
    await _reload();
  }

  Future<void> updateHeader(int id, String headerValue) async {
    await ref.read(settingsRepositoryProvider).updateColumnHeader(id, headerValue);
    await _reload();
  }

  Future<void> delete(int id) async {
    await ref.read(settingsRepositoryProvider).deleteColumnHeader(id);
    await _reload();
  }

  Future<void> _reload() async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).loadColumnHeaders(),
    );
  }
}

final columnHeadersProvider =
    AsyncNotifierProvider<ColumnHeadersNotifier, Map<String, List<ColumnHeader>>>(
  ColumnHeadersNotifier.new,
);
