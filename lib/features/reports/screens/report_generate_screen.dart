import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/domain/user_role.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../domain/picked_file.dart';
import '../providers/report_generate_provider.dart';
import '../providers/reports_provider.dart';
import '../widgets/generation_overlay.dart';

class ReportGenerateScreen extends ConsumerStatefulWidget {
  const ReportGenerateScreen({super.key});

  @override
  ConsumerState<ReportGenerateScreen> createState() =>
      _ReportGenerateScreenState();
}

class _ReportGenerateScreenState extends ConsumerState<ReportGenerateScreen> {
  static const _phases = [
    GenerationPhase(label: 'إعداد قائمة الموظفين'),
    GenerationPhase(label: 'جمع البصمات'),
    GenerationPhase(label: 'تصنيف الموظفين'),
    GenerationPhase(label: 'تحديد أيام العطل'),
    GenerationPhase(label: 'احتساب الوقت الإضافي'),
    GenerationPhase(label: 'تجهيز التقرير'),
  ];

  Future<void>? _generationFuture;
  int? _pendingReportId;
  bool _isHovering = false;

  void _onGenerateTapped() {
    _pendingReportId = null;
    final future = ref.read(reportGenerateProvider.notifier).generate().then((
      id,
    ) {
      if (id == null) throw Exception('generation failed');
      _pendingReportId = id;
    });
    setState(() {
      _generationFuture = future;
    });
  }

  void _onOverlayComplete() {
    final id = _pendingReportId;
    setState(() {
      _generationFuture = null;
      _pendingReportId = null;
    });
    if (id != null && mounted) {
      context.pushNamed('report', pathParameters: {'reportId': '$id'});
    }
  }

