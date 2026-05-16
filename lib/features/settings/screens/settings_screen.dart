import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_settings.dart';
import '../domain/column_header.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _initialized = false;

  late TextEditingController _dailyWorkDurationCtrl;
  late TextEditingController _dailyMaxOvertimeCtrl;
  late TextEditingController _dailyDelayAllowanceCtrl;
  late TextEditingController _shiftDurationCtrl;
  late TextEditingController _shiftZoneIntervalCtrl;
  late TextEditingController _shiftToleranceCtrl;
  late TextEditingController _shiftBaselineCtrl;
  late TextEditingController _shiftCeilingCtrl;

  @override
  void dispose() {
    _dailyWorkDurationCtrl.dispose();
    _dailyMaxOvertimeCtrl.dispose();
    _dailyDelayAllowanceCtrl.dispose();
    _shiftDurationCtrl.dispose();
    _shiftZoneIntervalCtrl.dispose();
    _shiftToleranceCtrl.dispose();
    _shiftBaselineCtrl.dispose();
    _shiftCeilingCtrl.dispose();
    super.dispose();
  }

  void _initControllers(AppSettings s) {
    if (_initialized) return;
    _dailyWorkDurationCtrl = TextEditingController(text: '${s.dailyWorkDuration}');
    _dailyMaxOvertimeCtrl = TextEditingController(text: '${s.dailyMaxOvertime}');
    _dailyDelayAllowanceCtrl = TextEditingController(text: '${s.dailyDelayAllowance}');
    _shiftDurationCtrl = TextEditingController(text: '${s.shiftDuration}');
    _shiftZoneIntervalCtrl = TextEditingController(text: '${s.shiftZoneInterval}');
    _shiftToleranceCtrl = TextEditingController(text: '${s.shiftTolerance}');
    _shiftBaselineCtrl = TextEditingController(text: '${s.shiftBaselineHours}');
    _shiftCeilingCtrl = TextEditingController(text: '${s.shiftCeilingHours}');
    _initialized = true;
  }

  // ─── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final headersAsync = ref.watch(columnHeadersProvider);

    return Scaffold(
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في تحميل الإعدادات: $e')),
        data: (settings) {
          _initControllers(settings);
          return headersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ في تحميل عناوين الأعمدة: $e')),
            data: (headers) => _buildContent(settings, headers),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    AppSettings settings,
    Map<String, List<ColumnHeader>> headers,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          children: [
            _sectionHeader('إعدادات موظفي الدوام اليومي'),
            _dailySection(settings),
            _sectionHeader('إعدادات موظفي الدوام بالمناوبة'),
            _shiftSection(settings),
            _sectionHeader('إعدادات العرض'),
            _displaySection(settings),
            _sectionHeader('عناوين الأعمدة'),
            _columnHeadersSection(headers),
          ],
        ),
      ),
    );
  }

  // ─── section headers ─────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }

  // ─── daily section ────────────────────────────────────────────────────────

  Widget _dailySection(AppSettings s) {
    final notifier = ref.read(settingsProvider.notifier);
    return Column(
      children: [
        _settingRow(
          label: 'بداية الدوام',
          hint: 'وقت بداية الدوام الصباحي',
          value: _timeTile(s.dailyStartTime, () => _saveTime(s.dailyStartTime, notifier.updateDailyStartTime)),
        ),
        _settingRow(
          label: 'ساعات الدوام',
          hint: 'مدة يوم العمل الاعتيادي بالساعات',
          value: _numberField(
            _dailyWorkDurationCtrl,
            () => _saveNumber(_dailyWorkDurationCtrl, '${s.dailyWorkDuration}', (v) => v > 0, notifier.updateDailyWorkDuration),
          ),
        ),
        _settingRow(
          label: 'اقصى وقت اضافي',
          hint: 'أقصى عدد ساعات إضافية الممكن احتسابه للموظف في اليوم الواحد',
          value: _numberField(
            _dailyMaxOvertimeCtrl,
            () => _saveNumber(_dailyMaxOvertimeCtrl, '${s.dailyMaxOvertime}', (v) => v > 0, notifier.updateDailyMaxOvertime),
          ),
        ),
        _settingRow(
          label: 'وقت السماح بالتأخير',
          hint: 'الهامش الزمني المسموح به للموظف للحضور بعد وقت البداية في أيام العمل الاعتيادية',
          value: _numberField(
            _dailyDelayAllowanceCtrl,
            () => _saveNumber(_dailyDelayAllowanceCtrl, '${s.dailyDelayAllowance}', (v) => v >= 0, notifier.updateDailyDelayAllowance),
          ),
        ),
        _readOnlyRow('وقت النهاية', s.dailyEndTime),
      ],
    );
  }

  // ─── shift section ────────────────────────────────────────────────────────

  Widget _shiftSection(AppSettings s) {
    final notifier = ref.read(settingsProvider.notifier);
    return Column(
      children: [
        _settingRow(
          label: 'بداية المناوبة',
          hint: 'قائمة الأوقات المحتملة لبداية المناوبة ممكن ادخال اكثر من وقت',
          value: _shiftStartTimesList(s),
        ),
        _settingRow(
          label: 'مدة المناوبة',
          hint: 'المدة الكاملة للمناوبة الواحدة بالساعات',
          value: _numberField(
            _shiftDurationCtrl,
            () => _saveNumber(_shiftDurationCtrl, '${s.shiftDuration}', (v) => v > 0, notifier.updateShiftDuration),
          ),
        ),
        _settingRow(
          label: 'عدد ساعات كل بصمة',
          hint: 'الوقت المسموح به للبصمات خلال المناوبة الواحدة',
          value: _numberField(
            _shiftZoneIntervalCtrl,
            () => _saveNumber(_shiftZoneIntervalCtrl, '${s.shiftZoneInterval}', (v) => v > 0 && v <= s.shiftDuration, notifier.updateShiftZoneInterval),
          ),
        ),
        _settingRow(
          label: 'دقائق السماح للبصمة',
          hint: 'الهامش الزمني بالدقائق المسموح به لجميع البصمات في المناوبة',
          value: _numberField(
            _shiftToleranceCtrl,
            () => _saveNumber(_shiftToleranceCtrl, '${s.shiftTolerance}', (v) => v >= 0, notifier.updateShiftTolerance),
          ),
        ),
        _settingRow(
          label: 'ساعات العمل الأساسية',
          hint: 'عدد ساعات العمل الشهرية المطلوبة',
          value: _numberField(
            _shiftBaselineCtrl,
            () => _saveNumber(_shiftBaselineCtrl, '${s.shiftBaselineHours}', (v) => v > 0 && v < s.shiftCeilingHours, notifier.updateShiftBaselineHours),
          ),
        ),
        _settingRow(
          label: 'الحد الأقصى للساعات الشهرية',
          hint: 'أقصى عدد ساعات عمل يُحتسب في الشهر، اي ساعات اكثر منه تهمل و لا تدخل في حساب الساعات الاضافية',
          value: _numberField(
            _shiftCeilingCtrl,
            () => _saveNumber(_shiftCeilingCtrl, '${s.shiftCeilingHours}', (v) => v > s.shiftBaselineHours, notifier.updateShiftCeilingHours),
          ),
        ),
        _readOnlyRow('عدد نقاط التحقق', '${s.zoneCount}'),
      ],
    );
  }

  Widget _shiftStartTimesList(AppSettings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ...s.shiftStartTimes.asMap().entries.map(
          (e) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.value),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'حذف',
                onPressed: s.shiftStartTimes.length <= 1
                    ? null
                    : () => _removeShiftStartTime(e.key, s.shiftStartTimes),
              ),
            ],
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('إضافة وقت'),
          onPressed: () => _addShiftStartTime(s.shiftStartTimes),
        ),
      ],
    );
  }

  // ─── display section ──────────────────────────────────────────────────────

  Widget _displaySection(AppSettings s) {
    const modes = [
      ('none', 'بدون تقريب'),
      ('quarter', 'تقريب لربع ساعة'),
      ('half', 'تقريب لنصف ساعة'),
      ('hour', 'تقريب لساعة كاملة'),
    ];
    return Column(
      children: [
        _settingRow(
          label: 'وضع التقريب',
          hint: 'طريقة عرض الساعات الإضافية: بدون تقريب، تقريب لربع ساعة، نصف ساعة، أو تقريب لساعة كاملة',
          value: const SizedBox.shrink(),
        ),
        RadioGroup<String>(
          groupValue: s.roundingMode,
          onChanged: (v) {
            if (v != null) ref.read(settingsProvider.notifier).updateRoundingMode(v);
          },
          child: Column(
            children: modes
                .map((m) => RadioListTile<String>(title: Text(m.$2), value: m.$1))
                .toList(),
          ),
        ),
      ],
    );
  }

  // ─── column headers section ───────────────────────────────────────────────

  Widget _columnHeadersSection(Map<String, List<ColumnHeader>> headers) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _columnHeaderCard('employee_name', 'اسم الموظف', headers['employee_name'] ?? [])),
        const SizedBox(width: 12),
        Expanded(child: _columnHeaderCard('department', 'القسم', headers['department'] ?? [])),
        const SizedBox(width: 12),
        Expanded(child: _columnHeaderCard('datetime', 'التاريخ والوقت', headers['datetime'] ?? [])),
      ],
    );
  }

  Widget _columnHeaderCard(
    String fieldKey,
    String title,
    List<ColumnHeader> headers,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const Divider(height: 16),
            ...headers.map((h) => _columnHeaderRow(h)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة'),
              onPressed: () => _showAddHeaderDialog(fieldKey, headers),
            ),
          ],
        ),
      ),
    );
  }

  Widget _columnHeaderRow(ColumnHeader header) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(header.headerValue, style: Theme.of(context).textTheme.bodySmall),
          ),
          if (header.isDefault)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.lock_outline, size: 14, color: Colors.grey),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'تعديل',
              onPressed: () => _showEditHeaderDialog(header),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'حذف',
              onPressed: () => _showDeleteHeaderDialog(header),
            ),
          ],
        ],
      ),
    );
  }

  // ─── reusable row widgets ─────────────────────────────────────────────────

  Widget _settingRow({
    required String label,
    required String hint,
    required Widget value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const Spacer(),
          value,
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'معلومات',
            onPressed: () => _showHint(hint),
          ),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController ctrl, VoidCallback onSave) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) onSave();
      },
      child: SizedBox(
        width: 90,
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            isDense: true,
          ),
          onSubmitted: (_) => onSave(),
        ),
      ),
    );
  }

  Widget _timeTile(String time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(time),
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }

  // ─── actions ──────────────────────────────────────────────────────────────

  void _saveNumber(
    TextEditingController ctrl,
    String fallback,
    bool Function(int) valid,
    Future<void> Function(int) save,
  ) async {
    final parsed = int.tryParse(ctrl.text.trim());
    if (parsed == null || !valid(parsed)) {
      ctrl.text = fallback;
      _snack('قيمة غير صالحة');
      return;
    }
    try {
      await save(parsed);
    } catch (_) {
      ctrl.text = fallback;
      _snack('حدث خطأ أثناء الحفظ');
    }
  }

  void _saveTime(String current, Future<void> Function(String) save) async {
    final picked = await _pickTime(current);
    if (picked == null || !mounted) return;
    try {
      await save(picked);
    } catch (_) {
      _snack('حدث خطأ أثناء الحفظ');
    }
  }

  void _addShiftStartTime(List<String> current) async {
    final picked = await _pickTime('08:00');
    if (picked == null || !mounted) return;
    try {
      await ref.read(settingsProvider.notifier).updateShiftStartTimes([...current, picked]);
    } catch (_) {
      _snack('حدث خطأ أثناء الحفظ');
    }
  }

  void _removeShiftStartTime(int index, List<String> current) async {
    final updated = List<String>.from(current)..removeAt(index);
    try {
      await ref.read(settingsProvider.notifier).updateShiftStartTimes(updated);
    } catch (_) {
      _snack('حدث خطأ أثناء الحفظ');
    }
  }

  Future<String?> _pickTime(String current) async {
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return null;
    return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  void _showHint(String description) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(description, textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
        ],
      ),
    );
  }

  void _showAddHeaderDialog(String fieldKey, List<ColumnHeader> existing) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => _HeaderInputDialog(
        title: 'إضافة قيمة',
        controller: ctrl,
        confirmLabel: 'إضافة',
        onConfirm: (value) {
          if (existing.any((h) => h.headerValue == value)) return 'القيمة موجودة مسبقاً';
          Navigator.pop(ctx);
          ref.read(columnHeadersProvider.notifier).add(fieldKey, value);
          return null;
        },
      ),
    );
  }

  void _showEditHeaderDialog(ColumnHeader header) {
    final ctrl = TextEditingController(text: header.headerValue);
    showDialog(
      context: context,
      builder: (ctx) => _HeaderInputDialog(
        title: 'تعديل القيمة',
        controller: ctrl,
        confirmLabel: 'حفظ',
        onConfirm: (value) {
          if (value == header.headerValue) {
            Navigator.pop(ctx);
            return null;
          }
          Navigator.pop(ctx);
          ref.read(columnHeadersProvider.notifier).updateHeader(header.id, value);
          return null;
        },
      ),
    );
  }

  void _showDeleteHeaderDialog(ColumnHeader header) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('هل تريد حذف "${header.headerValue}"؟', textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(columnHeadersProvider.notifier).delete(header.id);
            },
            child: Text('حذف', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

// ─── Header input dialog ──────────────────────────────────────────────────────

class _HeaderInputDialog extends StatefulWidget {
  const _HeaderInputDialog({
    required this.title,
    required this.controller,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final TextEditingController controller;
  final String confirmLabel;
  // Returns an error string or null on success.
  final String? Function(String value) onConfirm;

  @override
  State<_HeaderInputDialog> createState() => _HeaderInputDialogState();
}

class _HeaderInputDialogState extends State<_HeaderInputDialog> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, textAlign: TextAlign.right),
      content: TextField(
        controller: widget.controller,
        autofocus: true,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: 'أدخل القيمة',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }

  void _submit() {
    final value = widget.controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'القيمة مطلوبة');
      return;
    }
    final error = widget.onConfirm(value);
    if (error != null) {
      setState(() => _error = error);
    }
  }
}
