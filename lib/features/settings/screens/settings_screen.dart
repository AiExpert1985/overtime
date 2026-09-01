import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user_role.dart';
import '../../auth/providers/auth_provider.dart';
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
  late TextEditingController _shiftEdgeToleranceCtrl;
  late TextEditingController _shiftInnerToleranceCtrl;
  late TextEditingController _shiftDurationToleranceCtrl;
  late TextEditingController _shiftBaselineCtrl;
  late TextEditingController _shiftCeilingCtrl;

  bool _accountsInitialized = false;
  final Map<UserRole, TextEditingController> _usernameCtrls = {};
  final Map<UserRole, TextEditingController> _passwordCtrls = {};

  @override
  void dispose() {
    _dailyWorkDurationCtrl.dispose();
    _dailyMaxOvertimeCtrl.dispose();
    _dailyDelayAllowanceCtrl.dispose();
    _shiftDurationCtrl.dispose();
    _shiftZoneIntervalCtrl.dispose();
    _shiftEdgeToleranceCtrl.dispose();
    _shiftInnerToleranceCtrl.dispose();
    _shiftDurationToleranceCtrl.dispose();
    _shiftBaselineCtrl.dispose();
    _shiftCeilingCtrl.dispose();
    for (final ctrl in _usernameCtrls.values) {
      ctrl.dispose();
    }
    for (final ctrl in _passwordCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _initControllers(AppSettings s) {
    if (_initialized) return;
    _dailyWorkDurationCtrl = TextEditingController(
      text: '${s.dailyWorkDuration}',
    );
    _dailyMaxOvertimeCtrl = TextEditingController(
      text: '${s.dailyMaxOvertime}',
    );
    _dailyDelayAllowanceCtrl = TextEditingController(
      text: '${s.dailyDelayAllowance}',
    );
    _shiftDurationCtrl = TextEditingController(text: '${s.shiftDuration}');
    _shiftZoneIntervalCtrl = TextEditingController(
      text: '${s.shiftZoneInterval}',
    );
    _shiftEdgeToleranceCtrl = TextEditingController(
      text: '${s.shiftEdgeTolerance}',
    );
    _shiftInnerToleranceCtrl = TextEditingController(
      text: '${s.shiftInnerTolerance}',
    );
    _shiftDurationToleranceCtrl = TextEditingController(
      text: '${s.shiftDurationTolerance}',
    );
    _shiftBaselineCtrl = TextEditingController(text: '${s.shiftBaselineHours}');
    _shiftCeilingCtrl = TextEditingController(text: '${s.shiftCeilingHours}');
    _initialized = true;
  }

  void _initAccountControllers(Map<UserRole, (String, String)> accounts) {
    if (_accountsInitialized) return;
    for (final role in UserRole.values) {
      final (username, password) = accounts[role]!;
      _usernameCtrls[role] = TextEditingController(text: username);
      _passwordCtrls[role] = TextEditingController(text: password);
    }
    _accountsInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final headersAsync = ref.watch(columnHeadersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إعدادات النظام',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  Theme.of(context).colorScheme.surface,
                ],
              ),
            ),
          ),

          SafeArea(
            child: settingsAsync.when(
              loading: () => Center(
                child: const CircularProgressIndicator()
                    .animate()
                    .fade()
                    .scale(),
              ),
              error: (e, _) => _ErrorCard(error: e.toString()),
              data: (settings) {
                _initControllers(settings);
                return headersAsync.when(
                  loading: () => Center(
                    child: const CircularProgressIndicator()
                        .animate()
                        .fade()
                        .scale(),
                  ),
                  error: (e, _) => _ErrorCard(error: e.toString()),
                  data: (headers) => _buildContent(settings, headers),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    AppSettings settings,
    Map<String, List<ColumnHeader>> headers,
  ) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SettingsCard(
                      title: 'الدوام اليومي',
                      icon: Icons.wb_sunny_outlined,
                      accentColor: cs.primary,
                      child: _dailySection(settings),
                    ).animate().fade().slideY(begin: 0.1),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _SettingsCard(
                      title: 'الدوام بالمناوبة',
                      icon: Icons.change_circle_outlined,
                      accentColor: cs.secondary,
                      child: _shiftSection(settings),
                    ).animate().fade(delay: 100.ms).slideY(begin: 0.1),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _SettingsCard(
                      title: 'إعدادات العرض',
                      icon: Icons.display_settings_outlined,
                      accentColor: cs.tertiary,
                      child: _displaySection(settings),
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              _SettingsCard(
                title: 'عناوين الأعمدة (تعيين أعمدة ملفات الحضور)',
                icon: Icons.view_column_outlined,
                child: _columnHeadersSection(headers),
              ).animate().fade(delay: 300.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              _SettingsCard(
                title: 'حسابات الدخول',
                icon: Icons.admin_panel_settings_outlined,
                child: _accountsSection(),
              ).animate().fade(delay: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 64),
            ],
          ),
        ),
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
          value: _timeTile(
            s.dailyStartTime,
            () => _saveTime(s.dailyStartTime, notifier.updateDailyStartTime),
          ),
        ),
        _settingRow(
          label: 'ساعات الدوام',
          hint: 'مدة يوم العمل الاعتيادي بالساعات',
          value: _numberField(
            _dailyWorkDurationCtrl,
            () => _saveNumber(
              _dailyWorkDurationCtrl,
              '${s.dailyWorkDuration}',
              (v) => v > 0,
              notifier.updateDailyWorkDuration,
            ),
          ),
        ),
        _settingRow(
          label: 'اقصى وقت اضافي',
          hint: 'أقصى عدد ساعات إضافية الممكن احتسابه للموظف في اليوم الواحد',
          value: _numberField(
            _dailyMaxOvertimeCtrl,
            () => _saveNumber(
              _dailyMaxOvertimeCtrl,
              '${s.dailyMaxOvertime}',
              (v) => v > 0,
              notifier.updateDailyMaxOvertime,
            ),
          ),
        ),
        _settingRow(
          label: 'سماحية التأخير الصباحي',
          hint: 'الهامش الزمني المسموح به للموظف (بالدقيقة) بعد وقت البداية',
          value: _numberField(
            _dailyDelayAllowanceCtrl,
            () => _saveNumber(
              _dailyDelayAllowanceCtrl,
              '${s.dailyDelayAllowance}',
              (v) => v >= 0,
              notifier.updateDailyDelayAllowance,
            ),
          ),
        ),
        _readOnlyRow('وقت النهاية المحتسب', s.dailyEndTime),
      ],
    );
  }

  // ─── shift section ────────────────────────────────────────────────────────

  Widget _shiftSection(AppSettings s) {
    final notifier = ref.read(settingsProvider.notifier);
    return Column(
      children: [
        _settingRow(
          label: 'أوقات بداية المناوبة',
          hint:
              'قائمة الأوقات المحتملة لبداية المناوبة. ممكن ادخال اكثر من وقت',
          value: _shiftStartTimesList(s),
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
        _settingRow(
          label: 'مدة المناوبة',
          hint: 'المدة الكاملة للمناوبة الواحدة بالساعات',
          value: _numberField(
            _shiftDurationCtrl,
            () => _saveNumber(
              _shiftDurationCtrl,
              '${s.shiftDuration}',
              (v) => v > 0,
              notifier.updateShiftDuration,
            ),
          ),
        ),
        _settingRow(
          label: 'ساعات البصمة',
          hint: 'الوقت المسموح به بين البصمات خلال المناوبة الواحدة',
          value: _numberField(
            _shiftZoneIntervalCtrl,
            () => _saveNumber(
              _shiftZoneIntervalCtrl,
              '${s.shiftZoneInterval}',
              (v) =>
                  v > 0 &&
                  v <= s.shiftDuration &&
                  v * 30 >= _largestTolerance(s),
              notifier.updateShiftZoneInterval,
              invalidMessage: _minZoneIntervalMessage(s),
            ),
          ),
        ),
        _settingRow(
          label: 'سماحية بصمة الدخول والخروج',
          hint:
              'الهامش الزمني بالدقائق المسموح به لبصمة بداية المناوبة ونهايتها',
          value: _numberField(
            _shiftEdgeToleranceCtrl,
            () => _saveNumber(
              _shiftEdgeToleranceCtrl,
              '${s.shiftEdgeTolerance}',
              (v) => v >= 0 && v <= s.maxToleranceMinutes,
              notifier.updateShiftEdgeTolerance,
              invalidMessage: _maxToleranceMessage(s),
            ),
          ),
        ),
        _settingRow(
          label: 'سماحية البصمات الداخلية',
          hint: 'الهامش الزمني بالدقائق المسموح به لبصمات التحقق خلال المناوبة',
          value: _numberField(
            _shiftInnerToleranceCtrl,
            () => _saveNumber(
              _shiftInnerToleranceCtrl,
              '${s.shiftInnerTolerance}',
              (v) => v >= 0 && v <= s.maxToleranceMinutes,
              notifier.updateShiftInnerTolerance,
              invalidMessage: _maxToleranceMessage(s),
            ),
          ),
        ),
        _settingRow(
          label: 'سماحية مدة المناوبة',
          hint: 'الهامش الزمني بالدقائق المسموح به للنقص في مدة الحضور الفعلية',
          value: _numberField(
            _shiftDurationToleranceCtrl,
            () => _saveNumber(
              _shiftDurationToleranceCtrl,
              '${s.shiftDurationTolerance}',
              (v) => v >= 0,
              notifier.updateShiftDurationTolerance,
            ),
          ),
        ),
        _settingRow(
          label: 'ساعات العمل الأساسية',
          hint: 'عدد ساعات العمل الشهرية المطلوبة',
          value: _numberField(
            _shiftBaselineCtrl,
            () => _saveNumber(
              _shiftBaselineCtrl,
              '${s.shiftBaselineHours}',
              (v) => v > 0 && v < s.shiftCeilingHours,
              notifier.updateShiftBaselineHours,
            ),
          ),
        ),
        _settingRow(
          label: 'سقف الساعات الأقصى',
          hint: 'أقصى عدد ساعات عمل يُحتسب في الشهر',
          value: _numberField(
            _shiftCeilingCtrl,
            () => _saveNumber(
              _shiftCeilingCtrl,
              '${s.shiftCeilingHours}',
              (v) => v > s.shiftBaselineHours,
              notifier.updateShiftCeilingHours,
            ),
          ),
        ),
        _readOnlyRow('عدد نقاط التحقق المحتسبة', '${s.zoneCount}'),
      ],
    );
  }

  Widget _shiftStartTimesList(AppSettings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ...s.shiftStartTimes.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    e.value,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'حذف',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: s.shiftStartTimes.length <= 1
                      ? null
                      : () => _removeShiftStartTime(e.key, s.shiftStartTimes),
                ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('إضافة وقت'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () => _addShiftStartTime(s.shiftStartTimes),
        ),
      ],
    );
  }

  // ─── accounts section ─────────────────────────────────────────────────────
  // Only the admin ever reaches this screen (gated by routerProvider), so no
  // further role check is needed here. Role identity itself is fixed — only
  // each account's username/password can be changed.

  Widget _accountsSection() {
    final accountsAsync = ref.watch(accountsProvider);
    return accountsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(error: e.toString()),
      data: (accounts) {
        _initAccountControllers(accounts);
        return Column(
          children: [
            for (final role in UserRole.values) ...[
              _accountRow(role),
              if (role != UserRole.values.last) const Divider(height: 32),
            ],
          ],
        );
      },
    );
  }

  Widget _accountRow(UserRole role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          role.arabicLabel,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _accountTextField(
                _usernameCtrls[role]!,
                hint: 'اسم المستخدم',
                onSave: () => _saveAccountUsername(role),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _accountTextField(
                _passwordCtrls[role]!,
                hint: 'كلمة المرور',
                onSave: () => _saveAccountPassword(role),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _accountTextField(
    TextEditingController ctrl, {
    required String hint,
    required VoidCallback onSave,
  }) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) onSave();
      },
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
        onSubmitted: (_) => onSave(),
      ),
    );
  }

  void _saveAccountUsername(UserRole role) async {
    final ctrl = _usernameCtrls[role]!;
    final value = ctrl.text.trim();
    if (value.isEmpty) {
      ctrl.text = ref.read(accountsProvider).value?[role]?.$1 ?? '';
      _snack('اسم المستخدم لا يمكن أن يكون فارغاً');
      return;
    }
    try {
      await ref.read(accountsProvider.notifier).updateUsername(role, value);
    } catch (_) {
      _snack('حدث خطأ أثناء الحفظ');
    }
  }

  void _saveAccountPassword(UserRole role) async {
    final ctrl = _passwordCtrls[role]!;
    final value = ctrl.text;
    if (value.isEmpty) {
      ctrl.text = ref.read(accountsProvider).value?[role]?.$2 ?? '';
      _snack('كلمة المرور لا يمكن أن تكون فارغة');
      return;
    }
    try {
      await ref.read(accountsProvider.notifier).updatePassword(role, value);
    } catch (_) {
      _snack('حدث خطأ أثناء الحفظ');
    }
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
          label: 'وضع التقريب للساعات الاضافية',
          hint: 'كيفية تقريب الأرقام لسهولة القراءة في التقرير النهائي',
          value: const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: RadioGroup<String>(
            groupValue: s.roundingMode,
            onChanged: (v) {
              if (v != null) {
                ref.read(settingsProvider.notifier).updateRoundingMode(v);
              }
            },
            child: Column(
              children: modes.map((m) {
                return RadioListTile<String>(
                  title: Text(
                    m.$2,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  value: m.$1,
                  activeColor: Theme.of(context).colorScheme.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ─── column headers section ───────────────────────────────────────────────

  Widget _columnHeadersSection(Map<String, List<ColumnHeader>> headers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              _columnHeaderCard(
                'employee_name',
                'اسم الموظف',
                headers['employee_name'] ?? [],
              ),
              const SizedBox(height: 16),
              _columnHeaderCard(
                'department',
                'القسم',
                headers['department'] ?? [],
              ),
              const SizedBox(height: 16),
              _columnHeaderCard(
                'datetime',
                'التاريخ والوقت',
                headers['datetime'] ?? [],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _columnHeaderCard(
                'employee_name',
                'اسم الموظف',
                headers['employee_name'] ?? [],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _columnHeaderCard(
                'department',
                'القسم',
                headers['department'] ?? [],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _columnHeaderCard(
                'datetime',
                'التاريخ والوقت',
                headers['datetime'] ?? [],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _columnHeaderCard(
    String fieldKey,
    String title,
    List<ColumnHeader> headers,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.label_important_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...headers.map((h) => _columnHeaderRow(h)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة مرادف'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _showAddHeaderDialog(fieldKey, headers),
            ),
          ),
        ],
      ),
    );
  }

  Widget _columnHeaderRow(ColumnHeader header) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              header.headerValue,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          if (header.isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'إفتراضي',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'تعديل',
              onPressed: () => _showEditHeaderDialog(header),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              color: Theme.of(context).colorScheme.error,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'حذف',
              onPressed: () => _showDeleteHeaderDialog(header),
            ),
          ],
        ],
      ),
    );
  }

  // ─── reusable widgets ─────────────────────────────────────────────────

  Widget _settingRow({
    required String label,
    required String hint,
    required Widget value,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: hint,
                  preferBelow: false,
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          value,
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
        width: 100,
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── actions ──────────────────────────────────────────────────────────────

  // Both tolerances must fit inside half a zone interval, or a timestamp could
  // satisfy one zone's validity window while belonging to a neighbour's
  // bucket. Changing the interval re-validates both tolerances against it.
  int _largestTolerance(AppSettings s) =>
      s.shiftEdgeTolerance > s.shiftInnerTolerance
      ? s.shiftEdgeTolerance
      : s.shiftInnerTolerance;

  String _maxToleranceMessage(AppSettings s) =>
      'الحد الأقصى للسماحية هو ${s.maxToleranceMinutes} دقيقة مع ساعات البصمة الحالية';

  String _minZoneIntervalMessage(AppSettings s) {
    final minHours = (_largestTolerance(s) + 29) ~/ 30;
    return 'ساعات البصمة يجب ألا تقل عن $minHours ساعة مع السماحيات الحالية';
  }

  void _saveNumber(
    TextEditingController ctrl,
    String fallback,
    bool Function(int) valid,
    Future<void> Function(int) save, {
    String? invalidMessage,
  }) async {
    final parsed = int.tryParse(ctrl.text.trim());
    if (parsed == null || !valid(parsed)) {
      ctrl.text = fallback;
      _snack(invalidMessage ?? 'قيمة غير صالحة');
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
      await ref.read(settingsProvider.notifier).updateShiftStartTimes([
        ...current,
        picked,
      ]);
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

  void _showAddHeaderDialog(String fieldKey, List<ColumnHeader> existing) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => _HeaderInputDialog(
        title: 'إضافة مرادف للعمود',
        controller: ctrl,
        confirmLabel: 'إضافة',
        onConfirm: (value) {
          if (existing.any((h) => h.headerValue == value)) {
            return 'هذا المسمى موجود مسبقاً';
          }
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
        title: 'تعديل المسمى',
        controller: ctrl,
        confirmLabel: 'حفظ التعديلات',
        onConfirm: (value) {
          if (value == header.headerValue) {
            Navigator.pop(ctx);
            return null;
          }
          Navigator.pop(ctx);
          ref
              .read(columnHeadersProvider.notifier)
              .updateHeader(header.id, value);
          return null;
        },
      ),
    );
  }

  void _showDeleteHeaderDialog(ColumnHeader header) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف مسمى العمود'),
        content: Text(
          'هل أنت متأكد من رغبتك بحذف المسمى "${header.headerValue}"؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(columnHeadersProvider.notifier).delete(header.id);
            },
            child: const Text(
              'حذف',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ─── Settings Card Layout Container ──────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
    this.accentColor,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? Theme.of(context).colorScheme.primary;
    final outline = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.3);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: color),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                border: Border(bottom: BorderSide(color: outline)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 26),
                  const SizedBox(width: 14),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.all(24), child: child),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
      ),
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
  final String? Function(String value) onConfirm;

  @override
  State<_HeaderInputDialog> createState() => _HeaderInputDialogState();
}

class _HeaderInputDialogState extends State<_HeaderInputDialog> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: TextField(
        controller: widget.controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'قيمة المسمى..',
          errorText: _error,
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
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
