import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في تحميل الإعدادات: $e')),
        data: (settings) => _SettingsBody(settings: settings),
      ),
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  final SettingsState settings;
  const _SettingsBody({required this.settings});

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(settingsProvider.notifier);
    final settings = widget.settings;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // ── Daily Employee Settings ───────────────────────────────────
              _SectionHeader(title: 'إعدادات موظف الدوام الصباحي'),
              _TimeRow(
                label: 'وقت البداية',
                hint: 'وقت بداية الدوام الصباحي. يُستخدم للتحقق من البصمة الأولى واحتساب وقت النهاية.',
                value: settings.dailyStartTime,
                onChanged: notifier.setDailyStartTime,
              ),
              _NumberRow(
                label: 'مدة الدوام',
                hint: 'مدة يوم العمل الاعتيادي بالساعات.',
                value: settings.dailyWorkDuration,
                unit: 'ساعة',
                onChanged: notifier.setDailyWorkDuration,
              ),
              _NumberRow(
                label: 'الحد الأقصى للإضافي اليومي',
                hint: 'أقصى عدد ساعات إضافية يُحتسب في اليوم الواحد.',
                value: settings.dailyMaxOvertime,
                unit: 'ساعة',
                onChanged: notifier.setDailyMaxOvertime,
              ),
              _DerivedRow(
                label: 'وقت النهاية',
                value: 'وقت النهاية: ${settings.dailyEndTime}',
              ),
              const SizedBox(height: 20),

              // ── Shift Employee Settings ───────────────────────────────────
              _SectionHeader(title: 'إعدادات موظف المناوبة'),
              _ShiftStartTimesRow(
                times: settings.shiftStartTimes,
                onAdd: (t) => notifier.addShiftStartTime(t),
                onRemove: (t) => notifier.removeShiftStartTime(t),
              ),
              _NumberRow(
                label: 'مدة المناوبة',
                hint: 'المدة الكاملة للمناوبة الواحدة بالساعات.',
                value: settings.shiftDuration,
                unit: 'ساعة',
                onChanged: notifier.setShiftDuration,
              ),
              _NumberRow(
                label: 'فترة نقاط التحقق',
                hint: 'المسافة الزمنية بين كل نقطة تحقق والأخرى.',
                value: settings.shiftZoneInterval,
                unit: 'ساعة',
                onChanged: notifier.setShiftZoneInterval,
              ),
              _NumberRow(
                label: 'هامش البداية والنهاية',
                hint: 'الهامش الزمني بالدقائق لبصمتي البداية والنهاية.',
                value: settings.shiftStartEndTolerance,
                unit: 'دقيقة',
                onChanged: notifier.setShiftStartEndTolerance,
              ),
              _NumberRow(
                label: 'هامش النقاط الداخلية',
                hint: 'الهامش الزمني بالدقائق للبصمات في نقاط التحقق الداخلية.',
                value: settings.shiftInnerTolerance,
                unit: 'دقيقة',
                onChanged: notifier.setShiftInnerTolerance,
              ),
              _NumberRow(
                label: 'نافذة الكشف عن فترة جديدة',
                hint: 'المدة التي يُبحث خلالها عن بصمة بداية الفترة التالية.',
                value: settings.shiftPeriodGap,
                unit: 'ساعة',
                onChanged: notifier.setShiftPeriodGap,
              ),
              _NumberRow(
                label: 'ساعات العمل الأساسية',
                hint: 'عدد ساعات العمل الشهرية قبل احتساب الإضافي.',
                value: settings.shiftBaselineHours,
                unit: 'ساعة',
                onChanged: notifier.setShiftBaselineHours,
              ),
              _NumberRow(
                label: 'الحد الأقصى للساعات الشهرية',
                hint: 'أقصى عدد ساعات عمل يُحتسب في الشهر.',
                value: settings.shiftCeilingHours,
                unit: 'ساعة',
                onChanged: notifier.setShiftCeilingHours,
              ),
              _DerivedRow(
                label: 'عدد نقاط التحقق',
                value: 'عدد نقاط التحقق: ${settings.shiftZoneCount}',
              ),
              const SizedBox(height: 20),

              // ── Display Settings ──────────────────────────────────────────
              _SectionHeader(title: 'إعدادات العرض'),
              _RoundingModeRow(
                value: settings.roundingMode,
                onChanged: notifier.setRoundingMode,
              ),
              const SizedBox(height: 20),

              // ── Column Header Management ──────────────────────────────────
              _SectionHeader(title: 'رؤوس الأعمدة'),
              _NavigationRow(
                label: 'إدارة رؤوس الأعمدة',
                description: 'تخصيص أسماء أعمدة ملف الحضور',
                onTap: () => context.pushNamed('column_headers'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Time row ─────────────────────────────────────────────────────────────────

class _TimeRow extends StatelessWidget {
  final String label;
  final String hint;
  final String value;
  final Future<void> Function(String) onChanged;

  const _TimeRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      label: label,
      hint: hint,
      trailing: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _pick(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final parts = value.split(':');
    final initial = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await onChanged(formatted);
    }
  }
}

// ── Number row ────────────────────────────────────────────────────────────────

class _NumberRow extends StatelessWidget {
  final String label;
  final String hint;
  final int value;
  final String unit;
  final Future<void> Function(int) onChanged;

  const _NumberRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      label: label,
      hint: hint,
      trailing: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showDialog(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '$value $unit',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final controller = TextEditingController(text: value.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          decoration: InputDecoration(suffixText: unit),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v != null && v > 0) Navigator.of(ctx).pop(v);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result != null) await onChanged(result);
  }
}

