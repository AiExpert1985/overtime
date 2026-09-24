// Arabic labels for displaying a report's settings snapshot (see Report
// domain model). Mirrors the labels already used on the Settings screen, so
// the same setting reads identically whether viewed live or from a snapshot.

import 'dart:convert';

const _roundingModeLabels = {
  'none': 'بدون تقريب',
  'quarter': 'تقريب لربع ساعة',
  'half': 'تقريب لنصف ساعة',
  'hour': 'تقريب لساعة كاملة',
};

class SettingsSnapshotField {
  const SettingsSnapshotField(this.label, this.value);
  final String label;
  final String value;
}

List<SettingsSnapshotField> describeSettingsSnapshot(
  Map<String, String> snapshot,
) {
  String unit(String key, String suffix) =>
      snapshot.containsKey(key) ? '${snapshot[key]} $suffix' : '—';

  return [
    SettingsSnapshotField('بداية الدوام', snapshot['daily_start_time'] ?? '—'),
    SettingsSnapshotField('ساعات الدوام', unit('daily_work_duration', 'ساعة')),
    SettingsSnapshotField('اقصى وقت اضافي', unit('daily_max_overtime', 'ساعة')),
    SettingsSnapshotField(
      'سماحية التأخير الصباحي',
      unit('daily_delay_allowance', 'دقيقة'),
    ),
    SettingsSnapshotField(
      'هامش تجاهل الوقت الإضافي',
      unit('daily_overtime_margin', 'دقيقة'),
    ),
    SettingsSnapshotField(
      'أوقات بداية المناوبة',
      _decodeStartTimes(snapshot['shift_start_times']),
    ),
    SettingsSnapshotField('مدة المناوبة', unit('shift_duration', 'ساعة')),
    SettingsSnapshotField('ساعات البصمة', unit('shift_zone_interval', 'ساعة')),
    SettingsSnapshotField(
      'سماحية بصمة الدخول والخروج',
      unit('shift_edge_tolerance', 'دقيقة'),
    ),
    SettingsSnapshotField(
      'سماحية البصمات الداخلية',
      unit('shift_inner_tolerance', 'دقيقة'),
    ),
    SettingsSnapshotField(
      'سماحية مدة المناوبة',
      unit('shift_duration_tolerance', 'دقيقة'),
    ),
    SettingsSnapshotField(
      'ساعات العمل الأساسية',
      unit('shift_baseline_hours', 'ساعة'),
    ),
    SettingsSnapshotField(
      'سقف الساعات الأقصى',
      unit('shift_ceiling_hours', 'ساعة'),
    ),
    SettingsSnapshotField(
      'وضع التقريب للساعات الاضافية',
      _roundingModeLabels[snapshot['rounding_mode']] ?? '—',
    ),
    SettingsSnapshotField(
      'الحد الأقصى لمدة التقرير',
      unit('max_report_date_range', 'يوم'),
    ),
  ];
}

String _decodeStartTimes(String? raw) {
  if (raw == null) return '—';
  final times = List<String>.from(jsonDecode(raw) as List);
  return times.isEmpty ? '—' : times.join('، ');
}
