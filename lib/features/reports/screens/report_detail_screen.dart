import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../settings/providers/settings_provider.dart';
import '../domain/daily_period_row.dart';
import '../domain/shift_period_row.dart';
import '../domain/zone_row.dart';
import '../providers/detail_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _fmtTime(DateTime dt) => DateFormat('h:mm a', 'ar').format(dt);

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _shortDate(String isoDate) {
  final d = DateTime.parse(isoDate);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

String _fmtDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '$h:${m.toString().padLeft(2, '0')}';
}

String _fmtOvertimeMinutes(int minutes, String mode) {
  int rounded = minutes;
  switch (mode) {
    case 'quarter':
      rounded = ((minutes / 15).ceil() * 15);
    case 'half':
      rounded = ((minutes / 30).ceil() * 30);
    case 'hour':
      rounded = ((minutes / 60).ceil() * 60);
  }
  final h = rounded ~/ 60;
  final m = rounded % 60;
  if (m == 0) return '$h ساعة';
  return '$h:${m.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ReportDetailScreen extends ConsumerWidget {
  final int reportId;
  final String employeeType;
  final int employeeResultId;

  const ReportDetailScreen({
    super.key,
    required this.reportId,
    required this.employeeType,
    required this.employeeResultId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (
      reportId: reportId,
      employeeResultId: employeeResultId,
      employeeType: employeeType,
    );
    final state = ref.watch(detailProvider(args));

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الموظف')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('حدث خطأ أثناء التحميل: $e')),
        data: (data) => data.employeeType == 'shift'
            ? _ShiftDetailBody(state: data)
            : _DailyDetailBody(state: data),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shift body
// ---------------------------------------------------------------------------

class _ShiftDetailBody extends StatelessWidget {
  const _ShiftDetailBody({required this.state});

  final DetailState state;

  static const _columns = [
    'تاريخ البداية',
    'تاريخ النهاية',
    'نقاط التحقق',
    'ساعات الحضور',
    'الساعات المحتسبة',
    'ملاحظات',
  ];
  static const _flexes = [2, 2, 5, 2, 2, 3];

  @override
  Widget build(BuildContext context) {
    final periods = state.shiftPeriods;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShiftEmployeeHeader(state: state),
        _DetailTableHeader(columns: _columns, flexes: _flexes),
        Expanded(
          child: periods.isEmpty
              ? const _EmptyState(message: 'لا توجد فترات محتسبة')
              : ListView.builder(
                  itemCount: periods.length,
                  itemBuilder: (_, i) => _ShiftPeriodRowWidget(
                    period: periods[i],
                    flexes: _flexes,
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Daily body
// ---------------------------------------------------------------------------

class _DailyDetailBody extends StatelessWidget {
  const _DailyDetailBody({required this.state});

  final DetailState state;

  static const _columns = [
    'التاريخ',
    'اليوم',
    'نوع اليوم',
    'الدخول',
    'البصمات',
    'الخروج',
    'ساعات الحضور',
    'الوقت الإضافي',
    'ملاحظات',
  ];
  static const _flexes = [2, 2, 2, 2, 3, 2, 2, 2, 3];

  @override
  Widget build(BuildContext context) {
    final periods = state.dailyPeriods;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DailyEmployeeHeader(state: state),
        _DetailTableHeader(columns: _columns, flexes: _flexes),
        Expanded(
          child: periods.isEmpty
              ? const _EmptyState(message: 'لا توجد أيام مسجلة')
              : ListView.builder(
                  itemCount: periods.length,
                  itemBuilder: (_, i) => _DailyPeriodRowWidget(
                    period: periods[i],
                    flexes: _flexes,
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Employee headers
// ---------------------------------------------------------------------------

class _ShiftEmployeeHeader extends ConsumerWidget {
  const _ShiftEmployeeHeader({required this.state});

  final DetailState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final periods = state.shiftPeriods;

    final validDays = periods.where((p) => p.isValid).length;
    final totalAttendanceMin =
        periods.fold(0, (s, p) => s + p.totalAttendanceDuration);
    final totalHoursCounted =
        periods.fold(0, (s, p) => s + p.hoursCounted);

    final settings =
        ref.watch(settingsProvider).whenOrNull(data: (s) => s);
    String overtimeText = '—';
    if (settings != null) {
      final ot = max(
        0,
        min(totalHoursCounted, settings.shiftCeilingHours) -
            settings.shiftBaselineHours,
      );
      overtimeText = '$ot ساعة';
    }

    return _HeaderCard(
      children: [
        _HeaderRow(label: 'الموظف', value: state.employeeName),
        _HeaderRow(label: 'القسم', value: state.department),
        _HeaderRow(
          label: 'النطاق',
          value:
              '${_fmtDate(state.reportRangeStart)} — ${_fmtDate(state.reportRangeEnd)}',
        ),
        _HeaderRow(label: 'أيام المناوبة الصالحة', value: '$validDays يوم'),
        _HeaderRow(
          label: 'إجمالي ساعات الحضور',
          value: _fmtDuration(totalAttendanceMin),
        ),
        _HeaderRow(
          label: 'الساعات المحتسبة',
          value: '$totalHoursCounted ساعة',
        ),
        _HeaderRow(
          label: 'الساعات الإضافية',
          value: overtimeText,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _DailyEmployeeHeader extends ConsumerWidget {
  const _DailyEmployeeHeader({required this.state});

  final DetailState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final roundingMode =
        ref.watch(settingsProvider).whenOrNull(data: (s) => s.roundingMode) ??
            'quarter';
    return _HeaderCard(
      children: [
        _HeaderRow(label: 'الموظف', value: state.employeeName),
        _HeaderRow(label: 'القسم', value: state.department),
        _HeaderRow(
          label: 'النطاق',
          value:
              '${_fmtDate(state.reportRangeStart)} — ${_fmtDate(state.reportRangeEnd)}',
        ),
        _HeaderRow(
          label: 'الوقت الإضافي الإجمالي',
          value: _fmtOvertimeMinutes(state.totalOvertimeMinutes, roundingMode),
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Period row widgets
// ---------------------------------------------------------------------------

class _ShiftPeriodRowWidget extends StatelessWidget {
  const _ShiftPeriodRowWidget({
    required this.period,
    required this.flexes,
  });

  final ShiftPeriodRow period;
  final List<int> flexes;

  @override
  Widget build(BuildContext context) {
    final bg = period.isValid ? null : Colors.red.shade50;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cell(flex: flexes[0], child: Text(_shortDate(period.periodDate))),
          _Cell(flex: flexes[1], child: Text(_shortDate(period.endDate))),
          _Cell(
            flex: flexes[2],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: period.zoneResults
                  .map((z) => _ZoneWidget(zone: z))
                  .toList(),
            ),
          ),
          _Cell(
            flex: flexes[3],
            child: Text(_fmtDuration(period.totalAttendanceDuration)),
          ),
          _Cell(
            flex: flexes[4],
            child: Text('${period.hoursCounted} ساعة'),
          ),
          _Cell(
            flex: flexes[5],
            child: Text(period.notes ?? ''),
          ),
        ],
      ),
    );
  }
}

class _DailyPeriodRowWidget extends StatelessWidget {
  const _DailyPeriodRowWidget({
    required this.period,
    required this.flexes,
  });

  final DailyPeriodRow period;
  final List<int> flexes;

  @override
  Widget build(BuildContext context) {
    final bg = period.isValid ? null : Colors.red.shade50;
    final ts = period.timestamps;
    final entry = ts.isNotEmpty ? _fmtTime(ts.first) : '—';
    final exit = ts.length > 1 ? _fmtTime(ts.last) : '—';
    final intermediates =
        ts.length > 2 ? ts.sublist(1, ts.length - 1) : <DateTime>[];
    final dayTypeLabel = period.dayType == 'off' ? 'عطلة' : 'عادي';

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cell(flex: flexes[0], child: Text(_shortDate(period.date))),
          _Cell(flex: flexes[1], child: Text(period.weekday)),
          _Cell(flex: flexes[2], child: Text(dayTypeLabel)),
          _Cell(flex: flexes[3], child: Text(entry)),
          _Cell(
            flex: flexes[4],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: intermediates
                  .map((ts) => Text(_fmtTime(ts)))
                  .toList(),
            ),
          ),
          _Cell(flex: flexes[5], child: Text(exit)),
          _Cell(
            flex: flexes[6],
            child: Text(_fmtDuration(period.totalAttendanceDuration)),
          ),
          _Cell(
            flex: flexes[7],
            child: Text(_fmtDuration(period.overtimeMinutes)),
          ),
          _Cell(flex: flexes[8], child: Text(period.notes ?? '')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zone widget
// ---------------------------------------------------------------------------

class _ZoneWidget extends StatelessWidget {
  const _ZoneWidget({required this.zone});

  final ZoneRow zone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label =
        'نقطة ${zone.zoneIndex + 1}: ${DateFormat('H:mm').format(zone.startTime)}';

    return Container(
      color: zone.isSatisfied ? null : Colors.red.shade50,
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!zone.isSatisfied)
                Text(
                  '✗ ',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          for (final ts in zone.timestamps)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(_fmtTime(ts), style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Wrap(
        spacing: 32,
        runSpacing: 6,
        children: children,
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.label,
    required this.value,
    this.style,
  });

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(value, style: style ?? theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _DetailTableHeader extends StatelessWidget {
  const _DetailTableHeader({
    required this.columns,
    required this.flexes,
  });

  final List<String> columns;
  final List<int> flexes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: flexes[i],
              child: Text(
                columns[i],
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: child,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