// ── Derived (read-only) row ───────────────────────────────────────────────────

class _DerivedRow extends StatelessWidget {
  final String label;
  final String value;
  const _DerivedRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shift start times row ─────────────────────────────────────────────────────

class _ShiftStartTimesRow extends StatelessWidget {
  final List<String> times;
  final Future<void> Function(String) onAdd;
  final Future<void> Function(String) onRemove;

  const _ShiftStartTimesRow({
    required this.times,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text('أوقات بداية المناوبة',
                style: theme.textTheme.bodyMedium),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: times.map((t) => _TimeChip(
                  time: t,
                  canDelete: times.length > 1,
                  onDelete: () => onRemove(t),
                )).toList(),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => _addTime(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة وقت'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await onAdd(formatted);
    }
  }
}

class _TimeChip extends StatelessWidget {
  final String time;
  final bool canDelete;
  final VoidCallback onDelete;

  const _TimeChip({required this.time, required this.canDelete, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(time),
      deleteIcon: canDelete ? const Icon(Icons.close, size: 14) : null,
      onDeleted: canDelete ? onDelete : null,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ── Rounding mode row ─────────────────────────────────────────────────────────

class _RoundingModeRow extends StatelessWidget {
  final String value;
  final Future<void> Function(String) onChanged;

  const _RoundingModeRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text('وضع التقريب', style: theme.textTheme.bodyMedium),
          ),
          RadioGroup<String>(
            groupValue: value,
            onChanged: (v) { if (v != null) onChanged(v); },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _RadioOption(label: 'بدون تقريب', optionValue: 'none'),
                _RadioOption(label: 'تقريب لربع ساعة', optionValue: 'quarter'),
                _RadioOption(label: 'تقريب لساعة كاملة', optionValue: 'hour'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  final String label;
  final String optionValue;

  const _RadioOption({required this.label, required this.optionValue});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: optionValue,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ── Navigation row ────────────────────────────────────────────────────────────

class _NavigationRow extends StatelessWidget {
  final String label;
  final String description;
  final VoidCallback onTap;

  const _NavigationRow({
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── Generic setting row ───────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  final String label;
  final String hint;
  final Widget trailing;

  const _SettingRow({required this.label, required this.hint, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 16),
            tooltip: hint,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(label),
                content: Text(hint),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('إغلاق'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          trailing,
        ],
      ),
    );
  }
}
