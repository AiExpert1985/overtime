import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/employee.dart';
import '../../domain/employee_record.dart';
import '../providers/reference_data_providers.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(employeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الموظفون'),
        actions: [
          Tooltip(
            message: 'استيراد من Excel\nالأعمدة المطلوبة: الرقم الوظيفي، الاسم، نوع التوظيف، القسم',
            child: _importing
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.upload_file),
                    onPressed: _pickAndImport,
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(context, null),
        tooltip: 'إضافة موظف',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('خطأ في تحميل الموظفين',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        data: (employees) {
          if (employees.isEmpty) {
            return const Center(
              child: Text('لم يتم إضافة أي موظفين بعد',
                  style: TextStyle(fontSize: 16)),
            );
          }
          return _EmployeesTable(employees: employees);
        },
      ),
    );
  }

  Future<void> _pickAndImport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _importing = true);
    final outcome = await ref
        .read(employeesProvider.notifier)
        .importFromFile(result.files.single.path!);
    if (!mounted) return;
    setState(() => _importing = false);

    if (outcome.isSuccess) {
      _showImportSummary(context, outcome.inserted, outcome.updated);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(outcome.errorMessage ?? 'حدث خطأ أثناء الاستيراد'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showImportSummary(BuildContext context, int inserted, int updated) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اكتمل الاستيراد'),
        content: Text('موظفون جدد: $inserted\nتم تحديثهم: $updated'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, EmployeeRecord? employee) {
    showDialog<void>(
      context: context,
      builder: (_) => _EmployeeDialog(
        employee: employee,
        notifier: ref.read(employeesProvider.notifier),
      ),
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _EmployeesTable extends ConsumerWidget {
  final List<EmployeeRecord> employees;

  const _EmployeesTable({required this.employees});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('الرقم الوظيفي')),
            DataColumn(label: Text('الاسم')),
            DataColumn(label: Text('نوع التوظيف')),
            DataColumn(label: Text('القسم')),
            DataColumn(label: Text('')),
          ],
          rows: employees.map((emp) {
            return DataRow(cells: [
              DataCell(Text(emp.employeeNumber)),
              DataCell(Text(emp.name)),
              DataCell(Text(_typeLabel(emp.employmentType))),
              DataCell(Text(emp.department)),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'تعديل',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showDialog(context, ref, emp),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: theme.colorScheme.error),
                    tooltip: 'حذف',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmDelete(context, ref, emp),
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  String _typeLabel(EmploymentType type) => switch (type) {
        EmploymentType.shift => 'مناوب',
        EmploymentType.daily => 'صباحي',
      };

  void _showDialog(
      BuildContext context, WidgetRef ref, EmployeeRecord? employee) {
    showDialog<void>(
      context: context,
      builder: (_) => _EmployeeDialog(
        employee: employee,
        notifier: ref.read(employeesProvider.notifier),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, EmployeeRecord emp) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الموظف'),
        content: Text('هل تريد حذف "${emp.name}" نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(employeesProvider.notifier).deleteEmployee(emp.id);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

// ── Add / Edit Dialog ─────────────────────────────────────────────────────────

class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog({this.employee, required this.notifier});

  final EmployeeRecord? employee;
  final EmployeesNotifier notifier;

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  late final _numberCtrl =
      TextEditingController(text: widget.employee?.employeeNumber ?? '');
  late final _nameCtrl =
      TextEditingController(text: widget.employee?.name ?? '');
  late final _deptCtrl =
      TextEditingController(text: widget.employee?.department ?? '');

  EmploymentType? _type;
  String? _numberError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.employee?.employmentType;
    _numberCtrl.addListener(_onTextChanged);
    _nameCtrl.addListener(_onTextChanged);
    _deptCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() => _numberError = null);

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _deptCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving &&
      _numberCtrl.text.trim().isNotEmpty &&
      _nameCtrl.text.trim().isNotEmpty &&
      _deptCtrl.text.trim().isNotEmpty &&
      _type != null;

  Future<void> _save() async {
    setState(() => _saving = true);
    final employee = widget.employee;
    final String? error;
    if (employee == null) {
      error = await widget.notifier.addEmployee(
        employeeNumber: _numberCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        employmentType: _type!,
        department: _deptCtrl.text.trim(),
      );
    } else {
      error = await widget.notifier.updateEmployee(
        employee.id,
        employeeNumber: _numberCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        employmentType: _type!,
        department: _deptCtrl.text.trim(),
      );
    }
    if (error != null) {
      setState(() {
        _numberError = error;
        _saving = false;
      });
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.employee != null;
    return AlertDialog(
      title: Text(isEdit ? 'تعديل موظف' : 'إضافة موظف'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _numberCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'الرقم الوظيفي',
                errorText: _numberError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            const SizedBox(height: 12),
            DropdownMenu<EmploymentType>(
              initialSelection: _type,
              label: const Text('نوع التوظيف'),
              expandedInsets: EdgeInsets.zero,
              onSelected: (v) => setState(() => _type = v),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: EmploymentType.shift, label: 'مناوب'),
                DropdownMenuEntry(value: EmploymentType.daily, label: 'صباحي'),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deptCtrl,
              decoration: const InputDecoration(labelText: 'القسم'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
