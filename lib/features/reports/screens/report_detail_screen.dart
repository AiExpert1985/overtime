import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../settings/providers/settings_provider.dart';
import '../domain/daily_period_row.dart';
import '../domain/shift_period_row.dart';
import '../domain/undetected_period_row.dart';
import '../domain/zone_row.dart';
import '../providers/detail_provider.dart';
import '../services/report_export_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _fmtTime(DateTime dt) => DateFormat('h:mm a', 'ar').format(dt);

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

class ReportDetailScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  bool _exporting = false;

  DetailArgs get _args => (
        reportId: widget.reportId,
        employeeResultId: widget.employeeResultId,
        employeeType: widget.employeeType,
      );

  Future<void> _doExport(DetailState data) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final settings = ref.read(settingsProvider).whenOrNull(data: (s) => s);
      final roundingMode = settings?.roundingMode ?? 'quarter';
      String? path;
      if (data.employeeType == 'shift') {
        path = await ReportExportService().exportShiftEmployee(
          state: data,
          baselineHours: settings?.shiftBaselineHours ?? 0,
          ceilingHours: settings?.shiftCeilingHours ?? 0,
        );
      } else if (data.employeeType == 'daily') {
        path = await ReportExportService().exportDailyEmployee(
          state: data,
          roundingMode: roundingMode,
        );
      } else {
        path = await ReportExportService().exportUndetectedEmployee(state: data);
      }
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تم الحفظ: $path')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء التصدير')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detailProvider(_args));
    final loadedData = state.whenOrNull(data: (d) => d);
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: loadedData != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    loadedData.employeeName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    loadedData.department,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              )
            : const Text(
                'تفاصيل الموظف',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (loadedData != null)
            _exporting
                ? const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _AppBarAction(
                    icon: Icons.download_rounded,
                    label: 'تصدير',
                    onTap: () => _doExport(loadedData),
                  ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  theme.colorScheme.surface,
                ],
              ),
            ),
          ),

          SafeArea(
            child: state.when(
              loading: () => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'جارٍ تحميل التفاصيل...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ).animate().fade().scale(begin: const Offset(0.9, 0.9)),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text('حدث خطأ أثناء التحميل',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: theme.colorScheme.error)),
                    const SizedBox(height: 4),
                    Text('$e',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              data: (data) {
                if (data.employeeType == 'shift') {
                  return _ShiftDetailBody(state: data);
                }
                if (data.employeeType == 'undetected') {
                  return _UndetectedDetailBody(state: data);
                }
                return _DailyDetailBody(state: data);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppBar action button — icon + label stacked
// ---------------------------------------------------------------------------

class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card — accent bar + icon one end, value + label other end
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Leading accent bar (right edge in RTL)
            Container(width: 5, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon + label
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: accentColor, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Value
                    if (!compact)
                      Text(
                        value,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      )
                    else
                      Flexible(
                        child: Text(
                          value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 3,
                          textAlign: TextAlign.end,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shift body
// ---------------------------------------------------------------------------

class _ShiftDetailBody extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).whenOrNull(data: (s) => s);
    final periods = state.shiftPeriods;

    final validDays = periods.where((p) => p.isValid).length;
    final totalAttendanceMin =
        periods.fold(0, (s, p) => s + p.totalAttendanceDuration);
    final totalHoursCounted =
        periods.fold(0, (s, p) => s + p.hoursCounted);
    final ot = max(
      0,
      min(totalHoursCounted,
              settings?.shiftCeilingHours ?? totalHoursCounted) -
          (settings?.shiftBaselineHours ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.85,
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'أيام المناوبة الصالحة',
                      value: '$validDays يوم',
                      icon: Icons.calendar_month_rounded,
                      accentColor: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SummaryCard(
                      label: 'إجمالي ساعات الحضور',
                      value: _fmtDuration(totalAttendanceMin),
                      icon: Icons.access_time_rounded,
                      accentColor: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SummaryCard(
                      label: 'الساعات الإضافية',
                      value: '$ot ساعة',
                      icon: Icons.verified_rounded,
                      accentColor: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

class _DailyDetailBody extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final roundingMode =
        ref.watch(settingsProvider).whenOrNull(data: (s) => s.roundingMode) ??
            'quarter';
    final periods = state.dailyPeriods;

    final offOvertime = periods
        .where((p) => p.dayType == 'off')
        .fold(0, (s, p) => s + p.overtimeMinutes);
    final regularOvertime = periods
        .where((p) => p.dayType != 'off')
        .fold(0, (s, p) => s + p.overtimeMinutes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.85,
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'إضافي العطل',
                      value: _fmtOvertimeMinutes(offOvertime, roundingMode),
                      icon: Icons.weekend_rounded,
                      accentColor: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SummaryCard(
                      label: 'إضافي الدوام',
                      value: _fmtOvertimeMinutes(regularOvertime, roundingMode),
                      icon: Icons.work_rounded,
                      accentColor: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SummaryCard(
                      label: 'إجمالي الإضافي',
                      value: _fmtOvertimeMinutes(
                          state.totalOvertimeMinutes, roundingMode),
                      icon: Icons.verified_rounded,
                      accentColor: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
// Undetected body
// ---------------------------------------------------------------------------

class _UndetectedDetailBody extends StatelessWidget {
  const _UndetectedDetailBody({required this.state});

  final DetailState state;

  static const _columns = ['التاريخ', 'اليوم', 'البصمات'];
  static const _flexes = [2, 2, 5];

  @override
  Widget build(BuildContext context) {
    final periods = state.undetectedPeriods;
    final totalDays = periods.length;
    final totalTimestamps =
        periods.fold(0, (s, p) => s + p.timestamps.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.85,
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'سبب عدم الكشف',
                      value: state.failureReason,
                      icon: Icons.help_outline_rounded,
                      accentColor: Colors.red,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SummaryCard(
                      label: 'أيام مسجلة',
                      value: '$totalDays يوم',
                      icon: Icons.calendar_today_rounded,
                      accentColor: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SummaryCard(
                      label: 'إجمالي البصمات',
                      value: '$totalTimestamps',
                      icon: Icons.fingerprint_rounded,
                      accentColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _DetailTableHeader(columns: _columns, flexes: _flexes),
        Expanded(
          child: periods.isEmpty
              ? const _EmptyState(
                  message: 'لا تتوفر بيانات للتصفح لهذا التقرير')
              : ListView.builder(
                  itemCount: periods.length,
                  itemBuilder: (_, i) => _UndetectedPeriodRowWidget(
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

    final zones = period.zoneResults;
    final toleranceMinutes = zones.isNotEmpty
        ? zones.last.endTime.difference(zones.last.startTime).inMinutes ~/ 2
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.45),
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
              children: [
                const _ZoneSubHeader(),
                ...zones.map(
                  (z) => _ZoneWidget(zone: z, toleranceMinutes: toleranceMinutes),
                ),
              ],
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
    final dayTypeLabel = period.dayType == 'off' ? 'عطلة' : 'دوام';

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.45),
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
              children: intermediates.map((ts) => Text(_fmtTime(ts))).toList(),
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

class _UndetectedPeriodRowWidget extends StatelessWidget {
  const _UndetectedPeriodRowWidget({
    required this.period,
    required this.flexes,
  });

  final UndetectedPeriodRow period;
  final List<int> flexes;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.45),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cell(flex: flexes[0], child: Text(_shortDate(period.date))),
          _Cell(flex: flexes[1], child: Text(period.weekday)),
          _Cell(
            flex: flexes[2],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: period.timestamps.map((ts) => Text(_fmtTime(ts))).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zone widget
// ---------------------------------------------------------------------------

class _ZoneSubHeader extends StatelessWidget {
  const _ZoneSubHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('النافذة', style: style)),
          Expanded(flex: 4, child: Text('داخل النافذة', style: style)),
          Expanded(flex: 4, child: Text('خارج النافذة', style: style)),
        ],
      ),
    );
  }
}

class _ZoneWidget extends StatelessWidget {
  const _ZoneWidget({required this.zone, required this.toleranceMinutes});

  final ZoneRow zone;
  final int toleranceMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final windowEnd =
        zone.startTime.add(Duration(minutes: 2 * toleranceMinutes));
    final window = '${_fmtTime(zone.startTime)} - ${_fmtTime(windowEnd)}';

    final inWindow = zone.timestamps
        .where((ts) => !ts.isBefore(zone.startTime) && !ts.isAfter(windowEnd))
        .toList();
    final outOfWindow = zone.timestamps
        .where((ts) => ts.isBefore(zone.startTime) || ts.isAfter(windowEnd))
        .toList();

    return Container(
      color: zone.isSatisfied ? null : Colors.red.shade50,
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              window,
              style:
                  theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 4,
            child: inWindow.isNotEmpty
                ? Text(
                    inWindow.map(_fmtTime).join('، '),
                    style: theme.textTheme.bodySmall,
                  )
                : Text(
                    '✗',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          Expanded(
            flex: 4,
            child: outOfWindow.isNotEmpty
                ? Text(
                    outOfWindow.map(_fmtTime).join('، '),
                    style: theme.textTheme.bodySmall,
                  )
                : Text(
                    '✗',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

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
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.primary,
      letterSpacing: 0.3,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
              color: theme.colorScheme.outlineVariant, width: 0.5),
          bottom: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
              width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: flexes[i],
              child: Text(
                columns[i],
                style: labelStyle,
                textAlign: TextAlign.center,
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
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_rounded,
                size: 48,
                color: theme.colorScheme.primary.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fade().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
