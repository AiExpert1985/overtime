import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/settings_repository.dart';
import '../../../../shared/database/database_helper.dart';

@immutable
class SettingsState {
  final String dailyStartTime;
  final int dailyWorkDuration;
  final int dailyMaxOvertime;
  final List<String> shiftStartTimes;
  final int shiftDuration;
  final int shiftZoneInterval;
  final int shiftStartEndTolerance;
  final int shiftInnerTolerance;
  final int shiftPeriodGap;
  final int shiftBaselineHours;
  final int shiftCeilingHours;
  final String roundingMode;
  final int maxReportDateRange;

  const SettingsState({
    required this.dailyStartTime,
    required this.dailyWorkDuration,
    required this.dailyMaxOvertime,
    required this.shiftStartTimes,
    required this.shiftDuration,
    required this.shiftZoneInterval,
    required this.shiftStartEndTolerance,
    required this.shiftInnerTolerance,
    required this.shiftPeriodGap,
    required this.shiftBaselineHours,
    required this.shiftCeilingHours,
    required this.roundingMode,
    required this.maxReportDateRange,
  });

  String get dailyEndTime {
    final parts = dailyStartTime.split(':');
    if (parts.length != 2) return '';
    final startMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final endMinutes = startMinutes + dailyWorkDuration * 60;
    final h = (endMinutes ~/ 60) % 24;
    final m = endMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  int get shiftZoneCount {
    if (shiftZoneInterval == 0) return 0;
    return shiftDuration ~/ shiftZoneInterval;
  }

  SettingsState copyWith({
    String? dailyStartTime,
    int? dailyWorkDuration,
    int? dailyMaxOvertime,
    List<String>? shiftStartTimes,
    int? shiftDuration,
    int? shiftZoneInterval,
    int? shiftStartEndTolerance,
    int? shiftInnerTolerance,
    int? shiftPeriodGap,
    int? shiftBaselineHours,
    int? shiftCeilingHours,
    String? roundingMode,
    int? maxReportDateRange,
  }) {
    return SettingsState(
      dailyStartTime: dailyStartTime ?? this.dailyStartTime,
      dailyWorkDuration: dailyWorkDuration ?? this.dailyWorkDuration,
      dailyMaxOvertime: dailyMaxOvertime ?? this.dailyMaxOvertime,
      shiftStartTimes: shiftStartTimes ?? this.shiftStartTimes,
      shiftDuration: shiftDuration ?? this.shiftDuration,
      shiftZoneInterval: shiftZoneInterval ?? this.shiftZoneInterval,
      shiftStartEndTolerance: shiftStartEndTolerance ?? this.shiftStartEndTolerance,
      shiftInnerTolerance: shiftInnerTolerance ?? this.shiftInnerTolerance,
      shiftPeriodGap: shiftPeriodGap ?? this.shiftPeriodGap,
      shiftBaselineHours: shiftBaselineHours ?? this.shiftBaselineHours,
      shiftCeilingHours: shiftCeilingHours ?? this.shiftCeilingHours,
      roundingMode: roundingMode ?? this.roundingMode,
      maxReportDateRange: maxReportDateRange ?? this.maxReportDateRange,
    );
  }
}

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  late final SettingsRepository _repo;

  @override
  Future<SettingsState> build() async {
    _repo = SettingsRepository(DatabaseHelper.instance);
    return _load();
  }