  void _onOverlayError(Object _) {
    setState(() {
      _generationFuture = null;
      _pendingReportId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportGenerateProvider);
    final maxRange =
        ref
            .watch(settingsProvider)
            .whenOrNull(data: (s) => s.maxReportDateRange) ??
        32;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'نظام حساب الاوقات الاضافية لموظفي كهرباء مركز نينوى',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      drawer: _AppDrawer(),
      body: Stack(
        children: [
          // Subtle top-to-bottom tint — light indigo to app surface
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFDDE8FF), Color(0xFFF8FAFC)],
                stops: [0.0, 0.55],
              ),
            ),
          ),

          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                    maxWidth: 750,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header — icon + action heading
                      Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [colors.primary, colors.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            blendMode: BlendMode.srcIn,
                            child: const Icon(
                              Icons.access_time_filled,
                              size: 96,
                              color: Colors.white,
                            ),
                          ).animate().fade(duration: 500.ms).scale(),
                          const SizedBox(height: 16),
                          Text(
                            'إنشاء تقرير جديد',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.onSurface,
                                ),
                          ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
                        ],
                      ),
                      const SizedBox(height: 40),

                      if (state.generationError != null)
                        _ErrorBanner(
                          message: state.generationError!,
                          onDismiss: () => ref
                              .read(reportGenerateProvider.notifier)
                              .dismissError(),
                        ).animate().fade().slideY(begin: -0.1),

                      _buildFileDropzone(
                        state,
                      ).animate().fade(delay: 300.ms).slideY(begin: 0.1),
                      const SizedBox(height: 24),

                      _buildDateSection(
                        state,
                        maxRange,
                      ).animate().fade(delay: 400.ms).slideY(begin: 0.1),
                      const SizedBox(height: 48),

                      // Generate button with pulse when enabled
                      _GenerateButton(
                            enabled:
                                state.isGenerateEnabled &&
                                _generationFuture == null,
                            onTap: _onGenerateTapped,
                          )
                          .animate()
                          .fade(delay: 500.ms)
                          .scale(begin: const Offset(0.95, 0.95)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_generationFuture != null)
            Positioned.fill(
              child: GenerationOverlay(
                phases: _phases,
                generationFuture: _generationFuture!,
                onComplete: _onOverlayComplete,
                onError: _onOverlayError,
              ).animate().fade(duration: 300.ms),
            ),
        ],
      ),
    );
  }

  Widget _buildFileDropzone(ReportGenerateState state) {
    final notifier = ref.read(reportGenerateProvider.notifier);

    return DropTarget(
      onDragDone: (detail) {
        final paths = detail.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) notifier.addFiles(paths);
        setState(() => _isHovering = false);
      },
      onDragEntered: (_) => setState(() => _isHovering = true),
      onDragExited: (_) => setState(() => _isHovering = false),
      child: _HoverCard(
        isHovering: _isHovering,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.file_present_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'ملفات الحضور',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'معلومات',
                  onPressed: _showInfoDialog,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 24),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: state.files.isEmpty
                  ? _EmptyDropzone(
                      key: const ValueKey('empty'),
                      generationFuture: _generationFuture,
                      onPickFiles: _pickFiles,
                    )
                  : _FileList(
                      key: const ValueKey('files'),
                      files: state.files,
                      canAdd: state.files.length < 10,
                      generationFuture: _generationFuture,
                      onRemove: (path) => notifier.removeFile(path),
                      onPickMore: _pickFiles,
                    ),
            ),

            if (state.filesError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.filesError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fade().scale(begin: const Offset(0.95, 0.95)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection(ReportGenerateState state, int maxRange) {
    return _HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'الفترة الزمنية',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'من تاريخ',
                  date: state.startDate,
                  enabled: _generationFuture == null,
                  onTap: () => _pickStartDate(maxRange),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _DateField(
                  label: 'إلى تاريخ',
                  date: state.endDate,
                  enabled: _generationFuture == null,
                  onTap: () => _pickEndDate(maxRange),
                ),
              ),
            ],
          ),
          if (state.dateError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.dateError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ).animate().fade().slideY(begin: -0.1),
          ],
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    if (result == null) return;
    final paths = result.files.map((f) => f.path).whereType<String>().toList();
    if (paths.isEmpty) return;
    ref.read(reportGenerateProvider.notifier).addFiles(paths);
  }

  Future<void> _pickStartDate(int maxRange) async {
    final current = ref.read(reportGenerateProvider).startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ar'),
    );
    if (picked == null) return;
    ref.read(reportGenerateProvider.notifier).setStartDate(picked, maxRange);
  }

  Future<void> _pickEndDate(int maxRange) async {
    final state = ref.read(reportGenerateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: state.endDate ?? state.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ar'),
    );
    if (picked == null) return;
    ref.read(reportGenerateProvider.notifier).setEndDate(picked, maxRange);
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معلومات الملف'),
        content: const Text(
          'ملف Excel يجب أن يحتوي على ثلاثة أعمدة رئيسية: \n\n'
          '• اسم الموظف\n'
          '• القسم\n'
          '• التاريخ والوقت\n\n'
          'يمكن تقديم أكثر من ملف، وكل ملف يمكن أن يحتوي على أكثر من ورقة عمل (Sheet).',
          style: TextStyle(height: 1.5),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}

// ── Reusable hoverable card ─────────────────────────────────────────────────

class _HoverCard extends StatefulWidget {
  const _HoverCard({required this.child, this.isHovering});

  final Widget child;
  final bool? isHovering;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  bool get _isHovering => widget.isHovering ?? _hovered;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _isHovering
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isHovering
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: _isHovering ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovering ? 0.10 : 0.03),
              blurRadius: _isHovering ? 24 : 15,
              offset: Offset(0, _isHovering ? 12 : 8),
            ),
          ],
        ),
        transform: _isHovering
            ? Matrix4.translationValues(0.0, -2.0, 0.0)
            : Matrix4.identity(),
        padding: const EdgeInsets.all(32),
        child: widget.child,
      ),
    );
  }
}

// ── Empty dropzone state ────────────────────────────────────────────────────

class _EmptyDropzone extends StatelessWidget {
  const _EmptyDropzone({
    super.key,
    required this.generationFuture,
    required this.onPickFiles,
  });

