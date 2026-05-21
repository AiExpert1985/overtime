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
                        fontWeight: FontWeight.bold, fontSize: 22),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    loadedData.department,
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: _exporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _ExportButton(onTap: () => _doExport(loadedData)),
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
// Export button — prominent outlined button with icon
// ---------------------------------------------------------------------------

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
              width: 1.5),
          borderRadius: BorderRadius.circular(10),
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_rounded,
                size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'تصدير',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
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
            Container(width: 5, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
// Daily body — stateful to hold filter state
// ---------------------------------------------------------------------------

class _DailyDetailBody extends ConsumerStatefulWidget {
  const _DailyDetailBody({required this.state});

  final DetailState state;

  @override
  ConsumerState<_DailyDetailBody> createState() => _DailyDetailBodyState();
}

class _DailyDetailBodyState extends ConsumerState<_DailyDetailBody> {
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

  // Day type filter
  bool _showDaoam = true;
  bool _showEtla = true;

  // Overtime filter
  bool _hasOvertime = true;
  bool _noOvertime = true;

  List<DailyPeriodRow> _applyFilters(List<DailyPeriodRow> periods) {
    return periods.where((p) {
      final isOff = p.dayType == 'off';
      final dayTypeMatch =
          (_showDaoam && !isOff) || (_showEtla && isOff);
      if (!dayTypeMatch) return false;

      final hasOt = p.overtimeMinutes > 0;
      final otMatch =
          (_hasOvertime && hasOt) || (_noOvertime && !hasOt);
      if (!otMatch) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final roundingMode =
        ref.watch(settingsProvider).whenOrNull(data: (s) => s.roundingMode) ??
            'quarter';
    final periods = widget.state.dailyPeriods;

    final offOvertime = periods
        .where((p) => p.dayType == 'off')
        .fold(0, (s, p) => s + p.overtimeMinutes);
    final regularOvertime = periods
        .where((p) => p.dayType != 'off')
        .fold(0, (s, p) => s + p.overtimeMinutes);

    final visible = _applyFilters(periods);

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
                      value:
                          _fmtOvertimeMinutes(regularOvertime, roundingMode),
                      icon: Icons.work_rounded,
                      accentColor: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SummaryCard(
                      label: 'إجمالي الإضافي',
                      value: _fmtOvertimeMinutes(
                          widget.state.totalOvertimeMinutes, roundingMode),
                      icon: Icons.verified_rounded,
                      accentColor: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _DailyFilterTableHeader(
          columns: _columns,
          flexes: _flexes,
          showDaoam: _showDaoam,
          showEtla: _showEtla,
          hasOvertime: _hasOvertime,
          noOvertime: _noOvertime,
          onShowDaoamChanged: (v) => setState(() => _showDaoam = v),
          onShowEtlaChanged: (v) => setState(() => _showEtla = v),
          onHasOvertimeChanged: (v) => setState(() => _hasOvertime = v),
          onNoOvertimeChanged: (v) => setState(() => _noOvertime = v),
        ),
        Expanded(
          child: visible.isEmpty
              ? const _EmptyState(message: 'لا توجد أيام مطابقة للفلاتر')
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, i) => _DailyPeriodRowWidget(
                    period: visible[i],
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
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.45),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cell(
            flex: flexes[0],
            child: Text(_shortDate(period.periodDate),
                textAlign: TextAlign.center),
          ),
          _Cell(
            flex: flexes[1],
            child: Text(_shortDate(period.endDate),
                textAlign: TextAlign.center),
          ),
          // Zones column: not centered — structured sub-table
          _Cell(
            flex: flexes[2],
            centered: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ZoneSubHeader(),
                ...zones.map(
                  (z) =>
                      _ZoneWidget(zone: z, toleranceMinutes: toleranceMinutes),
                ),
              ],
            ),
          ),
          _Cell(
            flex: flexes[3],
            child: Text(_fmtDuration(period.totalAttendanceDuration),
                textAlign: TextAlign.center),
          ),
          _Cell(
            flex: flexes[4],
            child: Text('${period.hoursCounted} ساعة',
                textAlign: TextAlign.center),
          ),
          _Cell(
            flex: flexes[5],
            child: Text(period.notes ?? '', textAlign: TextAlign.center),
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
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.45),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cell(
            flex: flexes[0],
            child: Text(_shortDate(period.date), textAlign: TextAlign.center),
          ),
          _Cell(
            flex: flexes[1],
            child: Text(period.weekday, textAlign: TextAlign.center),
          ),
          _Cell(
            flex: flexes[2],
            child: Text(dayTypeLabel, textAlign: TextAlign.center),
          ),
          _Cell(
            flex: flexes[3],
            child: Text(entry, textAlign: TextAlign.center),
          ),
          _Cell(
            flex: flexes[4],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: intermediates
                  .map((ts) => Text(_fmtTime(ts), textAlign: TextAlign.center))
                  .toList(),
            ),
          ),
          _Cell(
            flex: flexes[5],
            child: Text(exit, textAlign: TextAlign.center),
          ),
          _Cell(
            flex: flexes[6],
            child: Text(_fmtDuration(period.totalAttendanceDuration),
                textAlign: TextAlign.center),
          ),
          _Cell(
            flex: flexes[7],
            child: Text(_fmtDuration(period.overtimeMinutes),
                textAlign: TextAlign.center),
          ),
          _Cell(
            flex: flexes[8],
            child: Text(period.notes ?? '', textAlign: TextAlign.center),
          ),
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
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.45),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cell(
            flex: flexes[0],
            child: Text(_shortDate(period.date), textAlign: TextAlign.center),
          ),
          _Cell(
            flex: flexes[1],
            child: Text(period.weekday, textAlign: TextAlign.center),
          ),
          _Cell(
            flex: flexes[2],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: period.timestamps
                  .map((ts) => Text(_fmtTime(ts), textAlign: TextAlign.center))
                  .toList(),
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
        .where(
            (ts) => !ts.isBefore(zone.startTime) && !ts.isAfter(windowEnd))
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
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
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
// Table headers
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

// Daily table header with inline filters under نوع اليوم and الوقت الإضافي
class _DailyFilterTableHeader extends StatelessWidget {
  const _DailyFilterTableHeader({
    required this.columns,
    required this.flexes,
    required this.showDaoam,
    required this.showEtla,
    required this.hasOvertime,
    required this.noOvertime,
    required this.onShowDaoamChanged,
    required this.onShowEtlaChanged,
    required this.onHasOvertimeChanged,
    required this.onNoOvertimeChanged,
  });

  final List<String> columns;
  final List<int> flexes;
  final bool showDaoam;
  final bool showEtla;
  final bool hasOvertime;
  final bool noOvertime;
  final void Function(bool) onShowDaoamChanged;
  final void Function(bool) onShowEtlaChanged;
  final void Function(bool) onHasOvertimeChanged;
  final void Function(bool) onNoOvertimeChanged;

  // Column indices of filtered columns
  static const int _dayTypeCol = 2;
  static const int _overtimeCol = 7;

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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label row
          Row(
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
          const SizedBox(height: 8),
          // Filter row — only filtered columns show chips; others are empty spacers
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < columns.length; i++)
                Expanded(
                  flex: flexes[i],
                  child: switch (i) {
                    _dayTypeCol => Center(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: [
                            _ToggleChip(
                              label: 'دوام',
                              selected: showDaoam,
                              onSelected: onShowDaoamChanged,
                            ),
                            _ToggleChip(
                              label: 'عطلة',
                              selected: showEtla,
                              onSelected: onShowEtlaChanged,
                            ),
                          ],
                        ),
                      ),
                    _overtimeCol => Center(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: [
                            _ToggleChip(
                              label: 'لديه إضافي',
                              selected: hasOvertime,
                              onSelected: onHasOvertimeChanged,
                            ),
                            _ToggleChip(
                              label: 'بدون إضافي',
                              selected: noOvertime,
                              onSelected: onNoOvertimeChanged,
                            ),
                          ],
                        ),
                      ),
                    _ => const SizedBox(),
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toggle chip — same pattern as report screen
// ---------------------------------------------------------------------------

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final void Function(bool) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
            color: selected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _Cell extends StatelessWidget {
  const _Cell({
    required this.flex,
    required this.child,
    this.centered = true,
  });

  final int flex;
  final Widget child;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: centered ? Center(child: child) : child,
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
              color:
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
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