  Future<SettingsState> _load() async {
    final dailyStartTime = await _repo.getString('daily_start_time', defaultValue: '09:00');
    final dailyWorkDuration = await _repo.getInt('daily_work_duration', defaultValue: 8);
    final dailyMaxOvertime = await _repo.getInt('daily_max_overtime', defaultValue: 3);
    final shiftStartTimes = await _repo.getShiftStartTimes();
    final shiftDuration = await _repo.getInt('shift_duration', defaultValue: 24);
    final shiftZoneInterval = await _repo.getInt('shift_zone_interval', defaultValue: 6);
    final shiftStartEndTolerance = await _repo.getInt('shift_start_end_tolerance', defaultValue: 30);
    final shiftInnerTolerance = await _repo.getInt('shift_inner_tolerance', defaultValue: 60);
    final shiftPeriodGap = await _repo.getInt('shift_period_gap', defaultValue: 6);
    final shiftBaselineHours = await _repo.getInt('shift_baseline_hours', defaultValue: 154);
    final shiftCeilingHours = await _repo.getInt('shift_ceiling_hours', defaultValue: 192);
    final roundingMode = await _repo.getString('rounding_mode', defaultValue: 'quarter');
    final maxReportDateRange = await _repo.getInt('max_report_date_range', defaultValue: 31);

    return SettingsState(
      dailyStartTime: dailyStartTime,
      dailyWorkDuration: dailyWorkDuration,
      dailyMaxOvertime: dailyMaxOvertime,
      shiftStartTimes: shiftStartTimes,
      shiftDuration: shiftDuration,
      shiftZoneInterval: shiftZoneInterval,
      shiftStartEndTolerance: shiftStartEndTolerance,
      shiftInnerTolerance: shiftInnerTolerance,
      shiftPeriodGap: shiftPeriodGap,
      shiftBaselineHours: shiftBaselineHours,
      shiftCeilingHours: shiftCeilingHours,
      roundingMode: roundingMode,
      maxReportDateRange: maxReportDateRange,
    );
  }

  Future<void> setDailyStartTime(String time) async {
    await _repo.setValue('daily_start_time', time);
    state = AsyncData(state.requireValue.copyWith(dailyStartTime: time));
  }

  Future<void> setIntSetting(String key, int value, SettingsState Function(SettingsState s) updater) async {
    await _repo.setValue(key, value.toString());
    state = AsyncData(updater(state.requireValue));
  }

  Future<void> setDailyWorkDuration(int hours) =>
      setIntSetting('daily_work_duration', hours, (s) => s.copyWith(dailyWorkDuration: hours));

  Future<void> setDailyMaxOvertime(int hours) =>
      setIntSetting('daily_max_overtime', hours, (s) => s.copyWith(dailyMaxOvertime: hours));

  Future<void> setShiftDuration(int hours) =>
      setIntSetting('shift_duration', hours, (s) => s.copyWith(shiftDuration: hours));

  Future<void> setShiftZoneInterval(int hours) =>
      setIntSetting('shift_zone_interval', hours, (s) => s.copyWith(shiftZoneInterval: hours));

  Future<void> setShiftStartEndTolerance(int minutes) =>
      setIntSetting('shift_start_end_tolerance', minutes, (s) => s.copyWith(shiftStartEndTolerance: minutes));

  Future<void> setShiftInnerTolerance(int minutes) =>
      setIntSetting('shift_inner_tolerance', minutes, (s) => s.copyWith(shiftInnerTolerance: minutes));

  Future<void> setShiftPeriodGap(int hours) =>
      setIntSetting('shift_period_gap', hours, (s) => s.copyWith(shiftPeriodGap: hours));

  Future<void> setShiftBaselineHours(int hours) =>
      setIntSetting('shift_baseline_hours', hours, (s) => s.copyWith(shiftBaselineHours: hours));

  Future<void> setShiftCeilingHours(int hours) =>
      setIntSetting('shift_ceiling_hours', hours, (s) => s.copyWith(shiftCeilingHours: hours));

  Future<void> setRoundingMode(String mode) async {
    await _repo.setValue('rounding_mode', mode);
    state = AsyncData(state.requireValue.copyWith(roundingMode: mode));
  }

  Future<void> setMaxReportDateRange(int days) =>
      setIntSetting('max_report_date_range', days, (s) => s.copyWith(maxReportDateRange: days));

  Future<void> addShiftStartTime(String time) async {
    final current = List<String>.from(state.requireValue.shiftStartTimes);
    if (current.contains(time)) return;
    current.add(time);
    current.sort();
    await _repo.setShiftStartTimes(current);
    state = AsyncData(state.requireValue.copyWith(shiftStartTimes: current));
  }

  Future<void> removeShiftStartTime(String time) async {
    final current = List<String>.from(state.requireValue.shiftStartTimes);
    if (current.length <= 1) return;
    current.remove(time);
    await _repo.setShiftStartTimes(current);
    state = AsyncData(state.requireValue.copyWith(shiftStartTimes: current));
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