  final Future<void>? generationFuture;
  final VoidCallback onPickFiles;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
                Icons.cloud_upload_outlined,
                size: 72,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.6),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -5,
                end: 5,
                duration: 3000.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 16),
          Text(
            'قم بسحب وإفلات ملفات Excel هنا',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // "أو" with divider lines
          Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Divider(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'أو',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: generationFuture == null ? onPickFiles : null,
            icon: const Icon(Icons.folder_open),
            label: const Text('تصفح الملفات'),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(
                context,
              ).colorScheme.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Files list state ────────────────────────────────────────────────────────

class _FileList extends StatelessWidget {
  const _FileList({
    super.key,
    required this.files,
    required this.canAdd,
    required this.generationFuture,
    required this.onRemove,
    required this.onPickMore,
  });

  final List<PickedFile> files;
  final bool canAdd;
  final Future<void>? generationFuture;
  final void Function(String path) onRemove;
  final VoidCallback onPickMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: files.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final file = files[index];
            return _FileRow(
              file: file,
              onDelete: generationFuture == null
                  ? () => onRemove(file.path)
                  : null,
            ).animate().fade(duration: 300.ms).slideX(begin: 0.15);
          },
        ),
        if (canAdd) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: generationFuture == null ? onPickMore : null,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('إضافة المزيد من الملفات'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Drawer ──────────────────────────────────────────────────────────────────

class _AppDrawer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = GoRouterState.of(context).uri.path;
    final role = ref.watch(currentUserProvider);
    final isAdmin = role == UserRole.admin;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.access_time_filled,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'نظام الأوقات الإضافية',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _DrawerTile(
              icon: Icons.home_rounded,
              label: 'الرئيسية',
              selected: currentLocation == '/',
              onTap: () {
                Navigator.of(context).pop();
                context.go('/');
              },
            ),
            _DrawerTile(
              icon: Icons.history,
              label: 'التقارير السابقة',
              selected: currentLocation.startsWith('/reports'),
              onTap: () {
                Navigator.of(context).pop();
                ref.invalidate(reportsProvider);
                context.push('/reports');
              },
            ),
            if (isAdmin)
              _DrawerTile(
                icon: Icons.settings_outlined,
                label: 'الإعدادات',
                selected: currentLocation == '/settings',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/settings');
                },
              ),
            const Spacer(),
            _DrawerTile(
              icon: Icons.logout_rounded,
              label: 'تسجيل الخروج',
              selected: false,
              onTap: () {
                Navigator.of(context).pop();
                ref.read(currentUserProvider.notifier).logout();
              },
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حول النظام',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'نظام ذكي لاحتساب الأوقات الإضافية وإعداد التقارير، '
                    'تم التصميم و التنفيذ من قبل قسم الاتصالات الحاسبة الالكترونية في فرع توزيع كهرباء مركز نينوى 2026 .',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(
        icon,
        color: selected ? colors.primary : colors.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.w600,
          color: selected ? colors.primary : colors.onSurface,
        ),
      ),
      selected: selected,
      selectedTileColor: colors.primaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

// ── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onDismiss,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onErrorContainer.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onDismiss,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── File row ─────────────────────────────────────────────────────────────────

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.onDelete});

  final PickedFile file;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: file.isValidating
                  ? Theme.of(context).colorScheme.primaryContainer
                  : file.isValid
                  ? Colors.green.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: file.isValidating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : Icon(
                    file.isValid
                        ? Icons.description_rounded
                        : Icons.broken_image_rounded,
                    color: file.isValid
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (file.errorMessage != null)
                  Text(
                    file.errorMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 22),
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
            tooltip: 'حذف',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Date field ───────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final bool enabled;

  String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date != null ? _format(date!) : 'اختر التاريخ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: date != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: date != null
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.date_range_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Generate button with pulse ───────────────────────────────────────────────

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget button = Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: enabled ? 0.35 : 0.0),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        icon: const Icon(Icons.auto_awesome, size: 24),
        label: const Text(
          'توليد التقرير',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );

    if (enabled) {
      button = button
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.02, 1.02),
            duration: 1200.ms,
            curve: Curves.easeInOut,
          );
    }

    return button;
  }
}
